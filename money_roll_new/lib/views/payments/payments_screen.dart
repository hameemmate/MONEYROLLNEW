import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/payment_model.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import 'payment_detail_screen.dart';
import 'add_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  PaymentType? _filterType;
  String? _filterCompanyId;

  List<PaymentModel> _filtered(
    List<PaymentModel> all,
    CompanyController compCtrl,
  ) {
    return all.where((p) {
      if (_filterType != null && p.type != _filterType) return false;
      if (_filterCompanyId != null && p.companyId != _filterCompanyId)
        return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final compName = p.companyId != null
            ? (compCtrl.getById(p.companyId!)?.name ?? '').toLowerCase()
            : '';
        final amountStr = p.amount.toStringAsFixed(0);
        return p.description.toLowerCase().contains(q) ||
            compName.contains(q) ||
            p.code.toLowerCase().contains(q) ||
            amountStr.contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Payments',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => Get.to(() => const AddPaymentScreen()),
          ),
        ],
      ),
      body: Obx(() {
        final filtered = _filtered(payCtrl.payments, compCtrl);
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search payments...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(
                            Icons.clear,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _filterChip(
                    'All',
                    _filterType == null && _filterCompanyId == null,
                    () => setState(() {
                      _filterType = null;
                      _filterCompanyId = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'Sent',
                    _filterType == PaymentType.sent,
                    () => setState(() {
                      _filterType = _filterType == PaymentType.sent
                          ? null
                          : PaymentType.sent;
                    }),
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'Received',
                    _filterType == PaymentType.received,
                    () => setState(() {
                      _filterType = _filterType == PaymentType.received
                          ? null
                          : PaymentType.received;
                    }),
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  ...compCtrl.companies.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(
                        c.name,
                        _filterCompanyId == c.id,
                        () => setState(() {
                          _filterCompanyId = _filterCompanyId == c.id
                              ? null
                              : c.id;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} payment${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${AppUtils.formatAmount(filtered.fold(0.0, (s, p) => s + p.amount))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            if (filtered.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No payments found',
                  subtitle: 'Try different filters or add a new payment',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    return _PaymentListItem(payment: p);
                  },
                ),
              ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "payments_fab", // Unique tag
        onPressed: () => Get.to(() => const AddPaymentScreen()),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        icon: const Icon(Icons.add),
        label: Text(
          'New Payment',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool active,
    VoidCallback onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (color ?? AppColors.gold).withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? (color ?? AppColors.gold) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? (color ?? AppColors.gold) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  final PaymentModel payment;

  const _PaymentListItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final compCtrl = Get.find<CompanyController>();
    final company = payment.companyId != null
        ? compCtrl.getById(payment.companyId!)
        : null;
    final isSent = payment.type == PaymentType.sent;
    final typeColor = isSent ? AppColors.red : AppColors.green;
    final progress = payment.amount > 0
        ? (payment.amount - payment.remainingAmount) / payment.amount
        : 0.0;

    return GestureDetector(
      onTap: () => Get.to(
        () => PaymentDetailScreen(paymentId: payment.id),
        transition: Transition.cupertino, // Use a different transition
        duration: const Duration(milliseconds: 280),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: payment.totalDebt > 0
                ? AppColors.debtRed.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isSent ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.description,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              payment.code.isEmpty ? '—' : payment.code,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (company != null) ...[
                            CompanyAvatar(name: company.name, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              company.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            Text(
                              'Free entry',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '• ${AppUtils.formatRelativeDate(payment.date)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (payment.deadline != null) ...[
                        const SizedBox(height: 6),
                        DeadlineChip(
                          deadline: payment.deadline!,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppUtils.formatAmount(payment.amount),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    if (payment.totalDebt > 0)
                      Text(
                        'Debt ${AppUtils.formatAmount(payment.totalDebt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.debtRed,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),

            // Progress bar for forwarded amount
            if (payment.amount > 0 &&
                payment.remainingAmount < payment.amount) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(
                          progress >= 1.0 ? AppColors.green : AppColors.gold,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    payment.remainingAmount <= 0
                        ? 'Fully forwarded'
                        : '${AppUtils.formatAmount(payment.remainingAmount)} left',
                    style: TextStyle(
                      fontSize: 10,
                      color: payment.remainingAmount <= 0
                          ? AppColors.green
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
