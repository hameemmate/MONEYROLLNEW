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
  final RxList<DebtClearanceModel> debtClearances = <DebtClearanceModel>[].obs;

  final RxDouble cashInHand = 0.0.obs;
  final RxBool isLoading = false.obs;

  final RxMap<String, double> companyBalances = <String, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _paymentBox = Hive.box<PaymentModel>(AppConstants.boxPayments);
    _transferBox = Hive.box<TransferModel>(AppConstants.boxTransfers);
    _cashBox = Hive.box<CashTransactionModel>(AppConstants.boxCashTx);
    _debtBox = Hive.box<DebtClearanceModel>(AppConstants.boxDebtClearances);
    loadAll();
    _migrateCompanyReceiptDebts();
  }

  Future<void> _migrateCompanyReceiptDebts() async {
    var changed = false;
    for (final t in _transferBox.values) {
      final isCompanyIncoming =
          t.parentTransferId == null &&
          t.toCompanyId == null &&
          t.fromCompanyId != null &&
          t.sourcePaymentId == null;
      if (isCompanyIncoming && !t.isDebt) {
        t.isDebt = true;
        t.debtAmount = t.amount;
        await _transferBox.put(t.id, t);
        changed = true;
      }
    }
    if (changed) {
      for (final p in _paymentBox.values) {
        await _updatePaymentStats(p.id);
      }
      loadAll();
    }
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

  void _recalcCompanyBalances() {
    final Map<String, double> balances = {};

    for (final transfer in transfers) {
      final from = transfer.fromCompanyId;
      final to = transfer.toCompanyId;
      final amt = transfer.amount;

      if (from == null && to != null) {
        balances[to] = (balances[to] ?? 0) + amt;
      } else if (from != null && to == null) {
        balances[from] = (balances[from] ?? 0) - amt;
      } else if (from != null && to != null) {
        balances[from] = (balances[from] ?? 0) - amt;
        balances[to] = (balances[to] ?? 0) + amt;
      }
    }

    for (final c in debtClearances) {
      balances[c.companyId] = (balances[c.companyId] ?? 0) + c.amount;
    }

    companyBalances.value = balances;
  }

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

  String _letterForDepth(int depth) => String.fromCharCode(65 + depth);

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

  double availableFromPool(PaymentModel payment) {
    if (payment.type == PaymentType.received && payment.companyId != null) {
      // Debt pool: available = total debt - total already sent to companies (ME → company branches)
      final sentToCompanies = _transferBox.values
          .where(
            (t) =>
                t.paymentId == payment.id &&
                t.parentTransferId == null &&
                t.fromCompanyId == null &&
                t.toCompanyId != null,
          )
          .fold(0.0, (s, t) => s + t.amount);
      return payment.amount - sentToCompanies;
    }
    // Normal pool
    final used = _transferBox.values
        .where(
          (t) =>
              t.paymentId == payment.id &&
              t.parentTransferId == null &&
              t.toCompanyId != null,
        )
        .fold(0.0, (s, t) => s + t.amount);
    final movedToOtherPools = _transferBox.values
        .where((t) => t.sourcePaymentId == payment.id)
        .fold(0.0, (s, t) => s + t.amount);
    final clearedFromPool = _debtBox.values
        .where(
          (c) => c.paymentId == payment.id && c.source == DebtClearSource.pool,
        )
        .fold(0.0, (s, c) => s + c.amount);
    return payment.amount - used - movedToOtherPools - clearedFromPool;
  }

  List<TransferModel> poolFundingsInto(String paymentId) {
    return _transferBox.values
        .where((t) => t.paymentId == paymentId && t.sourcePaymentId != null)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<TransferModel> poolFundingsOutOf(String paymentId) {
    return _transferBox.values
        .where((t) => t.sourcePaymentId == paymentId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  bool poolHasBranches(String paymentId) {
    return _transferBox.values.any((t) => t.paymentId == paymentId);
  }

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

    if (type == PaymentType.received) {
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

      if (companyId != null) {
        final receipt = TransferModel(
          id: _uuid.v4(),
          paymentId: payment.id,
          parentTransferId: null,
          amount: amount,
          fromCompanyId: companyId,
          toCompanyId: null,
          sourceType: TransferSourceType.fromTotal,
          createdAt: DateTime.now(),
          isDebt: true,
          debtAmount: amount,
          code: nextBranchCode(payment, null),
        );
        await _transferBox.put(receipt.id, receipt);
        payment.rootTransferId = receipt.id;
        await _paymentBox.put(payment.id, payment);
      }
    } else {
      if (companyId != null) {
        await addTransfer(
          paymentId: payment.id,
          parentTransferId: null,
          fromCompanyId: null,
          toCompanyId: companyId,
          amount: amount,
        );
      }
    }

    loadAll();
    return getPaymentById(payment.id) ?? payment;
  }

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

    if (parentTransfer == null) {
      final available = availableFromPool(payment);
      if (amount > available + 0.0001) {
        throw Exception(
          'Insufficient funds in pool. Available: ${available.toStringAsFixed(2)}',
        );
      }

      final transfer = TransferModel(
        id: _uuid.v4(),
        paymentId: paymentId,
        parentTransferId: null,
        amount: amount,
        fromCompanyId: null,
        toCompanyId: toCompanyId,
        sourceType: TransferSourceType.fromTotal,
        note: note,
        createdAt: DateTime.now(),
        isDebt: false,
        debtAmount: 0.0,
        code: nextBranchCode(payment, null),
        label: label,
        deadline: deadline,
      );
      await _transferBox.put(transfer.id, transfer);

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

      await _updatePaymentStats(paymentId);
      loadAll();
      return transfer;
    }

    // Branch from a company node
    final isDebt =
        amount >
        getAvailableAmount(
              parentTransfer.id,
              sourceType,
              specificParentTransferId,
            ) +
            0.0001;
    final debtAmount = isDebt
        ? amount -
              getAvailableAmount(
                parentTransfer.id,
                sourceType,
                specificParentTransferId,
              )
        : 0.0;

    final transfer = TransferModel(
      id: _uuid.v4(),
      paymentId: paymentId,
      parentTransferId: parentTransferId,
      amount: amount,
      fromCompanyId: fromCompanyId,
      toCompanyId: toCompanyId,
      sourceType: sourceType,
      specificParentTransferId: specificParentTransferId,
      note: note,
      createdAt: DateTime.now(),
      isDebt: isDebt,
      debtAmount: debtAmount,
      code: nextBranchCode(payment, parentTransfer),
      label: label,
      deadline: deadline,
    );
    await _transferBox.put(transfer.id, transfer);

    if (toCompanyId == null) {
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

    if (payment.type == PaymentType.received && payment.companyId != null) {
      // Debt pool: remainingAmount is the amount still available to branch
      // (total debt minus what has been sent to other companies)
      final sentToCompanies = allTransfers
          .where(
            (t) =>
                t.parentTransferId == null &&
                t.fromCompanyId == null &&
                t.toCompanyId != null,
          )
          .fold(0.0, (s, t) => s + t.amount);
      payment.remainingAmount = payment.amount - sentToCompanies;
    } else {
      final fromPool = allTransfers
          .where((t) => t.parentTransferId == null && t.toCompanyId != null)
          .fold(0.0, (sum, t) => sum + t.amount);
      final movedToOtherPools = _transferBox.values
          .where((t) => t.sourcePaymentId == paymentId)
          .fold(0.0, (s, t) => s + t.amount);
      final clearedFromPool = _debtBox.values
          .where(
            (c) => c.paymentId == paymentId && c.source == DebtClearSource.pool,
          )
          .fold(0.0, (s, c) => s + c.amount);
      payment.remainingAmount =
          payment.amount - fromPool - movedToOtherPools - clearedFromPool;
    }

    final totalDebt = allTransfers
        .where((t) => t.isDebt)
        .fold(0.0, (sum, t) => sum + remainingDebtForTransfer(t));
    payment.totalDebt = totalDebt;
    await _paymentBox.put(paymentId, payment);
  }

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

  double companyNodeBalance(String paymentId, String? companyId) {
    if (companyId == null) return 0;
    final incoming = _transferBox.values
        .where((t) => t.paymentId == paymentId && t.toCompanyId == companyId)
        .fold(0.0, (s, t) => s + t.amount);
    final forwarded = _transferBox.values
        .where(
          (t) =>
              t.paymentId == paymentId &&
              t.fromCompanyId == companyId &&
              !(t.parentTransferId == null && t.toCompanyId == null),
        )
        .fold(0.0, (s, t) => s + t.amount);
    return incoming - forwarded;
  }

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

  bool hasTotalForward(String paymentId, String? companyId) {
    if (companyId == null) return false;
    return _transferBox.values.any(
      (t) =>
          t.paymentId == paymentId &&
          t.fromCompanyId == companyId &&
          t.sourceType == TransferSourceType.fromTotal &&
          !(t.parentTransferId == null && t.toCompanyId == null),
    );
  }

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

  List<PaymentModel> get recentPayments => payments.take(10).toList();

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
              'sourcePaymentId': t.sourcePaymentId,
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
    final sourcePoolIds = _transferBox.values
        .where((t) => t.paymentId == paymentId && t.sourcePaymentId != null)
        .map((t) => t.sourcePaymentId!)
        .where((id) => id != paymentId)
        .toSet();
    final toRemove = _transferBox.values
        .where((t) => t.paymentId == paymentId)
        .map((t) => t.id)
        .toList();
    for (final id in toRemove) {
      await _transferBox.delete(id);
    }
    final cashToRemove = _cashBox.values
        .where((tx) => tx.relatedPaymentId == paymentId)
        .map((tx) => tx.id)
        .toList();
    for (final id in cashToRemove) {
      await _cashBox.delete(id);
    }
    final debtToRemove = _debtBox.values
        .where((c) => c.paymentId == paymentId)
        .map((c) => c.id)
        .toList();
    for (final id in debtToRemove) {
      await _debtBox.delete(id);
    }
    await _paymentBox.delete(paymentId);
    for (final sid in sourcePoolIds) {
      await _updatePaymentStats(sid);
    }
    loadAll();
  }

  Future<void> deleteCashTransaction(String id) async {
    await _cashBox.delete(id);
    loadAll();
  }

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
      (t) => t.paymentId == paymentId && t.id != p.rootTransferId,
    );

    if (amount != null && amount > 0 && (amount - p.amount).abs() > 0.0001) {
      final used = p.amount - availableFromPool(p);
      if (amount < used - 0.0001) {
        throw Exception(
          'Pool ${p.code} has already used ${used.toStringAsFixed(2)} — amount cannot go below that',
        );
      }
      final extras = _transferBox.values
          .where(
            (t) =>
                t.paymentId == paymentId &&
                t.parentTransferId == null &&
                t.toCompanyId == null &&
                t.id != p.rootTransferId,
          )
          .fold(0.0, (s, t) => s + t.amount);
      final newReceipt = amount - extras;
      if (newReceipt < -0.0001) {
        throw Exception(
          'Amount cannot go below the ${extras.toStringAsFixed(2)} received into this pool later',
        );
      }
      p.amount = amount;

      final receiptTxs = _cashBox.values
          .where(
            (tx) =>
                tx.relatedPaymentId == paymentId &&
                tx.relatedTransferId == null,
          )
          .toList();
      for (final tx in receiptTxs) {
        tx.amount = newReceipt;
        await _cashBox.put(tx.id, tx);
      }

      if (p.rootTransferId != null) {
        final root = _transferBox.get(p.rootTransferId);
        if (root != null) {
          final cleared = clearedForTransfer(root.id);
          if (cleared > newReceipt + 0.0001) {
            throw Exception(
              '${cleared.toStringAsFixed(2)} of this receipt\'s debt was already cleared — amount cannot go below that',
            );
          }
          root.amount = newReceipt;
          root.debtAmount = newReceipt;
          root.isDebt = newReceipt > 0.0001;
          await _transferBox.put(root.id, root);
        }
      }
    }

    if (!hasBranches) {
      p.companyId = companyId;
      final receiptTxs = _cashBox.values
          .where(
            (tx) =>
                tx.relatedPaymentId == paymentId &&
                tx.relatedTransferId == null,
          )
          .toList();
      for (final tx in receiptTxs) {
        if (p.type == PaymentType.received) tx.fromCompanyId = companyId;
        await _cashBox.put(tx.id, tx);
      }
      if (p.type == PaymentType.received) {
        final root = p.rootTransferId == null
            ? null
            : _transferBox.get(p.rootTransferId);
        if (root != null &&
            root.fromCompanyId != companyId &&
            clearedForTransfer(root.id) > 0.0001) {
          throw Exception(
            'Part of this receipt\'s debt was already cleared — the company cannot change anymore',
          );
        }
        if (companyId == null) {
          if (root != null) {
            await _transferBox.delete(root.id);
            p.rootTransferId = null;
          }
        } else if (root != null) {
          if (root.fromCompanyId != companyId) {
            root.fromCompanyId = companyId;
            await _transferBox.put(root.id, root);
          }
        } else {
          final receipt = TransferModel(
            id: _uuid.v4(),
            paymentId: paymentId,
            parentTransferId: null,
            amount: p.amount,
            fromCompanyId: companyId,
            toCompanyId: null,
            sourceType: TransferSourceType.fromTotal,
            createdAt: DateTime.now(),
            isDebt: true,
            debtAmount: p.amount,
            code: nextBranchCode(p, null),
          );
          await _transferBox.put(receipt.id, receipt);
          p.rootTransferId = receipt.id;
        }
      }
    }

    await _paymentBox.put(paymentId, p);
    await _updatePaymentStats(paymentId);
    loadAll();
  }

  Future<void> updateTransfer(
    String transferId, {
    String? label,
    String? note,
    DateTime? deadline,
    double? amount,
  }) async {
    final t = _transferBox.get(transferId);
    if (t == null) return;

    String? sourcePoolToRefresh;
    if (amount != null && (amount - t.amount).abs() > 0.0001) {
      if (amount <= 0) throw Exception('Enter an amount greater than zero');
      await _applyTransferAmountEdit(t, amount);
      sourcePoolToRefresh = t.sourcePaymentId;
    }

    t.label = (label != null && label.trim().isNotEmpty) ? label.trim() : null;
    t.note = (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    t.deadline = deadline;
    await _transferBox.put(transferId, t);
    await _updatePaymentStats(t.paymentId);
    if (sourcePoolToRefresh != null) {
      await _updatePaymentStats(sourcePoolToRefresh);
    }
    loadAll();
  }

  Future<void> _applyTransferAmountEdit(
    TransferModel t,
    double newAmount,
  ) async {
    final payment = _paymentBox.get(t.paymentId);
    if (payment == null) throw Exception('Payment not found');
    final delta = newAmount - t.amount;

    final bool isIncoming = t.parentTransferId == null && t.toCompanyId == null;
    final bool isPoolBranch =
        t.parentTransferId == null && t.toCompanyId != null;

    if (isIncoming) {
      if (t.id == payment.rootTransferId) {
        throw Exception(
          'This is the pool\'s original receipt — edit the pool amount instead',
        );
      }
      if (t.sourcePaymentId != null && delta > 0) {
        final source = getPaymentById(t.sourcePaymentId!);
        if (source != null) {
          final spare = availableFromPool(source);
          if (delta > spare + 0.0001) {
            throw Exception(
              'Pool ${source.code} only has ${spare.toStringAsFixed(2)} more available',
            );
          }
        }
      }
      final used = payment.amount - availableFromPool(payment);
      if (payment.amount + delta < used - 0.0001) {
        throw Exception(
          'Pool ${payment.code} has already used ${used.toStringAsFixed(2)} — amount too low',
        );
      }
      if (t.fromCompanyId != null) {
        final cleared = clearedForTransfer(t.id);
        if (cleared > newAmount + 0.0001) {
          throw Exception(
            '${cleared.toStringAsFixed(2)} of this debt was already cleared — amount cannot go below that',
          );
        }
        t.isDebt = true;
        t.debtAmount = newAmount;
      }
      payment.amount += delta;
      await _paymentBox.put(payment.id, payment);
    } else if (isPoolBranch) {
      if (delta > availableFromPool(payment) + 0.0001) {
        throw Exception(
          'Pool ${payment.code} only has ${availableFromPool(payment).toStringAsFixed(2)} available',
        );
      }
    } else {
      double availableExcl;
      if (t.sourceType == TransferSourceType.fromSpecific &&
          t.specificParentTransferId != null) {
        final slice = getTransferById(t.specificParentTransferId!);
        availableExcl = (slice == null ? 0 : sliceRemaining(slice)) + t.amount;
      } else {
        availableExcl =
            companyNodeBalance(t.paymentId, t.fromCompanyId) + t.amount;
      }
      final isDebt = newAmount > availableExcl + 0.0001;
      final debtAmount = isDebt ? newAmount - availableExcl : 0.0;
      final cleared = clearedForTransfer(t.id);
      if (cleared > debtAmount + 0.0001) {
        throw Exception(
          '${cleared.toStringAsFixed(2)} of debt was already cleared on this branch — remove those clearances first',
        );
      }
      t.isDebt = isDebt;
      t.debtAmount = debtAmount;
    }

    if (t.toCompanyId != null) {
      final nodeBalance = companyNodeBalance(t.paymentId, t.toCompanyId);
      final sliceUsed = t.amount - sliceRemaining(t);
      final minAllowed = [
        t.amount - nodeBalance,
        sliceUsed,
      ].reduce((a, b) => a > b ? a : b);
      if (newAmount < minAllowed - 0.0001) {
        throw Exception(
          'That money was already forwarded onward — amount cannot go below ${minAllowed.toStringAsFixed(2)}',
        );
      }
    }

    t.amount = newAmount;

    final clearanceTxIds = _debtBox.values
        .map((c) => c.cashTxId)
        .whereType<String>()
        .toSet();
    final cashTxs = _cashBox.values
        .where(
          (tx) =>
              tx.relatedTransferId == t.id && !clearanceTxIds.contains(tx.id),
        )
        .toList();
    for (final tx in cashTxs) {
      tx.amount = newAmount;
      await _cashBox.put(tx.id, tx);
    }
  }

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
      if (t != null) {
        paymentIds.add(t.paymentId);
        if (t.sourcePaymentId != null) paymentIds.add(t.sourcePaymentId!);
        if (t.parentTransferId == null && t.toCompanyId == null) {
          final p = _paymentBox.get(t.paymentId);
          if (p != null && t.id != p.rootTransferId) {
            p.amount -= t.amount;
            await _paymentBox.put(p.id, p);
          }
        }
      }
      final cashIds = _cashBox.values
          .where((tx) => tx.relatedTransferId == id)
          .map((tx) => tx.id)
          .toList();
      for (final cid in cashIds) {
        await _cashBox.delete(cid);
      }
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
    for (final c in debtClearances) {
      final pools = byCompany.putIfAbsent(c.companyId, () => {});
      pools[c.paymentId] = (pools[c.paymentId] ?? 0) + c.amount;
    }
    return {for (final e in byCompany.entries) e.key: e.value.values.toList()};
  }

  List<DebtClearanceModel> clearancesForTransfer(String transferId) {
    return debtClearances.where((c) => c.transferId == transferId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double clearedForTransfer(String transferId) {
    return _debtBox.values
        .where((c) => c.transferId == transferId)
        .fold(0.0, (s, c) => s + c.amount);
  }

  double remainingDebtForTransfer(TransferModel t) {
    if (!t.isDebt) return 0;
    final remaining = t.debtAmount - clearedForTransfer(t.id);
    return remaining > 0 ? remaining : 0;
  }

  bool isDebtFullyCleared(TransferModel t) {
    return t.isDebt && remainingDebtForTransfer(t) <= 0.0001;
  }

  DateTime? debtClearedDate(String transferId) {
    final list = clearancesForTransfer(transferId);
    if (list.isEmpty) return null;
    return list.last.date;
  }

  List<TransferModel> outstandingDebtTransfers(String paymentId) {
    return _transferBox.values
        .where((t) => t.paymentId == paymentId && t.isDebt)
        .where((t) => remainingDebtForTransfer(t) > 0.0001)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<DebtClearanceModel> clearDebt({
    required String transferId,
    required DebtClearSource source,
    required double amount,
    DateTime? date,
    String? note,
    String? sourcePaymentId,
  }) async {
    final t = getTransferById(transferId);
    if (t == null) throw Exception('Transfer not found');
    if (!t.isDebt) throw Exception('This branch has no debt to clear');

    final creditorId = t.fromCompanyId;
    if (creditorId == null) throw Exception('No creditor company');

    final payment = getPaymentById(t.paymentId);
    if (payment == null) throw Exception('Payment not found');

    if (amount <= 0) throw Exception('Enter an amount greater than zero');

    final remaining = remainingDebtForTransfer(t);
    if (amount > remaining + 0.0001) {
      throw Exception(
        'Amount exceeds remaining debt (${remaining.toStringAsFixed(2)})',
      );
    }

    if (sourcePaymentId != null && sourcePaymentId != payment.id) {
      final sourcePool = getPaymentById(sourcePaymentId);
      if (sourcePool == null) throw Exception('Source pool not found');
      final available = availableFromPool(sourcePool);
      if (amount > available + 0.0001) {
        throw Exception(
          'Pool ${sourcePool.code} only has ${available.toStringAsFixed(2)} available',
        );
      }
      await receiveIntoPool(
        paymentId: payment.id,
        amount: amount,
        sourcePaymentId: sourcePool.id,
        note: 'Transferred to clear debt on ${t.code}',
      );
    }

    final pool = availableFromPool(payment);
    if (amount > pool + 0.0001) {
      throw Exception(
        'Pool ${payment.code} only has ${pool.toStringAsFixed(2)} available',
      );
    }

    final when = date ?? DateTime.now();

    final cashTx = CashTransactionModel(
      id: _uuid.v4(),
      txType: CashTxType.deduct,
      amount: amount,
      description: 'Debt cleared from pool ${payment.code} (${t.code})',
      relatedPaymentId: t.paymentId,
      relatedTransferId: transferId,
      fromCompanyId: creditorId,
      date: when,
      createdAt: DateTime.now(),
    );
    await _cashBox.put(cashTx.id, cashTx);

    final clearance = DebtClearanceModel(
      id: _uuid.v4(),
      transferId: transferId,
      paymentId: t.paymentId,
      companyId: creditorId,
      amount: amount,
      source: source,
      cashTxId: cashTx.id,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      date: when,
      createdAt: DateTime.now(),
    );
    await _debtBox.put(clearance.id, clearance);

    await _updatePaymentStats(t.paymentId);
    loadAll();
    return clearance;
  }

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

  double get netPosition => totalOutstanding - totalDebtOwedByMe;

  double getCompanyBalance(String companyId) =>
      companyBalances[companyId] ?? 0.0;

  Map<String, dynamic> getCompanyBalanceDetails(String companyId) {
    final balance = getCompanyBalance(companyId);
    return {
      'companyId': companyId,
      'balance': balance,
      'status': balance > 0 ? 'owes_me' : (balance < 0 ? 'i_owe' : 'settled'),
      'amount': balance.abs(),
    };
  }

  List<PaymentModel> getPaymentsForCompany(String companyId) {
    return payments.where((p) => p.companyId == companyId).toList();
  }

  List<TransferModel> getTransfersForCompany(String companyId) {
    return transfers
        .where(
          (t) => t.fromCompanyId == companyId || t.toCompanyId == companyId,
        )
        .toList();
  }

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

  double get totalOutstanding =>
      companyOwedToMe.values.fold(0.0, (sum, v) => sum + v);
  double get totalDebtOwedByMe =>
      companyOwedByMe.values.fold(0.0, (sum, v) => sum + v);

  Future<TransferModel> receiveIntoPool({
    required String paymentId,
    required double amount,
    String? fromCompanyId,
    String? sourcePaymentId,
    String? note,
    String? label,
    DateTime? deadline,
  }) async {
    final payment = getPaymentById(paymentId);
    if (payment == null) throw Exception('Payment not found');
    if (amount <= 0) throw Exception('Enter an amount greater than zero');
    if (fromCompanyId != null && sourcePaymentId != null)
      throw Exception('Pick a single source');

    PaymentModel? sourcePool;
    if (sourcePaymentId != null) {
      if (sourcePaymentId == paymentId)
        throw Exception('A pool cannot fund itself');
      sourcePool = getPaymentById(sourcePaymentId);
      if (sourcePool == null) throw Exception('Source pool not found');
      final available = availableFromPool(sourcePool);
      if (amount > available + 0.0001) {
        throw Exception(
          'Pool ${sourcePool.code} only has ${available.toStringAsFixed(2)} available',
        );
      }
    }

    final transfer = TransferModel(
      id: _uuid.v4(),
      paymentId: paymentId,
      parentTransferId: null,
      amount: amount,
      fromCompanyId: fromCompanyId,
      toCompanyId: null,
      sourceType: TransferSourceType.fromTotal,
      note: note,
      createdAt: DateTime.now(),
      isDebt: fromCompanyId != null,
      debtAmount: fromCompanyId != null ? amount : 0,
      code: nextBranchCode(payment, null),
      label: label,
      deadline: deadline,
      sourcePaymentId: sourcePaymentId,
    );
    await _transferBox.put(transfer.id, transfer);

    if (sourcePaymentId == null) {
      final cashTx = CashTransactionModel(
        id: _uuid.v4(),
        txType: CashTxType.add,
        amount: amount,
        description: fromCompanyId == null
            ? 'Cash added to pool ${payment.code} (${transfer.code})'
            : 'Received into pool ${payment.code} (${transfer.code})',
        relatedPaymentId: paymentId,
        relatedTransferId: transfer.id,
        fromCompanyId: fromCompanyId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _cashBox.put(cashTx.id, cashTx);
    }

    payment.amount += amount;
    await _paymentBox.put(payment.id, payment);
    await _updatePaymentStats(paymentId);
    if (sourcePool != null) {
      await _updatePaymentStats(sourcePool.id);
    }
    loadAll();
    return transfer;
  }

  Future<void> deleteAllData() async {
    await _paymentBox.clear();
    await _transferBox.clear();
    await _cashBox.clear();
    await _debtBox.clear();
    loadAll();
  }

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
