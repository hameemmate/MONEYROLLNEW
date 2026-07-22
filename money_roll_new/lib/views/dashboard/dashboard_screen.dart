import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_roll_new/models/payment_model.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../payments/payment_detail_screen.dart';
import '../payments/add_payment_screen.dart';
import '../companies/company_balance_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashCtrl = Get.find<DashboardController>();
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Obx(
          () => RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: () async {},
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MONEYROLL',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              AppUtils.formatDate(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // In dashboard_screen.dart, replace the Cash In Hand card section with this enhanced version:

                // Cash In Hand hero card with net position
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        // Cash in hand card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gold.withOpacity(0.18),
                                AppColors.goldDark.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gold.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CASH IN HAND',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppUtils.formatAmountSigned(
                                  payCtrl.cashInHand.value,
                                ),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: payCtrl.cashInHand.value < 0
                                      ? AppColors.red
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _miniStat(
                                    '↑ Received',
                                    AppUtils.formatAmountCompact(
                                      payCtrl.totalReceivedThisMonth,
                                    ),
                                    AppColors.green,
                                  ),
                                  const SizedBox(width: 20),
                                  _miniStat(
                                    'Debt',
                                    AppUtils.formatAmountCompact(
                                      payCtrl.totalDebtOwedByMe,
                                    ),
                                    AppColors.debtRed,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Net Position Card - NEW
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _netPositionCard(
                                      'Owes You',
                                      payCtrl.totalOutstanding,
                                      Icons.trending_up,
                                      AppColors.green,
                                      'Companies that owe you money',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _netPositionCard(
                                      'You Owe',
                                      payCtrl.totalDebtOwedByMe,
                                      Icons.trending_down,
                                      AppColors.red,
                                      'Companies you owe money to',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: payCtrl.netPosition >= 0
                                      ? AppColors.greenBg
                                      : AppColors.redBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      payCtrl.netPosition >= 0
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      size: 16,
                                      color: payCtrl.netPosition >= 0
                                          ? AppColors.green
                                          : AppColors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        payCtrl.netPosition >= 0
                                            ? 'Net: You are owed ${AppUtils.formatAmount(payCtrl.netPosition)}'
                                            : 'Net: You owe ${AppUtils.formatAmount(payCtrl.netPosition.abs())}',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: payCtrl.netPosition >= 0
                                              ? AppColors.green
                                              : AppColors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Outstanding',
                            amount: payCtrl.totalOutstanding,
                            icon: Icons.trending_up,
                            iconColor: AppColors.green,
                            amountColor: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Debt Owed',
                            amount: payCtrl.totalDebtOwedByMe,
                            icon: Icons.trending_down,
                            iconColor: AppColors.red,
                            amountColor: AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Payments',
                            amount: payCtrl.payments.length.toDouble(),
                            icon: Icons.receipt_long_outlined,
                            iconColor: AppColors.blue,
                            amountColor: AppColors.blue,
                            isCount: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chart
                if (payCtrl.payments.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: '6-Month Overview'),
                            const SizedBox(height: 16),
                            SizedBox(height: 140, child: _buildChart(dashCtrl)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _chartLegend(AppColors.green, 'Received'),
                                const SizedBox(width: 16),
                                _chartLegend(AppColors.debtRed, 'Debt'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Company balances
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Company Balances'),
                        const SizedBox(height: 12),
                        if (payCtrl.companiesThatOweMe.isEmpty &&
                            payCtrl.companiesIOwe.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Text(
                                'No company balances yet',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ...[
                            ...payCtrl.companiesThatOweMe,
                            ...payCtrl.companiesIOwe,
                          ].map((entry) {
                            final company = compCtrl.getById(entry.key);
                            final name = company?.name ?? 'Unknown';
                            final balance = entry.value;
                            final owesMe = balance > 0;
                            return GestureDetector(
                              onTap: () =>
                                  Get.to(() => const CompanyBalanceScreen()),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    CompanyAvatar(name: name, size: 36),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            owesMe
                                                ? 'Owes you'
                                                : 'You owe them',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: owesMe
                                                  ? AppColors.green
                                                  : AppColors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AmountBadge(
                                      amount: balance.abs(),
                                      isPositive: owesMe,
                                      isDebt: !owesMe,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),

                // Recent payments
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: SectionHeader(
                      title: 'Recent Payments',
                      actionLabel: 'See All',
                      onAction: () =>
                          Get.find<DashboardController>().selectedTab.value = 1,
                    ),
                  ),
                ),

                if (payCtrl.payments.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No payments yet',
                      subtitle: 'Create your first payment record',
                      actionLabel: 'Add Payment',
                      onAction: () => Get.to(() => const AddPaymentScreen()),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final p = payCtrl.recentPayments[i];
                      final company = p.companyId != null
                          ? compCtrl.getById(p.companyId!)
                          : null;
                      return GestureDetector(
                        onTap: () => Get.to(
                          () => PaymentDetailScreen(paymentId: p.id),
                          transition: Transition
                              .cupertino, // Use a different transition
                          duration: const Duration(milliseconds: 280),
                        ),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: p.type == PaymentType.received
                                      ? AppColors.greenBg
                                      : AppColors.redBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  p.type == PaymentType.received
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  size: 16,
                                  color: p.type == PaymentType.received
                                      ? AppColors.green
                                      : AppColors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.description,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (company != null) ...[
                                          CompanyAvatar(
                                            name: company.name,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            company.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          AppUtils.formatRelativeDate(p.date),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppUtils.formatAmount(p.amount),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: p.type == PaymentType.received
                                          ? AppColors.green
                                          : AppColors.red,
                                    ),
                                  ),
                                  if (p.remainingAmount < p.amount &&
                                      p.remainingAmount >= 0)
                                    Text(
                                      '${AppUtils.formatAmount(p.remainingAmount)} left',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  if (p.totalDebt > 0)
                                    Text(
                                      'Debt: ${AppUtils.formatAmount(p.totalDebt)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.debtRed,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: payCtrl.recentPayments.length),
                  ),
                // ── Upcoming Deadlines ──────────────────────────────────────────────
                if (dashCtrl.upcomingDeadlinePayments.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: SectionHeader(
                        title: '⚠️ Upcoming Deadlines',
                        actionLabel:
                            '${dashCtrl.upcomingDeadlinePayments.length} pending',
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final payment = dashCtrl.upcomingDeadlinePayments[i];
                      final company = payment.companyId != null
                          ? compCtrl.getById(payment.companyId!)
                          : null;
                      final earliest = _earliestDeadline(payment);

                      return GestureDetector(
                        onTap: () => Get.to(
                          () => PaymentDetailScreen(paymentId: payment.id),
                          transition: Transition.cupertino,
                          duration: const Duration(milliseconds: 280),
                        ),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  earliest != null &&
                                      earliest.isBefore(DateTime.now())
                                  ? AppColors.red.withOpacity(0.6)
                                  : AppColors.amber.withOpacity(0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: payment.type == PaymentType.received
                                      ? AppColors.greenBg
                                      : AppColors.redBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  payment.type == PaymentType.received
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  size: 16,
                                  color: payment.type == PaymentType.received
                                      ? AppColors.green
                                      : AppColors.red,
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (company != null) ...[
                                          CompanyAvatar(
                                            name: company.name,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            company.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          payment.code,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.gold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (earliest != null)
                                          DeadlineChip(
                                            deadline: earliest,
                                            compact: true,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppUtils.formatAmount(payment.amount),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          payment.type == PaymentType.received
                                          ? AppColors.green
                                          : AppColors.red,
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
                            ],
                          ),
                        ),
                      );
                    }, childCount: dashCtrl.upcomingDeadlinePayments.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }

  // Add this helper method inside DashboardScreen class:
  Widget _netPositionCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppUtils.formatAmount(amount),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(DashboardController ctrl) {
    final data = ctrl.monthlyChartData;
    if (data.isEmpty) return const SizedBox();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final months = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ];
                if (val.toInt() < data.length) {
                  final month = data[val.toInt()]['month'] as DateTime;
                  return Text(
                    months[month.month - 1],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value['received'] as double),
                color: AppColors.green,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: (entry.value['debt'] as double),
                color: AppColors.debtRed,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  DateTime? _earliestDeadline(PaymentModel payment) {
    DateTime? earliest = payment.deadline;
    for (final t in Get.find<PaymentController>().transfers.where(
      (t) => t.paymentId == payment.id,
    )) {
      if (t.deadline != null) {
        if (earliest == null || t.deadline!.isBefore(earliest)) {
          earliest = t.deadline;
        }
      }
    }
    return earliest;
  }
}
