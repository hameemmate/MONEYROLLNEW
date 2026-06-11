import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_model.dart';
import '../models/transfer_model.dart';
import '../models/cash_transaction_model.dart';
import '../models/debt_clearance_model.dart';
import '../models/enums.dart';
import '../utils/app_constants.dart';

class PaymentController extends GetxController {
  late Box<PaymentModel> _paymentBox;
  late Box<TransferModel> _transferBox;
  late Box<CashTransactionModel> _cashBox;
  late Box<DebtClearanceModel> _debtBox;

  final _uuid = const Uuid();

  final RxList<PaymentModel> payments = <PaymentModel>[].obs;
  final RxList<TransferModel> transfers = <TransferModel>[].obs;
  final RxList<CashTransactionModel> cashTransactions =
      <CashTransactionModel>[].obs;
  final RxList<DebtClearanceModel> debtClearances =
      <DebtClearanceModel>[].obs;

  final RxDouble cashInHand = 0.0.obs;
  final RxBool isLoading = false.obs;

  // Company balance: positive = they owe ME, negative = I owe THEM
  final RxMap<String, double> companyBalances = <String, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _paymentBox = Hive.box<PaymentModel>(AppConstants.boxPayments);
    _transferBox = Hive.box<TransferModel>(AppConstants.boxTransfers);
    _cashBox = Hive.box<CashTransactionModel>(AppConstants.boxCashTx);
    _debtBox = Hive.box<DebtClearanceModel>(AppConstants.boxDebtClearances);
    loadAll();
  }

  void loadAll() {
    payments.value = _paymentBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    transfers.value = _transferBox.values.toList();
    cashTransactions.value = _cashBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    debtClearances.value = _debtBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _recalcCashInHand();
    _recalcCompanyBalances();
  }

  void _recalcCashInHand() {
    double total = 0;
    for (final tx in cashTransactions) {
      if (tx.txType == CashTxType.add) {
        total += tx.amount;
      } else {
        total -= tx.amount;
      }
    }
    cashInHand.value = total;
  }

  /// Company balance logic:
  /// When YOU send to company A: A owes YOU → balance[A] += amount
  /// When A sends to B from YOUR payment: B owes YOU, A balance reduced
  ///   → balance[A] -= amount, balance[B] += amount
  /// When company sends back to YOU: their debt reduces
  ///   → balance[company] -= amount
  /// Debt case: A received 500, sent 600 → A balance = -100 (YOU owe A 100 more)
  void _recalcCompanyBalances() {
    final Map<String, double> balances = {};

    for (final transfer in transfers) {
      final from = transfer.fromCompanyId; // null = ME
      final to = transfer.toCompanyId; // null = ME
      final amt = transfer.amount;

      if (from == null && to != null) {
        // ME → Company: company owes me
        balances[to] = (balances[to] ?? 0) + amt;
      } else if (from != null && to == null) {
        // Company → ME: reduces their debt
        balances[from] = (balances[from] ?? 0) - amt;
      } else if (from != null && to != null) {
        // Company → Company: from reduced, to increased.
        // When 'from' forwarded more than it held, this naturally drives its
        // balance negative (e.g. A received 500, sent 600 → A = -100, meaning
        // I owe A 100). The debt is already captured here; isDebt/debtAmount on
        // the transfer is only a display flag, so we must NOT subtract it again.
        balances[from] = (balances[from] ?? 0) - amt;
        balances[to] = (balances[to] ?? 0) + amt;
      }
    }

    // Clearing a debt settles what I owe the creditor company, so it lifts that
    // company's balance back toward zero regardless of the funding source.
    for (final c in debtClearances) {
      balances[c.companyId] = (balances[c.companyId] ?? 0) + c.amount;
    }

    companyBalances.value = balances;
  }

  // ─── Cash In Hand ────────────────────────────────────────────────

  // ─── Code generation ─────────────────────────────────────────────

  /// Next main payment code: M1, M2, M3 ... based on the highest existing one.
  String _nextPaymentCode() {
    int maxN = 0;
    final re = RegExp(r'^M(\d+)$');
    for (final p in _paymentBox.values) {
      final m = re.firstMatch(p.code);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'M${maxN + 1}';
  }

  /// Depth of a transfer in its tree. First-level branches (hanging directly
  /// under the payment pool) are depth 1, their children depth 2, and so on.
  int _transferDepth(TransferModel t) {
    int depth = 1;
    var cur = t;
    while (cur.parentTransferId != null) {
      final p = getTransferById(cur.parentTransferId!);
      if (p == null) break;
      depth++;
      cur = p;
    }
    return depth;
  }

  /// Letter used at a given depth: 1 → B, 2 → C, 3 → D ...
  String _letterForDepth(int depth) => String.fromCharCode(65 + depth);

  /// Next branch code under [parent], or directly under the payment pool when
  /// [parent] is null. Letters advance with depth:
  ///   pool M1 → M1B1, M1B2 → M1B1C1, M1B1C2 → M1B1C1D1 ...
  String nextBranchCode(PaymentModel payment, TransferModel? parent) {
    final int newDepth = parent == null ? 1 : _transferDepth(parent) + 1;
    final String letter = _letterForDepth(newDepth);
    final String base = parent == null
        ? (payment.code.isEmpty ? 'M?' : payment.code)
        : parent.code;
    final int index =
        _transferBox.values
            .where(
              (t) =>
                  t.paymentId == payment.id && t.parentTransferId == parent?.id,
            )
            .length +
        1;
    return '$base$letter$index';
  }

  /// Amount still sitting in the payment pool, available to branch out.
  /// Only outgoing pool branches (ME/company -> company) consume the pool.
  /// Received-into-pool entries (toCompanyId == null) already raise
  /// payment.amount, so counting them here would cancel the funds out.
  double availableFromPool(PaymentModel payment) {
    final used = _transferBox.values
        .where(
          (t) =>
              t.paymentId == payment.id &&
              t.parentTransferId == null &&
              t.toCompanyId != null,
        )
        .fold(0.0, (s, t) => s + t.amount);
    // Debts cleared from this pool also draw down its un-branched balance.
    final clearedFromPool = _debtBox.values
        .where(
          (c) =>
              c.paymentId == payment.id && c.source == DebtClearSource.pool,
        )
        .fold(0.0, (s, c) => s + c.amount);
    return payment.amount - used - clearedFromPool;
  }

  // ─── Payment ─────────────────────────────────────────────────────

  Future<PaymentModel> createPayment({
    required PaymentType type,
    required double amount,
    required String description,
    String? companyId,
    String? note,
    String? label,
    DateTime? date,
    DateTime? deadline,
  }) async {
    final payment = PaymentModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      companyId: companyId,
      description: description,
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
      remainingAmount: amount,
      totalDebt: 0,
      note: note,
      code: _nextPaymentCode(),
      label: (label != null && label.trim().isNotEmpty) ? label.trim() : null,
      deadline: deadline,
    );

    await _paymentBox.put(payment.id, payment);

    // Cash transaction entry
    if (type == PaymentType.received) {
      // Receiving adds to cash in hand
      final cashTx = CashTransactionModel(
        id: _uuid.v4(),
        txType: CashTxType.add,
        amount: amount,
        description: 'Received: $description',
        relatedPaymentId: payment.id,
        fromCompanyId: companyId,
        date: payment.date,
        createdAt: DateTime.now(),
      );
      await _cashBox.put(cashTx.id, cashTx);
    } else {
      // A "sent" payment is a pool that is immediately branched in full to the
      // chosen company (ME → company = M1B1). The cash deduction happens inside
      // addTransfer, so nothing is deducted here.
      if (companyId != null) {
        // First-level branch M1B1 (ME → company); addTransfer handles the
        // cash deduction and pool/stat updates.
        await addTransfer(
          paymentId: payment.id,
          parentTransferId: null,
          fromCompanyId: null, // ME
          toCompanyId: companyId,
          amount: amount,
        );
      }
    }

    loadAll();
    return getPaymentById(payment.id) ?? payment;
  }

  // ─── Transfer (chain hop) ─────────────────────────────────────────

  /// Add a branch to a payment tree.
  /// [parentTransferId] — node to branch from; null means branch from the
  ///   payment pool itself (a first-level ME → company branch).
  /// [fromCompanyId] — sender; null means ME (only valid for pool branches).
  /// [toCompanyId] — receiver; null means back to ME / the pool.
  /// [sourceType] — fromSpecific (a locked slice from the parent) or fromTotal
  ///   (the parent's accumulated balance). Ignored for pool branches.
  Future<TransferModel> addTransfer({
    required String paymentId,
    String? parentTransferId,
    String? fromCompanyId,
    String? toCompanyId,
    required double amount,
    TransferSourceType sourceType = TransferSourceType.fromTotal,
    String? specificParentTransferId,
    String? note,
    String? label,
    DateTime? deadline,
  }) async {
    final payment = getPaymentById(paymentId);
    if (payment == null) throw Exception('Payment not found');

    final parentTransfer = parentTransferId == null
        ? null
        : getTransferById(parentTransferId);

    // Check availability
    final available = parentTransfer == null
        ? availableFromPool(payment)
        : getAvailableAmount(
            parentTransfer.id,
            sourceType,
            specificParentTransferId,
          );

    // BLOCK if insufficient funds when branching from pool
    if (parentTransfer == null && amount > available + 0.0001) {
      throw Exception(
        'Insufficient funds in pool. Available: ${available.toStringAsFixed(2)}, Requested: ${amount.toStringAsFixed(2)}',
      );
    }

    final isDebt = parentTransfer != null && amount > available + 0.0001;
    final debtAmount = isDebt ? amount - available : 0.0;

    final transfer = TransferModel(
      id: _uuid.v4(),
      paymentId: paymentId,
      parentTransferId: parentTransferId,
      amount: amount,
      fromCompanyId: fromCompanyId,
      toCompanyId: toCompanyId,
      sourceType: parentTransfer == null
          ? TransferSourceType.fromTotal
          : sourceType,
      specificParentTransferId: parentTransfer == null
          ? null
          : specificParentTransferId,
      note: note,
      createdAt: DateTime.now(),
      isDebt: isDebt,
      debtAmount: debtAmount,
      code: nextBranchCode(payment, parentTransfer),
      label: (label != null && label.trim().isNotEmpty) ? label.trim() : null,
      deadline: deadline,
    );

    await _transferBox.put(transfer.id, transfer);

    // Cash in hand only changes at the boundary with ME.
    if (toCompanyId == null) {
      // Money returns to my hand / the pool.
      final cashTx = CashTransactionModel(
        id: _uuid.v4(),
        txType: CashTxType.add,
        amount: amount,
        description: 'Return to pool ${payment.code} (${transfer.code})',
        relatedPaymentId: paymentId,
        relatedTransferId: transfer.id,
        fromCompanyId: fromCompanyId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _cashBox.put(cashTx.id, cashTx);
    } else if (parentTransfer == null && fromCompanyId == null) {
      // Money leaves my hand into the chain (ME → company).
      final cashTx = CashTransactionModel(
        id: _uuid.v4(),
        txType: CashTxType.deduct,
        amount: amount,
        description: 'Branch ${transfer.code} from pool ${payment.code}',
        relatedPaymentId: paymentId,
        relatedTransferId: transfer.id,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _cashBox.put(cashTx.id, cashTx);
    }

    await _updatePaymentStats(paymentId);

    loadAll();
    return transfer;
  }

  Future<void> _updatePaymentStats(String paymentId) async {
    final payment = _paymentBox.get(paymentId);
    if (payment == null) return;

    final allTransfers = _transferBox.values
        .where((t) => t.paymentId == paymentId)
        .toList();

    // Remaining = pool amount - everything branched directly out of the pool.
    // Incoming receipts (toCompanyId == null) raise payment.amount instead of
    // consuming the pool, so they must not be subtracted here.
    final fromPool = allTransfers
        .where((t) => t.parentTransferId == null && t.toCompanyId != null)
        .fold(0.0, (sum, t) => sum + t.amount);

    // Debt remaining in the chain after any settlements.
    final totalDebt = allTransfers
        .where((t) => t.isDebt)
        .fold(0.0, (sum, t) => sum + remainingDebtForTransfer(t));

    // Debts settled from this pool also draw down its remaining balance, so the
    // displayed remaining stays in step with availableFromPool.
    final clearedFromPool = _debtBox.values
        .where(
          (c) => c.paymentId == paymentId && c.source == DebtClearSource.pool,
        )
        .fold(0.0, (s, c) => s + c.amount);

    payment.remainingAmount = payment.amount - fromPool - clearedFromPool;
    payment.totalDebt = totalDebt;
    await _paymentBox.put(paymentId, payment);
  }

  // ─── Query helpers ────────────────────────────────────────────────

  TransferModel? getTransferById(String id) {
    try {
      return _transferBox.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  PaymentModel? getPaymentById(String id) {
    try {
      return _paymentBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<TransferModel> getChildTransfers(String parentTransferId) {
    return _transferBox.values
        .where((t) => t.parentTransferId == parentTransferId)
        .toList();
  }

  List<TransferModel> getPaymentTransfers(String paymentId) {
    return _transferBox.values.where((t) => t.paymentId == paymentId).toList();
  }

  /// How much is available to forward from a given node.
  /// fromSpecific: the remaining amount of the chosen slice (the node itself).
  /// fromTotal: the company's whole balance at this node in the payment.
  double getAvailableAmount(
    String transferId,
    TransferSourceType sourceType,
    String? specificParentId,
  ) {
    if (sourceType == TransferSourceType.fromSpecific &&
        specificParentId != null) {
      final slice = getTransferById(specificParentId);
      if (slice == null) return 0;
      return sliceRemaining(slice);
    }
    final transfer = getTransferById(transferId);
    if (transfer == null) return 0;
    return companyNodeBalance(transfer.paymentId, transfer.toCompanyId);
  }

  /// A company's combined, still-available balance inside one payment:
  /// everything it received minus everything it has forwarded (by any method).
  double companyNodeBalance(String paymentId, String? companyId) {
    if (companyId == null) return 0;
    final incoming = _transferBox.values
        .where((t) => t.paymentId == paymentId && t.toCompanyId == companyId)
        .fold(0.0, (s, t) => s + t.amount);
    final forwarded = _transferBox.values
        .where((t) => t.paymentId == paymentId && t.fromCompanyId == companyId)
        .fold(0.0, (s, t) => s + t.amount);
    return incoming - forwarded;
  }

  /// Remaining amount of one incoming slice (the whole slice minus what has
  /// already been forwarded out of it as a locked slice).
  double sliceRemaining(TransferModel slice) {
    final used = _transferBox.values
        .where(
          (t) =>
              t.specificParentTransferId == slice.id &&
              t.sourceType == TransferSourceType.fromSpecific,
        )
        .fold(0.0, (s, t) => s + t.amount);
    return slice.amount - used;
  }

  /// True once a company has forwarded from its combined total in this payment.
  /// After that, locking onto individual slices is no longer offered, because
  /// the slices can no longer be cleanly told apart.
  bool hasTotalForward(String paymentId, String? companyId) {
    if (companyId == null) return false;
    return _transferBox.values.any(
      (t) =>
          t.paymentId == paymentId &&
          t.fromCompanyId == companyId &&
          t.sourceType == TransferSourceType.fromTotal,
    );
  }

  // ─── Dashboard stats ──────────────────────────────────────────────

  double get totalSentThisMonth {
    final now = DateTime.now();
    return payments
        .where(
          (p) =>
              p.type == PaymentType.sent &&
              p.date.year == now.year &&
              p.date.month == now.month,
        )
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double get totalReceivedThisMonth {
    final now = DateTime.now();
    return payments
        .where(
          (p) =>
              p.type == PaymentType.received &&
              p.date.year == now.year &&
              p.date.month == now.month,
        )
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  List<PaymentModel> get recentPayments {
    return payments.take(10).toList();
  }

  // ─── Export ───────────────────────────────────────────────────────

  Map<String, dynamic> exportAllData() {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'cashInHand': cashInHand.value,
      'payments': payments
          .map(
            (p) => {
              'id': p.id,
              'code': p.code,
              'label': p.label,
              'type': p.type.name,
              'amount': p.amount,
              'description': p.description,
              'date': p.date.toIso8601String(),
              'remainingAmount': p.remainingAmount,
              'totalDebt': p.totalDebt,
              'companyId': p.companyId,
              'note': p.note,
            },
          )
          .toList(),
      'transfers': transfers
          .map(
            (t) => {
              'id': t.id,
              'code': t.code,
              'label': t.label,
              'paymentId': t.paymentId,
              'parentTransferId': t.parentTransferId,
              'amount': t.amount,
              'fromCompanyId': t.fromCompanyId,
              'toCompanyId': t.toCompanyId,
              'sourceType': t.sourceType.name,
              'specificParentTransferId': t.specificParentTransferId,
              'isDebt': t.isDebt,
              'debtAmount': t.debtAmount,
              'note': t.note,
              'date': t.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'cashTransactions': cashTransactions
          .map(
            (tx) => {
              'id': tx.id,
              'type': tx.txType.name,
              'amount': tx.amount,
              'description': tx.description,
              'date': tx.date.toIso8601String(),
            },
          )
          .toList(),
      'debtClearances': debtClearances
          .map(
            (c) => {
              'id': c.id,
              'transferId': c.transferId,
              'paymentId': c.paymentId,
              'companyId': c.companyId,
              'amount': c.amount,
              'source': c.source.name,
              'cashTxId': c.cashTxId,
              'note': c.note,
              'date': c.date.toIso8601String(),
              'createdAt': c.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'companyBalances': companyBalances,
    };
  }

  Future<void> deletePayment(String paymentId) async {
    // Remove all transfers
    final toRemove = _transferBox.values
        .where((t) => t.paymentId == paymentId)
        .map((t) => t.id)
        .toList();
    for (final id in toRemove) {
      await _transferBox.delete(id);
    }
    // Remove related cash transactions
    final cashToRemove = _cashBox.values
        .where((tx) => tx.relatedPaymentId == paymentId)
        .map((tx) => tx.id)
        .toList();
    for (final id in cashToRemove) {
      await _cashBox.delete(id);
    }
    // Remove debt clearances tied to this payment
    final debtToRemove = _debtBox.values
        .where((c) => c.paymentId == paymentId)
        .map((c) => c.id)
        .toList();
    for (final id in debtToRemove) {
      await _debtBox.delete(id);
    }
    await _paymentBox.delete(paymentId);
    loadAll();
  }

  /// Delete a single cash entry (e.g. a manual "Add Cash" record) and recalc.
  Future<void> deleteCashTransaction(String id) async {
    await _cashBox.delete(id);
    loadAll();
  }

  /// Update a payment. Description, label, note, date and deadline are always
  /// editable. Amount and company can only change while the payment has no
  /// branches yet — otherwise they stay locked to keep the tree and cash
  /// consistent. When amount/company change, any cash entry tied to the payment
  /// is kept in sync.
  Future<void> updatePayment(
    String paymentId, {
    required String description,
    String? label,
    String? note,
    required DateTime date,
    DateTime? deadline,
    double? amount,
    String? companyId,
  }) async {
    final p = _paymentBox.get(paymentId);
    if (p == null) return;

    p.description = description;
    p.label = (label != null && label.trim().isNotEmpty) ? label.trim() : null;
    p.note = (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    p.date = date;
    p.deadline = deadline;

    final hasBranches = _transferBox.values.any(
      (t) => t.paymentId == paymentId,
    );
    if (!hasBranches) {
      if (amount != null && amount > 0) {
        p.amount = amount;
        p.remainingAmount = amount;
      }
      p.companyId = companyId;
      // Keep the related cash entry (the received +cash) in sync.
      final cashList = _cashBox.values
          .where((tx) => tx.relatedPaymentId == paymentId)
          .toList();
      for (final tx in cashList) {
        tx.amount = p.amount;
        if (p.type == PaymentType.received) tx.fromCompanyId = companyId;
        await _cashBox.put(tx.id, tx);
      }
    }

    await _paymentBox.put(paymentId, p);
    await _updatePaymentStats(paymentId);
    loadAll();
  }

  /// Update editable metadata on a branch (label, note, deadline).
  Future<void> updateTransfer(
    String transferId, {
    String? label,
    String? note,
    DateTime? deadline,
  }) async {
    final t = _transferBox.get(transferId);
    if (t == null) return;
    t.label = (label != null && label.trim().isNotEmpty) ? label.trim() : null;
    t.note = (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    t.deadline = deadline;
    await _transferBox.put(transferId, t);
    loadAll();
  }

  /// Delete a branch and every branch below it, removing any cash entries those
  /// branches created (ME → company deductions and returns), then recalc.
  Future<void> deleteTransfer(String transferId) async {
    final toDelete = <String>[];
    void collect(String id) {
      toDelete.add(id);
      for (final c in _transferBox.values.where(
        (t) => t.parentTransferId == id,
      )) {
        collect(c.id);
      }
    }

    collect(transferId);

    final paymentIds = <String>{};
    for (final id in toDelete) {
      final t = _transferBox.get(id);
      if (t != null) paymentIds.add(t.paymentId);
      final cashIds = _cashBox.values
          .where((tx) => tx.relatedTransferId == id)
          .map((tx) => tx.id)
          .toList();
      for (final cid in cashIds) {
        await _cashBox.delete(cid);
      }
      // Drop any debt clearances recorded against this branch.
      final debtIds = _debtBox.values
          .where((c) => c.transferId == id)
          .map((c) => c.id)
          .toList();
      for (final did in debtIds) {
        await _debtBox.delete(did);
      }
      await _transferBox.delete(id);
    }

    for (final pid in paymentIds) {
      await _updatePaymentStats(pid);
    }
    loadAll();
  }

  // Add these methods to PaymentController class

  /// Balance of every company inside each pool, kept separate per pool.
  /// Returns company id -> list of that company's net balance in each pool it
  /// appears in. Netting is done within a single pool only, so a surplus in one
  /// pool can never cancel out a debt the same company holds in another pool.
  Map<String, List<double>> _companyPoolBalances() {
    final Map<String, Map<String, double>> byCompany = {};
    for (final t in transfers) {
      final from = t.fromCompanyId;
      final to = t.toCompanyId;
      if (from != null) {
        final pools = byCompany.putIfAbsent(from, () => {});
        pools[t.paymentId] = (pools[t.paymentId] ?? 0) - t.amount;
      }
      if (to != null) {
        final pools = byCompany.putIfAbsent(to, () => {});
        pools[t.paymentId] = (pools[t.paymentId] ?? 0) + t.amount;
      }
    }
    // A cleared debt reduces what I owe the creditor inside that same pool.
    for (final c in debtClearances) {
      final pools = byCompany.putIfAbsent(c.companyId, () => {});
      pools[c.paymentId] = (pools[c.paymentId] ?? 0) + c.amount;
    }
    return {for (final e in byCompany.entries) e.key: e.value.values.toList()};
  }

  // ─── Debt clearing ───────────────────────────────────────────────

  /// All clearance entries recorded against a debt transfer.
  List<DebtClearanceModel> clearancesForTransfer(String transferId) {
    return debtClearances.where((c) => c.transferId == transferId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Total already cleared against a debt transfer.
  double clearedForTransfer(String transferId) {
    return _debtBox.values
        .where((c) => c.transferId == transferId)
        .fold(0.0, (s, c) => s + c.amount);
  }

  /// Outstanding debt still owed on a transfer (never negative).
  double remainingDebtForTransfer(TransferModel t) {
    if (!t.isDebt) return 0;
    final remaining = t.debtAmount - clearedForTransfer(t.id);
    return remaining > 0 ? remaining : 0;
  }

  /// True once a debt transfer has been settled in full.
  bool isDebtFullyCleared(TransferModel t) {
    return t.isDebt && remainingDebtForTransfer(t) <= 0.0001;
  }

  /// Date of the last clearance on a transfer, or null if untouched.
  DateTime? debtClearedDate(String transferId) {
    final list = clearancesForTransfer(transferId);
    if (list.isEmpty) return null;
    return list.last.date;
  }

  /// Debt-bearing transfers within a payment that still owe something.
  List<TransferModel> outstandingDebtTransfers(String paymentId) {
    return _transferBox.values
        .where((t) => t.paymentId == paymentId && t.isDebt)
        .where((t) => remainingDebtForTransfer(t) > 0.0001)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Settle part or all of a debt on [transferId].
  /// The amount is capped at the remaining debt and, for pool/cash sources, at
  /// the available funds. Pool and cash sources deduct real money; the company
  /// source is a waive (no money moves).
  Future<DebtClearanceModel> clearDebt({
    required String transferId,
    required DebtClearSource source,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final t = getTransferById(transferId);
    if (t == null) throw Exception('Transfer not found');
    if (!t.isDebt) throw Exception('This branch has no debt to clear');

    final creditorId = t.fromCompanyId;
    if (creditorId == null) {
      throw Exception('This debt has no creditor company');
    }

    final payment = getPaymentById(t.paymentId);
    if (payment == null) throw Exception('Payment not found');

    if (amount <= 0) throw Exception('Enter an amount greater than zero');

    final remaining = remainingDebtForTransfer(t);
    if (amount > remaining + 0.0001) {
      throw Exception(
        'Amount exceeds remaining debt (${remaining.toStringAsFixed(2)})',
      );
    }

    if (source == DebtClearSource.pool) {
      final pool = availableFromPool(payment);
      if (amount > pool + 0.0001) {
        throw Exception(
          'Pool ${payment.code} only has ${pool.toStringAsFixed(2)} available',
        );
      }
    } else if (source == DebtClearSource.cash) {
      if (amount > cashInHand.value + 0.0001) {
        throw Exception(
          'Cash in hand is only ${cashInHand.value.toStringAsFixed(2)}',
        );
      }
    }

    final when = date ?? DateTime.now();
    String? cashTxId;

    // Pool and cash settlements move money out of hand; a waive does not.
    if (source == DebtClearSource.pool || source == DebtClearSource.cash) {
      final label = source == DebtClearSource.pool
          ? 'Debt cleared from pool ${payment.code} (${t.code})'
          : 'Debt cleared from cash (${t.code})';
      final cashTx = CashTransactionModel(
        id: _uuid.v4(),
        txType: CashTxType.deduct,
        amount: amount,
        description: label,
        relatedPaymentId: t.paymentId,
        relatedTransferId: transferId,
        fromCompanyId: creditorId,
        date: when,
        createdAt: DateTime.now(),
      );
      await _cashBox.put(cashTx.id, cashTx);
      cashTxId = cashTx.id;
    }

    final clearance = DebtClearanceModel(
      id: _uuid.v4(),
      transferId: transferId,
      paymentId: t.paymentId,
      companyId: creditorId,
      amount: amount,
      source: source,
      cashTxId: cashTxId,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      date: when,
      createdAt: DateTime.now(),
    );
    await _debtBox.put(clearance.id, clearance);

    await _updatePaymentStats(t.paymentId);
    loadAll();
    return clearance;
  }

  /// Reverse a single debt clearance, restoring the debt and any cash deducted.
  Future<void> deleteDebtClearance(String clearanceId) async {
    final c = _debtBox.get(clearanceId);
    if (c == null) return;
    if (c.cashTxId != null) {
      await _cashBox.delete(c.cashTxId);
    }
    await _debtBox.delete(clearanceId);
    await _updatePaymentStats(c.paymentId);
    loadAll();
  }

  /// Per company, total they owe ME (sum of their positive pool balances).
  Map<String, double> get companyOwedToMe {
    final result = <String, double>{};
    _companyPoolBalances().forEach((companyId, pools) {
      final positive = pools
          .where((v) => v > 0.0001)
          .fold(0.0, (s, v) => s + v);
      if (positive > 0.0001) result[companyId] = positive;
    });
    return result;
  }

  /// Per company, total I owe THEM (sum of their negative pool balances, as a
  /// positive magnitude).
  Map<String, double> get companyOwedByMe {
    final result = <String, double>{};
    _companyPoolBalances().forEach((companyId, pools) {
      final negative = pools
          .where((v) => v < -0.0001)
          .fold(0.0, (s, v) => s + v.abs());
      if (negative > 0.0001) result[companyId] = negative;
    });
    return result;
  }

  /// Net position: positive = people owe me more, negative = I owe more
  double get netPosition => totalOutstanding - totalDebtOwedByMe;

  /// Get balance for a specific company (positive = they owe me, negative = I owe them)
  double getCompanyBalance(String companyId) {
    return companyBalances[companyId] ?? 0.0;
  }

  /// Get detailed balance info for a company
  Map<String, dynamic> getCompanyBalanceDetails(String companyId) {
    final balance = getCompanyBalance(companyId);
    return {
      'companyId': companyId,
      'balance': balance,
      'status': balance > 0 ? 'owes_me' : (balance < 0 ? 'i_owe' : 'settled'),
      'amount': balance.abs(),
    };
  }

  /// Get all payments that involve a specific company
  List<PaymentModel> getPaymentsForCompany(String companyId) {
    return payments.where((p) => p.companyId == companyId).toList();
  }

  /// Get all transfers for a specific company across all payments
  List<TransferModel> getTransfersForCompany(String companyId) {
    return transfers
        .where(
          (t) => t.fromCompanyId == companyId || t.toCompanyId == companyId,
        )
        .toList();
  }

  // Add to PaymentController class
  // Owed totals are aggregated per pool (see _companyPoolBalances) so a
  // company can legitimately appear in both lists: owing me in one pool while I
  // owe it in another. Values follow the old sign convention (owe-me positive,
  // I-owe negative) so existing screens keep working.
  List<MapEntry<String, double>> get companiesThatOweMe {
    return companyOwedToMe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, double>> get companiesIOwe {
    return companyOwedByMe.entries
        .map((e) => MapEntry(e.key, -e.value))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  double get totalOutstanding {
    return companyOwedToMe.values.fold(0.0, (sum, v) => sum + v);
  }

  double get totalDebtOwedByMe {
    return companyOwedByMe.values.fold(0.0, (sum, v) => sum + v);
  }
  /// Allocate cash in hand into a payment pool so it can be branched onward.
  /// Funding only earmarks money you already hold — the actual cash leaves your
  /// hand when you branch it out to a company, so it must not be deducted here
  /// or the same money would be counted out twice. It is blocked when cash in
  /// hand is less than the amount.
  Future<TransferModel> receiveIntoPool({
    required String paymentId,
    required double amount,
    String? note,
    String? label,
    DateTime? deadline,
  }) async {
    final payment = getPaymentById(paymentId);
    if (payment == null) throw Exception('Payment not found');
    if (amount <= 0) throw Exception('Enter an amount greater than zero');
    if (amount > cashInHand.value + 0.0001) {
      throw Exception(
        'Cash in hand is only ${cashInHand.value.toStringAsFixed(2)}',
      );
    }

    // Earmark record: money set aside from cash in hand into this pool.
    final transfer = TransferModel(
      id: _uuid.v4(),
      paymentId: paymentId,
      parentTransferId: null, // Directly under payment pool
      amount: amount,
      fromCompanyId: null, // ME / cash in hand
      toCompanyId: null, // null = ME (the pool)
      sourceType: TransferSourceType.fromTotal,
      specificParentTransferId: null,
      note: note,
      createdAt: DateTime.now(),
      isDebt: false,
      debtAmount: 0,
      code: nextBranchCode(payment, null),
      label: label,
      deadline: deadline,
    );

    await _transferBox.put(transfer.id, transfer);

    // Grow the pool's available balance. Cash in hand is intentionally left
    // unchanged; it is deducted when this money is branched out to a company.
    payment.amount += amount;
    payment.remainingAmount += amount;
    await _paymentBox.put(payment.id, payment);

    loadAll();
    return transfer;
  }

  // Add to PaymentController class
  Future<void> deleteAllData() async {
    await _paymentBox.clear();
    await _transferBox.clear();
    await _cashBox.clear();
    await _debtBox.clear();
    loadAll();
  }

  /// Restore payments, transfers and cash transactions from a backup,
  /// preserving their original ids so the tree relationships stay intact.
  Future<void> importData({
    required List<PaymentModel> payments,
    required List<TransferModel> transfers,
    required List<CashTransactionModel> cashTransactions,
    List<DebtClearanceModel> debtClearances = const [],
  }) async {
    await _paymentBox.putAll({for (final p in payments) p.id: p});
    await _transferBox.putAll({for (final t in transfers) t.id: t});
    await _cashBox.putAll({for (final tx in cashTransactions) tx.id: tx});
    await _debtBox.putAll({for (final c in debtClearances) c.id: c});
    loadAll();
  }
}
