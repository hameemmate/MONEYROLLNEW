import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../payments/payment_detail_screen.dart';
import '../payments/add_payment_screen.dart';

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
                        GestureDetector(
                          onTap: () => _showAddCashSheet(context, payCtrl),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldDark.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.gold.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Cash',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                                AppUtils.formatAmount(payCtrl.cashInHand.value),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
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
                                    '↓ Sent',
                                    AppUtils.formatAmountCompact(
                                      payCtrl.totalSentThisMonth,
                                    ),
                                    AppColors.red,
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
                                _chartLegend(AppColors.red, 'Sent'),
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
                        if (payCtrl.companyBalances.isEmpty)
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
                          ...payCtrl.companyBalances.entries.map((entry) {
                            final company = compCtrl.getById(entry.key);
                            final name = company?.name ?? 'Unknown';
                            final balance = entry.value;
                            final owesMe = balance > 0;
                            return Container(
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
                                          owesMe ? 'Owes you' : 'You owe them',
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
                toY: (entry.value['sent'] as double),
                color: AppColors.red,
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

  void _showAddCashSheet(BuildContext context, PaymentController payCtrl) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final compCtrl = Get.find<CompanyController>();
    String? fromCompanyId;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            bottom: true,
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
                  'Add Cash to Hand',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
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
                          'This will create a "Received" payment record',
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
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Amount (AED)',
                    prefixText: 'د.إ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description / Source',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: fromCompanyId,
                  dropdownColor: AppColors.surfaceAlt,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'From (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Free entry / Cash'),
                    ),
                    ...compCtrl.companies.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => fromCompanyId = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: 'Add Cash',
                    isLoading: submitting,
                    onTap: () async {
                      if (submitting) return;
                      final amt = double.tryParse(amountCtrl.text.trim());
                      if (amt == null || amt <= 0) {
                        AppUtils.showError('Error', 'Enter valid amount');
                        return;
                      }

                      if (descCtrl.text.trim().isEmpty) {
                        AppUtils.showError('Error', 'Enter description');
                        return;
                      }

                      setState(() => submitting = true);
                      try {
                        // Use createPayment instead of addCashInHand
                        await payCtrl.createPayment(
                          type: PaymentType.received,
                          amount: amt,
                          description: descCtrl.text.trim(),
                          companyId: fromCompanyId,
                          note: fromCompanyId == null
                              ? 'Manual cash addition'
                              : 'Cash received from ${compCtrl.getNameById(fromCompanyId)}',
                          label: 'Cash added',
                        );
                        Navigator.pop(ctx);
                        AppUtils.showSuccess(
                          'Cash Added',
                          '${AppUtils.formatAmount(amt)} added to cash in hand',
                        );
                      } catch (e) {
                        setState(() => submitting = false);
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
    );
  }
}
