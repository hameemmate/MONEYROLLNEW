import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/payment_model.dart';
import '../../models/transfer_model.dart';
import '../../models/debt_clearance_model.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../payments/payment_detail_screen.dart';
import 'common_widgets.dart';

class TransferTreeWidget extends StatefulWidget {
  final String paymentId;
  final bool allowAddTransfer;

  const TransferTreeWidget({
    super.key,
    required this.paymentId,
    this.allowAddTransfer = true,
  });

  @override
  State<TransferTreeWidget> createState() => _TransferTreeWidgetState();
}

class _TransferTreeWidgetState extends State<TransferTreeWidget> {
  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    final payment = payCtrl.getPaymentById(widget.paymentId);
    if (payment == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Payment not found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Exclude the root receipt from first‑level transfers
    final firstLevel =
        payCtrl
            .getPaymentTransfers(widget.paymentId)
            .where(
              (t) =>
                  t.parentTransferId == null && t.id != payment.rootTransferId,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final outgoingMoves = payCtrl.poolFundingsOutOf(widget.paymentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PoolCard(payment: payment, allowAdd: widget.allowAddTransfer),
        const SizedBox(height: 4),
        ...outgoingMoves.map((t) => _OutgoingPoolMoveCard(transfer: t)),
        ...firstLevel.map(
          (t) => _TransferNode(
            transfer: t,
            payment: payment,
            depth: 0,
            allowAdd: widget.allowAddTransfer,
          ),
        ),
      ],
    );
  }
}

class _OutgoingPoolMoveCard extends StatelessWidget {
  final TransferModel transfer;

  const _OutgoingPoolMoveCard({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final target = payCtrl.getPaymentById(transfer.paymentId);
    final targetCode = target?.code ?? '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blue.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.blueBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '→ $targetCode',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Moved to pool $targetCode' +
                  (transfer.label != null && transfer.label!.trim().isNotEmpty
                      ? ' · ${transfer.label!.trim()}'
                      : ''),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            AppUtils.formatAmount(transfer.amount),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'open' && target != null) {
                Get.to(() => PaymentDetailScreen(paymentId: target.id));
              } else if (v == 'edit') {
                showEditBranchSheet(context, transfer);
              } else if (v == 'delete') {
                confirmDeleteBranch(context, transfer);
              }
            },
            itemBuilder: (_) => [
              if (target != null)
                const PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 16),
                      SizedBox(width: 8),
                      Text('Open Pool'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Edit Amount'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16),
                    SizedBox(width: 8),
                    Text('Delete (return money)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  final PaymentModel payment;
  final bool allowAdd;

  const _PoolCard({required this.payment, required this.allowAdd});

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();
    final available = payCtrl.availableFromPool(payment);
    final source = payment.companyId != null
        ? compCtrl.getNameById(payment.companyId)
        : 'Cash / free entry';
    final bool debtPool =
        payment.type == PaymentType.received && payment.companyId != null;
    final Color accent = debtPool ? AppColors.debtRed : AppColors.gold;

    double receiptDebt = 0;
    if (debtPool && payment.rootTransferId != null) {
      final root = payCtrl.getTransferById(payment.rootTransferId!);
      if (root != null) receiptDebt = payCtrl.remainingDebtForTransfer(root);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  payment.code.isEmpty ? 'M?' : payment.code,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.label != null && payment.label!.trim().isNotEmpty
                      ? payment.label!.trim()
                      : debtPool
                      ? 'Debt pool · from $source'
                      : 'Pool · from $source',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                AppUtils.formatAmount(payment.amount),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          if (receiptDebt > 0.0001) ...[
            const SizedBox(height: 4),
            Text(
              'Debt to $source: ${AppUtils.formatAmount(receiptDebt)} outstanding',
              style: const TextStyle(fontSize: 11, color: AppColors.debtRed),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Available to branch: ${AppUtils.formatAmount(available)}',
            style: TextStyle(
              fontSize: 11,
              color: available > 0 ? AppColors.amber : AppColors.textMuted,
            ),
          ),
          if (allowAdd) ...[
            const SizedBox(height: 10),
            if (available <= 0 && !debtPool)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No funds available. Add money to the pool first.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (available > 0)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showAddBranchSheet(context, payment, null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.call_split,
                              size: 12,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Branch',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (available > 0) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showAddMoneyToPoolSheet(context, payment),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.green.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            size: 12,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Add Money',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.green,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (debtPool && receiptDebt > 0.0001) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showClearRootDebtSheet(context, payment),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.debtRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.debtRed.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.price_check,
                        size: 12,
                        color: AppColors.debtRed,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Clear remaining debt (${AppUtils.formatAmount(receiptDebt)})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.debtRed,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void showAddMoneyToPoolSheet(BuildContext context, PaymentModel payment) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final poolSearchCtrl = TextEditingController();
    DateTime? deadline;
    bool submitting = false;

    _PoolFundSource source = _PoolFundSource.freeCash;
    String? selectedCompanyId;
    String? selectedPoolId;
    String poolSearch = '';

    final nextCode = payCtrl.nextBranchCode(payment, null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final PaymentModel? selectedPool = selectedPoolId == null
              ? null
              : payCtrl.getPaymentById(selectedPoolId!);
          final double poolMax = selectedPool == null
              ? 0
              : payCtrl.availableFromPool(selectedPool);

          final q = poolSearch.trim().toLowerCase();
          final candidates = payCtrl.payments
              .where((p) => p.id != payment.id)
              .where((p) {
                if (q.isEmpty) return true;
                return p.code.toLowerCase().contains(q) ||
                    (p.label ?? '').toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q);
              })
              .toList();
          final funded =
              candidates
                  .where((p) => payCtrl.availableFromPool(p) > 0.0001)
                  .toList()
                ..sort(
                  (a, b) => payCtrl
                      .availableFromPool(b)
                      .compareTo(payCtrl.availableFromPool(a)),
                );
          final empty = candidates
              .where((p) => payCtrl.availableFromPool(p) <= 0.0001)
              .toList();

          String bannerText;
          switch (source) {
            case _PoolFundSource.freeCash:
              bannerText =
                  'Adds fresh cash into this pool and increases your cash in hand.';
              break;
            case _PoolFundSource.company:
              bannerText =
                  'Cash received from the company goes into this pool. It is recorded as debt you owe them.';
              break;
            case _PoolFundSource.pool:
              bannerText =
                  'Moves remaining balance from the selected pool into this one. No cash changes hands; both pools keep a record of the move.';
              break;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SafeArea(
              bottom: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Money to Pool ${payment.code}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bannerText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Where is the money coming from?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modeCard(
                      title: 'Free cash',
                      subtitle: 'New money without a company attached',
                      icon: Icons.payments_outlined,
                      selected: source == _PoolFundSource.freeCash,
                      enabled: true,
                      onTap: () => setModalState(() {
                        source = _PoolFundSource.freeCash;
                        selectedPoolId = null;
                      }),
                    ),
                    _modeCard(
                      title: 'From a company',
                      subtitle: 'Cash received — becomes debt you owe them',
                      icon: Icons.business_outlined,
                      selected: source == _PoolFundSource.company,
                      enabled: true,
                      onTap: () => setModalState(() {
                        source = _PoolFundSource.company;
                        selectedPoolId = null;
                      }),
                    ),
                    _modeCard(
                      title: 'From another pool',
                      subtitle: 'Move remaining balance between pools',
                      icon: Icons.swap_horiz,
                      selected: source == _PoolFundSource.pool,
                      enabled: true,
                      onTap: () => setModalState(() {
                        source = _PoolFundSource.pool;
                        selectedCompanyId = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    if (source == _PoolFundSource.company) ...[
                      DropdownButtonFormField<String>(
                        value: selectedCompanyId,
                        dropdownColor: AppColors.surfaceAlt,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'From company',
                        ),
                        items: compCtrl.companies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedCompanyId = val),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (source == _PoolFundSource.pool) ...[
                      TextField(
                        controller: poolSearchCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Search pools',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                        onChanged: (val) =>
                            setModalState(() => poolSearch = val),
                      ),
                      const SizedBox(height: 8),
                      if (funded.isEmpty && empty.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No other pools found.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      if (funded.isNotEmpty) ...[
                        const Text(
                          'Pools with balance',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...funded.map(
                          (p) => _poolTile(
                            p,
                            payCtrl,
                            selectedPoolId,
                            setModalState,
                          ),
                        ),
                      ],
                      if (empty.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Empty pools',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...empty.map(
                          (p) => _poolTile(
                            p,
                            payCtrl,
                            selectedPoolId,
                            setModalState,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Amount (AED)',
                        prefixText: 'د.إ ',
                        helperText: source == _PoolFundSource.pool
                            ? (selectedPool == null
                                  ? 'Select a source pool first'
                                  : 'Max ${AppUtils.formatAmount(poolMax, showSymbol: false)} from pool ${selectedPool.code}')
                            : null,
                      ),
                      onChanged: (val) {
                        if (source != _PoolFundSource.pool) return;
                        final parsed = double.tryParse(val);
                        if (parsed != null && poolMax > 0 && parsed > poolMax) {
                          amountCtrl.text = poolMax.toStringAsFixed(2);
                          amountCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: amountCtrl.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Branch label (optional)',
                        hintText: 'Names the $nextCode branch',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await _pickThemedDate(ctx, deadline);
                        if (picked != null)
                          setModalState(() => deadline = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              deadline == null
                                  ? 'Add deadline (optional)'
                                  : AppUtils.formatDate(deadline!),
                              style: TextStyle(
                                fontSize: 14,
                                color: deadline == null
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (deadline != null)
                              GestureDetector(
                                onTap: () =>
                                    setModalState(() => deadline = null),
                                child: const Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton(
                        label: 'Add to Pool',
                        icon: Icons.arrow_downward,
                        isLoading: submitting,
                        onTap: () async {
                          if (submitting) return;
                          final amt = double.tryParse(amountCtrl.text.trim());
                          if (amt == null || amt <= 0) {
                            AppUtils.showError('Error', 'Enter valid amount');
                            return;
                          }
                          if (source == _PoolFundSource.company &&
                              selectedCompanyId == null) {
                            AppUtils.showError(
                              'Error',
                              'Select the company the money came from',
                            );
                            return;
                          }
                          if (source == _PoolFundSource.pool &&
                              selectedPoolId == null) {
                            AppUtils.showError(
                              'Error',
                              'Select the pool to move money from',
                            );
                            return;
                          }
                          setModalState(() => submitting = true);
                          try {
                            await payCtrl.receiveIntoPool(
                              paymentId: payment.id,
                              amount: amt,
                              fromCompanyId: source == _PoolFundSource.company
                                  ? selectedCompanyId
                                  : null,
                              sourcePaymentId: source == _PoolFundSource.pool
                                  ? selectedPoolId
                                  : null,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              label: labelCtrl.text.trim().isEmpty
                                  ? null
                                  : labelCtrl.text.trim(),
                              deadline: deadline,
                            );
                            Navigator.pop(ctx);
                            AppUtils.showSuccess(
                              'Pool Funded',
                              '${AppUtils.formatAmount(amt)} added to pool ${payment.code}',
                            );
                          } catch (e) {
                            setModalState(() => submitting = false);
                            AppUtils.showError(
                              'Error',
                              e.toString().replaceFirst('Exception: ', ''),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _poolTile(
    PaymentModel p,
    PaymentController payCtrl,
    String? selectedPoolId,
    StateSetter setModalState,
  ) {
    final available = payCtrl.availableFromPool(p);
    final enabled = available > 0.0001;
    return _modeCard(
      title: p.label != null && p.label!.trim().isNotEmpty
          ? '${p.code} · ${p.label!.trim()}'
          : '${p.code} · ${p.description}',
      subtitle: enabled
          ? 'Available ${AppUtils.formatAmount(available)}'
          : 'Empty pool — nothing left to move',
      icon: Icons.circle_outlined,
      selected: selectedPoolId == p.id,
      enabled: enabled,
      onTap: () => setModalState(() => selectedPoolId = p.id),
    );
  }
}

enum _PoolFundSource { freeCash, company, pool }

class _TransferNode extends StatefulWidget {
  final TransferModel transfer;
  final PaymentModel payment;
  final int depth;
  final bool allowAdd;

  const _TransferNode({
    required this.transfer,
    required this.payment,
    required this.depth,
    required this.allowAdd,
  });

  @override
  State<_TransferNode> createState() => _TransferNodeState();
}

class _TransferNodeState extends State<_TransferNode> {
  bool _expanded = true;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();
    final children = payCtrl.getChildTransfers(widget.transfer.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final hasChildren = children.isNotEmpty;

    final sourcePool = widget.transfer.sourcePaymentId == null
        ? null
        : payCtrl.getPaymentById(widget.transfer.sourcePaymentId!);
    final isIncoming =
        widget.transfer.parentTransferId == null &&
        widget.transfer.toCompanyId == null;
    final fromName = sourcePool != null
        ? 'Pool ${sourcePool.code}'
        : widget.transfer.sourcePaymentId != null
        ? 'Pool ?'
        : widget.transfer.fromCompanyId == null
        ? 'Me'
        : compCtrl.getNameById(widget.transfer.fromCompanyId);
    final isReturnToMe = widget.transfer.toCompanyId == null;
    final toName = isIncoming
        ? 'Pool ${widget.payment.code}'
        : isReturnToMe
        ? 'Me (returned)'
        : compCtrl.getNameById(widget.transfer.toCompanyId);

    final nodeColor = widget.transfer.isDebt
        ? AppColors.debtRed
        : isReturnToMe
        ? AppColors.green
        : AppColors.gold;
    final canBranch = widget.allowAdd && !isReturnToMe;

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nodeCard(
            context,
            fromName,
            toName,
            nodeColor,
            hasChildren,
            canBranch,
            payCtrl,
            compCtrl,
          ),
          if (_expanded && hasChildren)
            ...children.map(
              (child) => _TransferNode(
                transfer: child,
                payment: widget.payment,
                depth: widget.depth + 1,
                allowAdd: widget.allowAdd,
              ),
            ),
          if (_expanded && canBranch)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2, bottom: 6),
              child: GestureDetector(
                onTap: () => showAddBranchSheet(
                  context,
                  widget.payment,
                  widget.transfer,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 13, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        'From $toName (${payCtrl.nextBranchCode(widget.payment, widget.transfer)})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nodeCard(
    BuildContext context,
    String fromName,
    String toName,
    Color nodeColor,
    bool hasChildren,
    bool canBranch,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final t = widget.transfer;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: hasChildren
            ? () => setState(() => _expanded = !_expanded)
            : null,
        onLongPress: () =>
            _showBranchOptionsSheet(context, t, payCtrl, compCtrl),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: t.isDebt
                  ? AppColors.debtRed.withOpacity(0.5)
                  : AppColors.border,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: nodeColor.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: nodeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.code.isEmpty ? '—' : t.code,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: nodeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (t.label != null && t.label!.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        t.label!.trim(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (t.deadline != null) ...[
                    DeadlineChip(deadline: t.deadline!, compact: true),
                    const SizedBox(width: 4),
                  ],
                  if (hasChildren)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textMuted,
                    ),
                    color: AppColors.surface,
                    onSelected: (v) {
                      if (v == 'details') {
                        _showBranchDetailsSheet(context, t, payCtrl, compCtrl);
                      } else if (v == 'edit') {
                        showEditBranchSheet(context, t);
                      } else if (v == 'delete') {
                        confirmDeleteBranch(context, t);
                      } else if (v == 'branch' && canBranch) {
                        showAddBranchSheet(
                          context,
                          widget.payment,
                          widget.transfer,
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit Branch'),
                          ],
                        ),
                      ),
                      if (canBranch)
                        const PopupMenuItem(
                          value: 'branch',
                          child: Row(
                            children: [
                              Icon(Icons.call_split, size: 16),
                              SizedBox(width: 8),
                              Text('Add Child Branch'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16),
                            SizedBox(width: 8),
                            Text('Delete Branch'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showCompanyDetails(
                            context,
                            t.fromCompanyId,
                            compCtrl,
                          ),
                          child: CompanyAvatar(name: fromName, size: 24),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _showCompanyDetails(
                              context,
                              t.fromCompanyId,
                              compCtrl,
                            ),
                            child: Text(
                              fromName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 13,
                            color: nodeColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showCompanyDetails(
                            context,
                            t.toCompanyId,
                            compCtrl,
                          ),
                          child: CompanyAvatar(name: toName, size: 24),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _showCompanyDetails(
                              context,
                              t.toCompanyId,
                              compCtrl,
                            ),
                            child: Text(
                              toName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppUtils.formatAmount(t.amount),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: nodeColor,
                    ),
                  ),
                ],
              ),
              if (t.sourceType == TransferSourceType.fromSpecific ||
                  t.isDebt) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (t.sourceType == TransferSourceType.fromSpecific)
                      _badge(
                        'Specific slice',
                        AppColors.blue,
                        AppColors.blueBg,
                      ),
                    if (t.isDebt) ...[
                      if (payCtrl.isDebtFullyCleared(t))
                        _badge(
                          payCtrl.debtClearedDate(t.id) != null
                              ? 'Cleared ${AppUtils.formatDateShort(payCtrl.debtClearedDate(t.id)!)}'
                              : 'Cleared',
                          AppColors.green,
                          AppColors.greenBg,
                        )
                      else ...[
                        GestureDetector(
                          onTap: () => showClearDebtSheet(context, t),
                          child: _badge(
                            'Debt +${AppUtils.formatAmount(payCtrl.remainingDebtForTransfer(t))} · Clear',
                            AppColors.debtRed,
                            AppColors.debtBg,
                          ),
                        ),
                        if (payCtrl.clearedForTransfer(t.id) > 0.0001)
                          _badge(
                            'Cleared ${AppUtils.formatAmount(payCtrl.clearedForTransfer(t.id))}',
                            AppColors.green,
                            AppColors.greenBg,
                          ),
                      ],
                    ],
                  ],
                ),
              ],
              if (t.note != null && t.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t.note!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (canBranch && _hovered) ...[
                const SizedBox(height: 8),
                Divider(color: AppColors.border.withOpacity(0.5), height: 1),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => showAddBranchSheet(
                    context,
                    widget.payment,
                    widget.transfer,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.call_split,
                          size: 12,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add child branch (${payCtrl.nextBranchCode(widget.payment, widget.transfer)})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
    ),
  );

  void _showBranchOptionsSheet(
    BuildContext context,
    TransferModel transfer,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          transfer.code,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transfer.label ?? 'Branch Transaction',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _optionTile(
                    icon: Icons.info_outline,
                    title: 'View Details',
                    subtitle: 'See complete branch information',
                    color: AppColors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _showBranchDetailsSheet(
                        context,
                        transfer,
                        payCtrl,
                        compCtrl,
                      );
                    },
                  ),
                  _optionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Branch',
                    subtitle: 'Change label, note, or deadline',
                    color: AppColors.gold,
                    onTap: () {
                      Navigator.pop(context);
                      showEditBranchSheet(context, transfer);
                    },
                  ),
                  _optionTile(
                    icon: Icons.add_link,
                    title: 'Add Child Branch',
                    subtitle: 'Forward money from this branch',
                    color: AppColors.green,
                    onTap: () {
                      Navigator.pop(context);
                      showAddBranchSheet(context, widget.payment, transfer);
                    },
                  ),
                  if (transfer.isDebt &&
                      payCtrl.remainingDebtForTransfer(transfer) > 0.0001)
                    _optionTile(
                      icon: Icons.price_check,
                      title: 'Clear Debt',
                      subtitle:
                          'Settle ${AppUtils.formatAmount(payCtrl.remainingDebtForTransfer(transfer))} owed',
                      color: AppColors.debtRed,
                      onTap: () {
                        Navigator.pop(context);
                        showClearDebtSheet(context, transfer);
                      },
                    ),
                  _optionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Branch',
                    subtitle: 'Remove this branch and all children',
                    color: AppColors.red,
                    onTap: () {
                      Navigator.pop(context);
                      confirmDeleteBranch(context, transfer);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBranchDetailsSheet(
    BuildContext context,
    TransferModel transfer,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final fromName = transfer.fromCompanyId == null
        ? 'Me (Cash)'
        : compCtrl.getNameById(transfer.fromCompanyId);
    final toName = transfer.toCompanyId == null
        ? 'Me (Pool)'
        : compCtrl.getNameById(transfer.toCompanyId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transfer.code,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (transfer.label != null && transfer.label!.isNotEmpty)
                    Text(
                      transfer.label!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('From', fromName, Icons.arrow_upward, AppColors.red),
              const SizedBox(height: 12),
              _detailRow('To', toName, Icons.arrow_downward, AppColors.green),
              const SizedBox(height: 12),
              _detailRow(
                'Amount',
                AppUtils.formatAmount(transfer.amount),
                Icons.attach_money,
                AppColors.gold,
              ),
              if (transfer.isDebt) ...[
                const SizedBox(height: 12),
                _detailRow(
                  'Debt',
                  AppUtils.formatAmount(transfer.debtAmount),
                  Icons.warning,
                  AppColors.debtRed,
                ),
                if (payCtrl.clearedForTransfer(transfer.id) > 0.0001) ...[
                  const SizedBox(height: 12),
                  _detailRow(
                    'Cleared',
                    AppUtils.formatAmount(
                      payCtrl.clearedForTransfer(transfer.id),
                    ),
                    Icons.check_circle_outline,
                    AppColors.green,
                  ),
                ],
                if (payCtrl.isDebtFullyCleared(transfer)) ...[
                  const SizedBox(height: 12),
                  _detailRow(
                    'Status',
                    payCtrl.debtClearedDate(transfer.id) != null
                        ? 'Cleared on ${AppUtils.formatDate(payCtrl.debtClearedDate(transfer.id)!)}'
                        : 'Cleared',
                    Icons.verified,
                    AppColors.green,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _detailRow(
                    'Remaining debt',
                    AppUtils.formatAmount(
                      payCtrl.remainingDebtForTransfer(transfer),
                    ),
                    Icons.pending_outlined,
                    AppColors.debtRed,
                  ),
                ],
              ],
              if (transfer.sourceType == TransferSourceType.fromSpecific) ...[
                const SizedBox(height: 12),
                _detailRow(
                  'Source',
                  'Specific slice',
                  Icons.lock,
                  AppColors.blue,
                ),
              ],
              if (transfer.note != null && transfer.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Note:',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(transfer.note!, style: const TextStyle(fontSize: 13)),
              ],
              if (transfer.deadline != null) ...[
                const SizedBox(height: 12),
                _detailRow(
                  'Deadline',
                  AppUtils.formatDate(transfer.deadline!),
                  Icons.flag,
                  AppColors.amber,
                ),
              ],
              const SizedBox(height: 20),
              if (transfer.isDebt &&
                  payCtrl.remainingDebtForTransfer(transfer) > 0.0001) ...[
                SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: 'Clear Debt',
                    icon: Icons.price_check,
                    onTap: () {
                      Navigator.pop(context);
                      showClearDebtSheet(context, transfer);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      isOutlined: true,
                      onTap: () {
                        Navigator.pop(context);
                        showEditBranchSheet(context, transfer);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoldButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      isOutlined: true,
                      onTap: () {
                        Navigator.pop(context);
                        confirmDeleteBranch(context, transfer);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _optionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
        ],
      ),
    ),
  );

  void _showCompanyDetails(
    BuildContext context,
    String? companyId,
    CompanyController compCtrl,
  ) {
    if (companyId == null) return;
    final company = compCtrl.getById(companyId);
    if (company == null) return;
    Get.snackbar(
      company.name,
      company.phone != null ? 'Phone: ${company.phone}' : 'No contact info',
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.gold.withOpacity(0.9),
      colorText: AppColors.onGold,
    );
  }
}

void showAddBranchSheet(
  BuildContext context,
  PaymentModel payment,
  TransferModel? parent,
) {
  final payCtrl = Get.find<PaymentController>();
  final compCtrl = Get.find<CompanyController>();

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  String? selectedTo;
  TransferSourceType sourceType = TransferSourceType.fromTotal;
  DateTime? deadline;
  bool submitting = false;
  String? selectedSliceTransferId;

  final bool fromPool = parent == null;
  final String fromName = fromPool
      ? 'Pool ${payment.code} (Me)'
      : compCtrl.getNameById(parent?.toCompanyId);
  final String nextCode = payCtrl.nextBranchCode(payment, parent);

  List<TransferModel> incomingSlices = [];
  if (!fromPool && parent != null) {
    incomingSlices = payCtrl.transfers
        .where(
          (t) =>
              t.paymentId == payment.id && t.toCompanyId == parent.toCompanyId,
        )
        .toList();
  }

  final String companyName = fromPool
      ? ''
      : compCtrl.getNameById(parent?.toCompanyId);
  final double totalAvail = fromPool
      ? payCtrl.availableFromPool(payment)
      : payCtrl.companyNodeBalance(payment.id, parent!.toCompanyId);
  final bool totalUsed =
      !fromPool && payCtrl.hasTotalForward(payment.id, parent!.toCompanyId);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        TransferModel? selectedSlice;
        double sliceRemaining = 0;
        if (selectedSliceTransferId != null) {
          selectedSlice = payCtrl.getTransferById(selectedSliceTransferId!);
          if (selectedSlice != null)
            sliceRemaining = payCtrl.sliceRemaining(selectedSlice);
        }
        final bool sliceMode = sourceType == TransferSourceType.fromSpecific;
        final double available = sliceMode ? sliceRemaining : totalAvail;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Branch from $fromName',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nextCode,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Available: ${AppUtils.formatAmount(available)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!fromPool) ...[
                    Text(
                      'How is $companyName sending this?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modeCard(
                      title: 'Combined balance',
                      subtitle:
                          'Send any amount up to ${AppUtils.formatAmount(totalAvail)}',
                      icon: Icons.account_balance_wallet_outlined,
                      selected:
                          sourceType == TransferSourceType.fromTotal &&
                          !sliceMode,
                      enabled: true,
                      onTap: () => setModalState(() {
                        sourceType = TransferSourceType.fromTotal;
                        selectedSliceTransferId = null;
                        amountCtrl.clear();
                      }),
                    ),
                    if (totalUsed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Slices merged — $companyName already sent from its combined total in this pool.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    if (!totalUsed && incomingSlices.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Specific slices (lock to one incoming payment)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...incomingSlices.map((slice) {
                        final sliceRem = payCtrl.sliceRemaining(slice);
                        final fromName = slice.fromCompanyId == null
                            ? 'Me'
                            : compCtrl.getNameById(slice.fromCompanyId);
                        final isSelected = selectedSliceTransferId == slice.id;
                        return _modeCard(
                          title: '${slice.code} · From $fromName',
                          subtitle: sliceRem > 0
                              ? '${AppUtils.formatAmount(sliceRem)} available'
                              : 'Already fully forwarded',
                          icon: Icons.lock_outline,
                          selected: isSelected,
                          enabled: sliceRem > 0.0001,
                          onTap: () => setModalState(() {
                            sourceType = TransferSourceType.fromSpecific;
                            selectedSliceTransferId = slice.id;
                            amountCtrl.text = sliceRem.toStringAsFixed(2);
                          }),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: amountCtrl,
                    readOnly: sliceMode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: sliceMode
                          ? 'Amount (locked slice)'
                          : 'Amount (AED)',
                      prefixText: 'د.إ ',
                      helperText: sliceMode
                          ? 'This slice amount is fixed'
                          : null,
                      helperStyle: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTo,
                    dropdownColor: AppColors.surfaceAlt,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Send To'),
                    items: [
                      if (!fromPool)
                        const DropdownMenuItem(
                          value: '__me__',
                          child: Text(
                            'Return to pool (Me)',
                            style: TextStyle(color: AppColors.green),
                          ),
                        ),
                      ...compCtrl.companies
                          .where((c) => fromPool || c.id != parent?.toCompanyId)
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                    ],
                    onChanged: (val) => setModalState(() => selectedTo = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Branch label (optional)',
                      hintText: 'Names the $nextCode branch',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickThemedDate(ctx, deadline);
                      if (picked != null)
                        setModalState(() => deadline = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            deadline == null
                                ? 'Add deadline (optional)'
                                : AppUtils.formatDate(deadline!),
                            style: TextStyle(
                              fontSize: 14,
                              color: deadline == null
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (deadline != null)
                            GestureDetector(
                              onTap: () => setModalState(() => deadline = null),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: GoldButton(
                      label: 'Add Branch',
                      isLoading: submitting,
                      onTap: () async {
                        if (submitting) return;
                        double? amt;
                        String? specificParentId;
                        if (sliceMode) {
                          if (selectedSliceTransferId == null) {
                            AppUtils.showError(
                              'Error',
                              'Select a slice to forward',
                            );
                            return;
                          }
                          amt = sliceRemaining;
                          specificParentId = selectedSliceTransferId;
                        } else {
                          amt = double.tryParse(amountCtrl.text.trim());
                        }
                        if (amt == null || amt <= 0 || selectedTo == null) {
                          AppUtils.showError(
                            'Error',
                            'Enter an amount and pick a recipient',
                          );
                          return;
                        }
                        final toId = selectedTo == '__me__' ? null : selectedTo;
                        setModalState(() => submitting = true);
                        try {
                          await payCtrl.addTransfer(
                            paymentId: payment.id,
                            parentTransferId: parent?.id,
                            fromCompanyId: fromPool
                                ? null
                                : parent?.toCompanyId,
                            toCompanyId: toId,
                            amount: amt,
                            sourceType: sourceType,
                            specificParentTransferId: specificParentId,
                            label: labelCtrl.text.trim().isEmpty
                                ? null
                                : labelCtrl.text.trim(),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            deadline: deadline,
                          );
                          Navigator.pop(ctx);
                          AppUtils.showSuccess(
                            'Branch Added',
                            'Transfer saved',
                          );
                        } catch (e) {
                          setModalState(() => submitting = false);
                          AppUtils.showError('Error', e.toString());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _modeCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required bool selected,
  required bool enabled,
  required VoidCallback onTap,
}) {
  final Color accent = enabled ? AppColors.gold : AppColors.textMuted;
  return Opacity(
    opacity: enabled ? 1 : 0.55,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withOpacity(0.10)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio(
              value: true,
              groupValue: selected,
              onChanged: enabled ? (_) => onTap() : null,
              activeColor: AppColors.gold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<DateTime?> _pickThemedDate(BuildContext context, DateTime? initial) =>
    showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.gold,
            surface: AppColors.surface,
            onPrimary: AppColors.onGold,
          ),
        ),
        child: child!,
      ),
    );

void showEditBranchSheet(BuildContext context, TransferModel t) {
  final payCtrl = Get.find<PaymentController>();
  final labelCtrl = TextEditingController(text: t.label ?? '');
  final noteCtrl = TextEditingController(text: t.note ?? '');
  final amountCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
  DateTime? deadline = t.deadline;
  bool submitting = false;

  final payment = payCtrl.getPaymentById(t.paymentId);
  final bool isRootReceipt = payment != null && payment.rootTransferId == t.id;
  final bool amountEditable = !isRootReceipt;
  double? maxAmount;
  String amountHelper;
  if (isRootReceipt) {
    amountHelper = 'Original receipt — edit the pool amount instead';
  } else if (t.parentTransferId == null &&
      t.toCompanyId == null &&
      t.sourcePaymentId != null) {
    final source = payCtrl.getPaymentById(t.sourcePaymentId!);
    maxAmount =
        t.amount + (source == null ? 0 : payCtrl.availableFromPool(source));
    amountHelper =
        'Max ${AppUtils.formatAmount(maxAmount, showSymbol: false)} — limited by pool ${source?.code ?? '?'}';
  } else if (t.parentTransferId == null && t.toCompanyId == null) {
    amountHelper = 'Resizes this top-up; the pool grows or shrinks with it';
  } else if (t.parentTransferId == null &&
      t.toCompanyId != null &&
      payment != null) {
    maxAmount = t.amount + payCtrl.availableFromPool(payment);
    amountHelper =
        'Max ${AppUtils.formatAmount(maxAmount, showSymbol: false)} — limited by pool ${payment.code}';
  } else {
    amountHelper =
        'Any amount — the excess over the sender\'s balance becomes debt';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Edit branch ${t.code}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  readOnly: !amountEditable,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Amount (AED)',
                    prefixText: 'د.إ ',
                    helperText: amountHelper,
                    helperMaxLines: 2,
                    helperStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onChanged: (val) {
                    final cap = maxAmount;
                    final parsed = double.tryParse(val);
                    if (cap != null && parsed != null && parsed > cap) {
                      amountCtrl.text = cap.toStringAsFixed(2);
                      amountCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: amountCtrl.text.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Branch label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickThemedDate(ctx, deadline);
                    if (picked != null) setModalState(() => deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          deadline == null
                              ? 'Add deadline (optional)'
                              : AppUtils.formatDate(deadline!),
                          style: TextStyle(
                            fontSize: 14,
                            color: deadline == null
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (deadline != null)
                          GestureDetector(
                            onTap: () => setModalState(() => deadline = null),
                            child: const Icon(
                              Icons.clear,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: 'Save Changes',
                    isLoading: submitting,
                    onTap: () async {
                      if (submitting) return;
                      double? amt;
                      if (amountEditable) {
                        amt = double.tryParse(amountCtrl.text.trim());
                        if (amt == null || amt <= 0) {
                          AppUtils.showError('Error', 'Enter valid amount');
                          return;
                        }
                      }
                      setModalState(() => submitting = true);
                      try {
                        await payCtrl.updateTransfer(
                          t.id,
                          label: labelCtrl.text.trim(),
                          note: noteCtrl.text.trim(),
                          deadline: deadline,
                          amount: amt,
                        );
                        Navigator.pop(ctx);
                        AppUtils.showSuccess('Branch Updated', 'Changes saved');
                      } catch (e) {
                        setModalState(() => submitting = false);
                        AppUtils.showError(
                          'Error',
                          e.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void showClearDebtSheet(BuildContext context, TransferModel t) {
  final payCtrl = Get.find<PaymentController>();
  final compCtrl = Get.find<CompanyController>();

  final payment = payCtrl.getPaymentById(t.paymentId);
  if (payment == null) return;
  if (!t.isDebt) return;

  final creditorName = compCtrl.getNameById(t.fromCompanyId);
  final remaining = payCtrl.remainingDebtForTransfer(t);
  final poolAvailable = payCtrl.availableFromPool(payment);
  final double maxClearable = remaining < poolAvailable
      ? remaining
      : poolAvailable;

  final amountCtrl = TextEditingController(
    text: (maxClearable > 0 ? maxClearable : 0).toStringAsFixed(2),
  );
  final noteCtrl = TextEditingController();
  const DebtClearSource source = DebtClearSource.pool;
  DateTime date = DateTime.now();
  bool submitting = false;
  String? selectedPoolId;
  String poolSearch = '';

  final otherPools = payCtrl.payments
      .where((p) => p.id != payment.id && payCtrl.availableFromPool(p) > 0.0001)
      .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final q = poolSearch.trim().toLowerCase();
        final filtered = otherPools.where((p) {
          if (q.isEmpty) return true;
          return p.code.toLowerCase().contains(q) ||
              (p.label?.toLowerCase().contains(q) ?? false) ||
              p.description.toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Clear debt ${t.code}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You owe $creditorName ${AppUtils.formatAmount(remaining)} on this branch.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Amount to clear',
                      prefixText: '${AppConstants.currencySymbol} ',
                      helperText:
                          'Max ${AppUtils.formatAmount(maxClearable > 0 ? maxClearable : 0, showSymbol: false)} (pool balance and remaining debt)',
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null &&
                          maxClearable > 0 &&
                          parsed > maxClearable) {
                        amountCtrl.text = maxClearable.toStringAsFixed(2);
                        amountCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: amountCtrl.text.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Source of funds', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedPoolId == null
                          ? AppColors.gold.withOpacity(0.10)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedPoolId == null
                            ? AppColors.gold
                            : AppColors.border,
                        width: selectedPoolId == null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 20,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From this pool ${payment.code}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Available ${AppUtils.formatAmount(poolAvailable)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio(
                          value: true,
                          groupValue: selectedPoolId == null,
                          onChanged: (_) =>
                              setModalState(() => selectedPoolId = null),
                          activeColor: AppColors.gold,
                        ),
                      ],
                    ),
                  ),
                  if (otherPools.isNotEmpty) ...[
                    const Text(
                      'From another pool',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) => setModalState(() => poolSearch = val),
                      decoration: const InputDecoration(
                        hintText: 'Search pools...',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...filtered.map((pool) {
                      final available = payCtrl.availableFromPool(pool);
                      final isSelected = selectedPoolId == pool.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withOpacity(0.10)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 20,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pool.label != null &&
                                            pool.label!.trim().isNotEmpty
                                        ? '${pool.code} · ${pool.label!.trim()}'
                                        : '${pool.code} · ${pool.description}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Available ${AppUtils.formatAmount(available)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio(
                              value: true,
                              groupValue: isSelected,
                              onChanged: (_) =>
                                  setModalState(() => selectedPoolId = pool.id),
                              activeColor: AppColors.gold,
                            ),
                          ],
                        ),
                      );
                    }),
                    if (filtered.isEmpty)
                      const Text(
                        'No other pools with balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickThemedDate(ctx, date);
                      if (picked != null) setModalState(() => date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Cleared on ${AppUtils.formatDate(date)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: GoldButton(
                      label: 'Clear Debt',
                      icon: Icons.price_check,
                      isLoading: submitting,
                      onTap: () async {
                        if (submitting) return;
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          AppUtils.showError(
                            'Invalid amount',
                            'Enter an amount greater than zero',
                          );
                          return;
                        }
                        setModalState(() => submitting = true);
                        try {
                          await payCtrl.clearDebt(
                            transferId: t.id,
                            source: source,
                            amount: amount,
                            date: date,
                            note: noteCtrl.text.trim(),
                            sourcePaymentId: selectedPoolId,
                          );
                          Navigator.pop(ctx);
                          AppUtils.showSuccess(
                            'Debt Cleared',
                            '${AppUtils.formatAmount(amount)} settled for $creditorName',
                          );
                        } catch (e) {
                          setModalState(() => submitting = false);
                          AppUtils.showError(
                            'Error',
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

void showClearRootDebtSheet(BuildContext context, PaymentModel payment) {
  final payCtrl = Get.find<PaymentController>();
  if (payment.rootTransferId == null) return;
  final root = payCtrl.getTransferById(payment.rootTransferId!);
  if (root == null || !root.isDebt) return;
  showClearDebtSheet(context, root);
}

void confirmDeleteBranch(BuildContext context, TransferModel t) {
  final payCtrl = Get.find<PaymentController>();
  final childCount = payCtrl.getChildTransfers(t.id).isNotEmpty
      ? ' and everything under it'
      : '';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Delete ${t.code}?',
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        'This deletes this branch$childCount and updates balances and cash. This cannot be undone.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await payCtrl.deleteTransfer(t.id);
            AppUtils.showSuccess('Deleted', 'Branch ${t.code} removed');
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
}
