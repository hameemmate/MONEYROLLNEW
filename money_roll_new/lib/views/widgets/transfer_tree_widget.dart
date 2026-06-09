import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/payment_model.dart';
import '../../models/transfer_model.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import 'common_widgets.dart';

/// Renders a payment as a branchable pool (M1) with its full transfer tree.
/// First-level branches (M1B1, M1B2 ...) hang directly under the pool;
/// deeper branches advance the letter by depth (M1B1C1, M1B1C1D1 ...).
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

    final firstLevel =
        payCtrl
            .getPaymentTransfers(widget.paymentId)
            .where((t) => t.parentTransferId == null)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PoolCard(payment: payment, allowAdd: widget.allowAddTransfer),
        const SizedBox(height: 4),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  payment.code.isEmpty ? 'M?' : payment.code,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.label != null && payment.label!.trim().isNotEmpty
                      ? payment.label!.trim()
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
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
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

            // Show available amount warning if low
            if (available <= 0)
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
                        'No funds available. Receive money first.',
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
                    onTap: () => showReceiveIntoPoolSheet(context, payment),
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
                              'Receive',
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
          ],
        ],
      ),
    );
  }

  /// Bottom sheet to receive money into the payment pool
  void showReceiveIntoPoolSheet(BuildContext context, PaymentModel payment) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String? fromCompanyId; // null = cash, otherwise company ID
    DateTime? deadline;
    bool submitting = false;

    final nextCode = payCtrl.nextBranchCode(payment, null);

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
                    'Receive to Pool ${payment.code}',
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
                            'Receive money from company or cash. This increases the pool amount available for branching.',
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Amount (AED)',
                      prefixText: 'د.إ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: fromCompanyId,
                    dropdownColor: AppColors.surfaceAlt,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'From',
                      hintText: 'Who is sending this money?',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Cash / No company'),
                      ),
                      ...compCtrl.companies.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              CompanyAvatar(name: c.name, size: 22),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setModalState(() => fromCompanyId = val),
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
                      if (picked != null) {
                        setModalState(() => deadline = picked);
                      }
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
                      label: 'Receive to Pool',
                      icon: Icons.arrow_downward,
                      isLoading: submitting,
                      onTap: () async {
                        if (submitting) return;
                        final amt = double.tryParse(amountCtrl.text.trim());
                        if (amt == null || amt <= 0) {
                          AppUtils.showError('Error', 'Enter valid amount');
                          return;
                        }

                        setModalState(() => submitting = true);
                        try {
                          await payCtrl.receiveIntoPool(
                            paymentId: payment.id,
                            fromCompanyId: fromCompanyId,
                            amount: amt,
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
                            'Received',
                            '${AppUtils.formatAmount(amt)} received into pool',
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
        ),
      ),
    );
  }
}

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
  bool _hovered = false; // desktop hover, drives the subtle shadow only

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();
    final children = payCtrl.getChildTransfers(widget.transfer.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final hasChildren = children.isNotEmpty;

    final fromName = widget.transfer.fromCompanyId == null
        ? 'Me'
        : compCtrl.getNameById(widget.transfer.fromCompanyId);
    final isReturnToMe = widget.transfer.toCompanyId == null;
    final toName = isReturnToMe
        ? 'Me (returned)'
        : compCtrl.getNameById(widget.transfer.toCompanyId);

    final nodeColor = widget.transfer.isDebt
        ? AppColors.debtRed
        : isReturnToMe
        ? AppColors.green
        : AppColors.gold;

    // Can branch onward only when this node holds money at a company.
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
                  // Expand/collapse indicator (only when there are children)
                  if (hasChildren)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  // Actions menu — always shown, pinned to the right of every branch
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
                      _badge(
                        'Debt +${AppUtils.formatAmount(t.debtAmount)}',
                        AppColors.debtRed,
                        AppColors.debtBg,
                      ),
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
              // Quick "add child branch" action shown inline on desktop hover.
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

  Widget _badge(String label, Color fg, Color bg) {
    return Container(
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
  }

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
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

  Widget _detailRow(String label, String value, IconData icon, Color color) {
    return Row(
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
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
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
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

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

/// Bottom sheet to add a branch. [parent] null = branch from the payment pool
/// (ME → company); otherwise branch from that node (company → company / ME).
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

  // For slice selection
  String? selectedSliceTransferId;

  final bool fromPool = parent == null;
  final String fromName = fromPool
      ? 'Pool ${payment.code} (Me)'
      : compCtrl.getNameById(parent?.toCompanyId);
  final String nextCode = payCtrl.nextBranchCode(payment, parent);

  // Get all incoming slices for this company (when branching from a company node)
  List<TransferModel> incomingSlices = [];
  if (!fromPool && parent != null) {
    // Get ALL transfers that went TO this company in this payment
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

  // Check if total has been used already
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
        // Get the selected slice transfer
        TransferModel? selectedSlice;
        double sliceRemaining = 0;
        if (selectedSliceTransferId != null) {
          selectedSlice = payCtrl.getTransferById(selectedSliceTransferId!);
          if (selectedSlice != null) {
            sliceRemaining = payCtrl.sliceRemaining(selectedSlice);
          }
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

                  // How is the money being sent? (only for company nodes)
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

                    // Option 1: Combined balance (only if not already used)
                    if (!totalUsed)
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

                    // Option 2: Specific slices (show all incoming transfers)
                    if (incomingSlices.isNotEmpty) ...[
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
                      // Returning to the pool only makes sense from a company node.
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

                  // Deadline (optional)
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickThemedDate(ctx, deadline);
                      if (picked != null) {
                        setModalState(() => deadline = picked);
                      }
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
                          AppUtils.showSuccess('Branch Added', 'Transfer saved');
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

/// A selectable card explaining one way to send money (combined vs locked slice).
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

/// A light-themed date picker shared by the branch sheets.
Future<DateTime?> _pickThemedDate(BuildContext context, DateTime? initial) {
  return showDatePicker(
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
}

/// Edit a branch's label, note and deadline (amount/structure stay fixed).
void showEditBranchSheet(BuildContext context, TransferModel t) {
  final payCtrl = Get.find<PaymentController>();
  final labelCtrl = TextEditingController(text: t.label ?? '');
  final noteCtrl = TextEditingController(text: t.note ?? '');
  DateTime? deadline = t.deadline;
  bool submitting = false;

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
                      setModalState(() => submitting = true);
                      try {
                        await payCtrl.updateTransfer(
                          t.id,
                          label: labelCtrl.text.trim(),
                          note: noteCtrl.text.trim(),
                          deadline: deadline,
                        );
                        Navigator.pop(ctx);
                        AppUtils.showSuccess('Branch Updated', 'Changes saved');
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
      ),
    ),
  );
}

/// Confirm and delete a branch (and all branches below it).
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
        'This deletes this branch$childCount and updates balances and cash. '
        'This cannot be undone.',
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
