import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/enums.dart';
import '../../models/payment_model.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../payments/payment_detail_screen.dart';

class CompanyBalanceScreen extends StatelessWidget {
  const CompanyBalanceScreen({super.key});

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
          'Company Balances',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Obx(() {
        final owesMe = payCtrl.companiesThatOweMe;
        final iOwe = payCtrl.companiesIOwe;

        if (owesMe.isEmpty && iOwe.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.balance, size: 48, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text(
                  'No balances yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 8),
                Text(
                  'Create payments to track who owes whom',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Owes You',
                      payCtrl.totalOutstanding,
                      Icons.money_off,
                      AppColors.green,
                      '${owesMe.length} companies',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'You Owe',
                      payCtrl.totalDebtOwedByMe,
                      Icons.money,
                      AppColors.red,
                      '${iOwe.length} companies',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Companies that owe ME
              if (owesMe.isNotEmpty) ...[
                _sectionHeader('Owes You', AppColors.green, owesMe.length),
                const SizedBox(height: 8),
                ...owesMe.map(
                  (entry) => _companyBalanceCard(
                    entry.key,
                    entry.value,
                    true,
                    compCtrl,
                    payCtrl,
                    context,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Companies I owe
              if (iOwe.isNotEmpty) ...[
                _sectionHeader('You Owe', AppColors.red, iOwe.length),
                const SizedBox(height: 8),
                ...iOwe.map(
                  (entry) => _companyBalanceCard(
                    entry.key,
                    entry.value,
                    false,
                    compCtrl,
                    payCtrl,
                    context,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppUtils.formatAmount(amount),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // Get ALL payments that involve this company (either as main payment or in transfers)
  List<PaymentModel> _getPaymentsForCompany(
    String companyId,
    PaymentController payCtrl,
  ) {
    final Set<String> paymentIds = {};

    // Check main payments
    for (final payment in payCtrl.payments) {
      if (payment.companyId == companyId) {
        paymentIds.add(payment.id);
      }
    }

    // Check transfers where company appears as sender or receiver
    for (final transfer in payCtrl.transfers) {
      if (transfer.fromCompanyId == companyId ||
          transfer.toCompanyId == companyId) {
        paymentIds.add(transfer.paymentId);
      }
    }

    // Return unique payments
    return paymentIds
        .map((id) => payCtrl.getPaymentById(id))
        .whereType<PaymentModel>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Calculate company's balance for a specific payment
  double _getPaymentBalanceForCompany(
    String paymentId,
    String companyId,
    PaymentController payCtrl,
  ) {
    double balance = 0.0;

    // Find all transfers involving this company in this payment
    final relevantTransfers = payCtrl.transfers
        .where(
          (t) =>
              t.paymentId == paymentId &&
              (t.fromCompanyId == companyId || t.toCompanyId == companyId),
        )
        .toList();

    for (final transfer in relevantTransfers) {
      if (transfer.toCompanyId == companyId) {
        // Company received money
        balance += transfer.amount;
      }
      if (transfer.fromCompanyId == companyId) {
        // Company sent money
        balance -= transfer.amount;
      }
    }

    // Also check main payment if company is the direct party
    final payment = payCtrl.getPaymentById(paymentId);
    if (payment != null && payment.companyId == companyId) {
      if (payment.type == PaymentType.received) {
        balance += payment.amount;
      } else if (payment.type == PaymentType.sent) {
        balance -= payment.amount;
      }
    }

    return balance;
  }

  Widget _companyBalanceCard(
    String companyId,
    double balance,
    bool owesMe,
    CompanyController compCtrl,
    PaymentController payCtrl,
    BuildContext context,
  ) {
    final company = compCtrl.getById(companyId);
    if (company == null) return const SizedBox();

    // Get ALL payments involving this company (including transfers)
    final companyPayments = _getPaymentsForCompany(companyId, payCtrl);

    return GestureDetector(
      onTap: () {
        _showPaymentsSheet(
          context,
          company,
          balance,
          owesMe,
          companyPayments,
          payCtrl,
          compCtrl,
          companyId,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: owesMe
                ? AppColors.green.withOpacity(0.3)
                : AppColors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            CompanyAvatar(name: company.name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (company.phone != null && company.phone!.isNotEmpty)
                    Text(
                      company.phone!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${companyPayments.length} payment${companyPayments.length == 1 ? '' : 's'} · Tap to view',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountBadge(
                  amount: balance.abs(),
                  isPositive: owesMe,
                  isDebt: !owesMe,
                ),
                const SizedBox(height: 4),
                Text(
                  owesMe ? 'Owes you' : 'You owe',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: owesMe ? AppColors.green : AppColors.red,
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
      ),
    );
  }

  void _showPaymentsSheet(
    BuildContext context,
    dynamic company,
    double balance,
    bool owesMe,
    List<PaymentModel> payments,
    PaymentController payCtrl,
    CompanyController compCtrl,
    String companyId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
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

              // Company header
              Row(
                children: [
                  CompanyAvatar(name: company.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: owesMe ? AppColors.greenBg : AppColors.redBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            owesMe
                                ? 'Owes you ${AppUtils.formatAmount(balance)}'
                                : 'You owe ${AppUtils.formatAmount(balance.abs())}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: owesMe ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Payments list header
              const Text(
                'All Related Payments',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Includes payments where ${company.name} appears in transfer chain',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Payments list
              Expanded(
                child: payments.isEmpty
                    ? const Center(
                        child: Text(
                          'No payments found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final payment = payments[index];
                          final isSent = payment.type == PaymentType.sent;
                          final typeColor = isSent
                              ? AppColors.red
                              : AppColors.green;
                          final progress = payment.amount > 0
                              ? (payment.amount - payment.remainingAmount) /
                                    payment.amount
                              : 0.0;

                          // Calculate company's balance in this specific payment
                          final paymentBalance = _getPaymentBalanceForCompany(
                            payment.id,
                            companyId,
                            payCtrl,
                          );
                          final hasBalance = paymentBalance != 0;

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Get.to(
                                () =>
                                    PaymentDetailScreen(paymentId: payment.id),
                                transition: Transition
                                    .cupertino, // Use a different transition
                                duration: const Duration(milliseconds: 280),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
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
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Icon(
                                          isSent
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          size: 16,
                                          color: typeColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.gold
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    payment.code.isEmpty
                                                        ? '—'
                                                        : payment.code,
                                                    style:
                                                        GoogleFonts.spaceGrotesk(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppColors.gold,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${isSent ? "Sent" : "Received"} • ${AppUtils.formatRelativeDate(payment.date)}',
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            AppUtils.formatAmount(
                                              payment.amount,
                                            ),
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: typeColor,
                                            ),
                                          ),
                                          if (payment.totalDebt > 0)
                                            Text(
                                              'Debt: ${AppUtils.formatAmount(payment.totalDebt)}',
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

                                  // Show company's balance in this payment
                                  if (hasBalance) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: paymentBalance > 0
                                            ? AppColors.greenBg
                                            : AppColors.redBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            paymentBalance > 0
                                                ? Icons.arrow_downward
                                                : Icons.arrow_upward,
                                            size: 12,
                                            color: paymentBalance > 0
                                                ? AppColors.green
                                                : AppColors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            paymentBalance > 0
                                                ? '${company.name} gets ${AppUtils.formatAmount(paymentBalance.abs())} from this payment'
                                                : '${company.name} sends ${AppUtils.formatAmount(paymentBalance.abs())} in this payment',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: paymentBalance > 0
                                                  ? AppColors.green
                                                  : AppColors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Progress bar for forwarded amount
                                  if (isSent && payment.amount > 0) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: progress.clamp(0.0, 1.0),
                                              backgroundColor:
                                                  AppColors.surfaceAlt,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    progress >= 1.0
                                                        ? AppColors.green
                                                        : AppColors.gold,
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
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
