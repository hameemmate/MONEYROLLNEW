import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/company_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../models/payment_model.dart';
import '../../services/pdf_report_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _exportingAll = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PaymentModel> _filtered(List<PaymentModel> all, CompanyController compCtrl) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase().trim();
    return all.where((p) {
      final compName = p.companyId != null
          ? (compCtrl.getById(p.companyId!)?.name ?? '').toLowerCase()
          : '';
      return p.description.toLowerCase().contains(q) ||
          compName.contains(q) ||
          p.code.toLowerCase().contains(q) ||
          p.amount.toStringAsFixed(0).contains(q);
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
          'Reports',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Export full report button in AppBar
          Obx(() {
            if (payCtrl.payments.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed:
                    _exportingAll ? null : () => _exportAll(payCtrl, compCtrl),
                icon: _exportingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined,
                        size: 16, color: AppColors.gold),
                label: Text(
                  _exportingAll ? 'Generating...' : 'Export PDF',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        final filtered = _filtered(payCtrl.payments, compCtrl);

        return Column(
          children: [
            // ── Search bar (always visible) ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name, code (M1), company or amount...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.gold, width: 1),
                  ),
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            if (payCtrl.payments.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assessment_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No pools yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Create a payment to start tracking',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 40, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No pools match your search',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview always shows full totals
                      _OverviewCard(payCtrl: payCtrl),
                      const SizedBox(height: 20),

                      _sectionLabel('PAYMENT SUMMARY / POOL SUMMARY'),
                      const SizedBox(height: 10),
                      _CompanyTable(
                          payments: filtered, compCtrl: compCtrl),
                      const SizedBox(height: 20),

                      _DebtOwesTable(
                          payments: filtered, compCtrl: compCtrl,
                          payCtrl: payCtrl),
                      const SizedBox(height: 24),

                      _sectionLabel('POOL REPORTS'),
                      const SizedBox(height: 10),
                      _PoolReportsSection(
                          payments: filtered,
                          payCtrl: payCtrl,
                          compCtrl: compCtrl),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1.0,
        ),
      );

  Future<void> _exportAll(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) async {
    setState(() => _exportingAll = true);
    try {
      await PdfReportService.exportAll(payCtrl: payCtrl, compCtrl: compCtrl);
    } catch (e) {
      AppUtils.showError('Export Failed', e.toString());
    } finally {
      if (mounted) setState(() => _exportingAll = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview card
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final PaymentController payCtrl;
  const _OverviewCard({required this.payCtrl});

  @override
  Widget build(BuildContext context) {
    final totalReceived =
        payCtrl.payments.fold(0.0, (s, p) => s + p.amount);
    final totalForwarded = payCtrl.payments
        .fold(0.0, (s, p) => s + (p.amount - p.remainingAmount));
    final totalBalance =
        payCtrl.payments.fold(0.0, (s, p) => s + p.remainingAmount);
    final totalDebt =
        payCtrl.payments.fold(0.0, (s, p) => s + p.totalDebt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash in Hand',
                      style:
                          TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 2),
                  Text(
                    AppUtils.formatAmountSigned(payCtrl.cashInHand.value),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: payCtrl.cashInHand.value < 0
                          ? AppColors.red
                          : AppColors.gold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(
                    'Owes You',
                    AppUtils.formatAmount(payCtrl.totalOutstanding),
                    AppColors.green,
                  ),
                  const SizedBox(height: 6),
                  _badge(
                    'You Owe',
                    AppUtils.formatAmount(payCtrl.totalDebtOwedByMe),
                    AppColors.red,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Total Received',
                  AppUtils.formatAmountCompact(totalReceived), AppColors.gold),
              _vDivider(),
              _stat('Forwarded',
                  AppUtils.formatAmountCompact(totalForwarded), Colors.white70),
              _vDivider(),
              _stat('Balance',
                  AppUtils.formatAmountCompact(totalBalance), AppColors.amber),
              _vDivider(),
              _stat(
                'Debt',
                totalDebt > 0
                    ? AppUtils.formatAmountCompact(totalDebt)
                    : 'None',
                totalDebt > 0 ? AppColors.debtRed : Colors.white30,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
            const SizedBox(width: 6),
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 9, color: Colors.white38),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _vDivider() => Container(
      width: 0.5,
      height: 28,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

// ─────────────────────────────────────────────────────────────────────────────
// Pool-level table  (one row per pool, company shown on first of each group)
// ─────────────────────────────────────────────────────────────────────────────

class _CompanyTable extends StatelessWidget {
  final List<PaymentModel> payments;
  final CompanyController compCtrl;
  const _CompanyTable({required this.payments, required this.compCtrl});

  @override
  Widget build(BuildContext context) {
    final Map<String?, List<PaymentModel>> grouped = {};
    for (final p in payments) {
      (grouped[p.companyId] ??= []).add(p);
    }
    final nonNullIds = grouped.keys
        .where((k) => k != null)
        .cast<String>()
        .toList()
      ..sort((a, b) {
        final na = compCtrl.getById(a)?.name ?? '';
        final nb = compCtrl.getById(b)?.name ?? '';
        return na.compareTo(nb);
      });
    final orderedIds = <String?>[
      ...nonNullIds,
      if (grouped.containsKey(null)) null,
    ];

    final totReceived = payments.fold(0.0, (s, p) => s + p.amount);
    final totSent =
        payments.fold(0.0, (s, p) => s + (p.amount - p.remainingAmount));
    final totBalance =
        payments.fold(0.0, (s, p) => s + p.remainingAmount);

    // Build rows: pool rows + subtotal row per company
    final bodyWidgets = <Widget>[];
    var altIndex = 0;

    for (final id in orderedIds) {
      final pools = grouped[id] ?? [];
      if (pools.isEmpty) continue;
      final companyName =
          id == null ? 'Cash' : (compCtrl.getById(id)?.name ?? 'Unknown');

      final compReceived = pools.fold(0.0, (s, p) => s + p.amount);
      final compSent =
          pools.fold(0.0, (s, p) => s + (p.amount - p.remainingAmount));
      final compBalance = pools.fold(0.0, (s, p) => s + p.remainingAmount);

      for (var i = 0; i < pools.length; i++) {
        final p = pools[i];
        bodyWidgets.add(_PoolRow(
          data: _RowData(
            companyLabel: i == 0 ? companyName : '',
            isCash: id == null,
            poolName: p.code.isNotEmpty
                ? '${p.code}  ${p.description}'
                : p.description,
            received: p.amount,
            sent: p.amount - p.remainingAmount,
            balance: p.remainingAmount,
            date: p.date,
            isFirstInGroup: i == 0,
          ),
          altBg: altIndex % 2 == 1,
          isLast: false,
        ));
        altIndex++;
      }

      // Company subtotal row
      bodyWidgets.add(_SubtotalRow(
        label: companyName,
        received: compReceived,
        sent: compSent,
        balance: compBalance,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _tableHeader(),
          ...bodyWidgets,
          _totalsRow(totReceived, totSent, totBalance, payments.length),
        ],
      ),
    );
  }

  Widget _tableHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D21),
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Row(
          children: [
            _hCell('COMPANY', flex: 4),
            _hCell('NAME', flex: 6),
            _hCell('RECEIVED', flex: 4, right: true),
            _hCell('SENT', flex: 4, right: true),
            _hCell('BALANCE', flex: 4, right: true),
            _hCell('DATE', flex: 4, right: true),
          ],
        ),
      );

  Widget _totalsRow(
          double totReceived, double totSent, double totBalance, int count) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D21),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: Row(
          children: [
            const Expanded(
              flex: 4,
              child: Text('TOTAL',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            Expanded(
              flex: 6,
              child: Text('$count pools',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.white54)),
            ),
            _tCell(AppUtils.formatAmountCompact(totReceived), AppColors.gold,
                flex: 4),
            _tCell(AppUtils.formatAmountCompact(totSent), Colors.white70,
                flex: 4),
            _tCell(AppUtils.formatAmountCompact(totBalance), AppColors.amber,
                flex: 4),
            const Expanded(flex: 4, child: SizedBox()),
          ],
        ),
      );

  Widget _hCell(String text, {required int flex, bool right = false}) =>
      Expanded(
        flex: flex,
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
                letterSpacing: 0.6)),
      );

  Widget _tCell(String text, Color color, {required int flex}) => Expanded(
        flex: flex,
        child: Text(text,
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _RowData {
  final String companyLabel; // non-empty only for first pool of each company
  final bool isCash;
  final String poolName;
  final double received;
  final double sent;
  final double balance;
  final DateTime date;
  final bool isFirstInGroup;

  const _RowData({
    required this.companyLabel,
    required this.isCash,
    required this.poolName,
    required this.received,
    required this.sent,
    required this.balance,
    required this.date,
    required this.isFirstInGroup,
  });
}

class _PoolRow extends StatelessWidget {
  final _RowData data;
  final bool altBg;
  final bool isLast;

  const _PoolRow({
    required this.data,
    required this.altBg,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: altBg ? AppColors.surfaceAlt : AppColors.surface,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Company — shown only on first row of each group
          Expanded(
            flex: 4,
            child: Text(
              data.companyLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: data.isFirstInGroup
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: data.isCash
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Pool name (code + description)
          Expanded(
            flex: 6,
            child: Text(
              data.poolName,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Received
          Expanded(
            flex: 4,
            child: Text(
              AppUtils.formatAmountCompact(data.received),
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          // Sent
          Expanded(
            flex: 4,
            child: Text(
              data.sent > 0.001
                  ? AppUtils.formatAmountCompact(data.sent)
                  : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: data.sent > 0.001
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
              ),
            ),
          ),
          // Balance
          Expanded(
            flex: 4,
            child: Text(
              AppUtils.formatAmountCompact(data.balance),
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: data.balance > 0.001
                    ? AppColors.amber
                    : AppColors.textMuted,
              ),
            ),
          ),
          // Date
          Expanded(
            flex: 4,
            child: Text(
              AppUtils.formatDateShort(data.date),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Company subtotal row
// ─────────────────────────────────────────────────────────────────────────────

class _SubtotalRow extends StatelessWidget {
  final String label;
  final double received;
  final double sent;
  final double balance;

  const _SubtotalRow({
    required this.label,
    required this.received,
    required this.sent,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        border: Border(
          top: BorderSide(color: AppColors.amber.withOpacity(0.2), width: 0.5),
          bottom:
              BorderSide(color: AppColors.amber.withOpacity(0.2), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              'TOTAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.amber.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _amt(AppUtils.formatAmountCompact(received), AppColors.gold, flex: 4),
          _amt(AppUtils.formatAmountCompact(sent), AppColors.textSecondary,
              flex: 4),
          _amt(AppUtils.formatAmountCompact(balance), AppColors.amber, flex: 4),
          const Expanded(flex: 4, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _amt(String text, Color color, {required int flex}) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Debt & Owes Me table (company-wise, combined)
// ─────────────────────────────────────────────────────────────────────────────

class _DebtOwesTable extends StatelessWidget {
  final List<PaymentModel> payments;
  final PaymentController payCtrl;
  final CompanyController compCtrl;
  const _DebtOwesTable(
      {required this.payments,
      required this.payCtrl,
      required this.compCtrl});

  @override
  Widget build(BuildContext context) {
    // Aggregate debt per company from filtered payments
    final Map<String?, double> debtByCompany = {};
    for (final p in payments) {
      if (p.totalDebt > 0.0001) {
        debtByCompany[p.companyId] =
            (debtByCompany[p.companyId] ?? 0) + p.totalDebt;
      }
    }

    // Owes Me per company (global — not filtered, it's transfer-based)
    final owesMe = <String, double>{
      for (final e in payCtrl.companiesThatOweMe) e.key: e.value,
    };

    // All companies that appear in either
    final allIds = <String?>{
      ...debtByCompany.keys,
      ...owesMe.keys,
    };

    if (allIds.isEmpty) return const SizedBox.shrink();

    // Sort alphabetically, null last
    final sorted = allIds
        .where((k) => k != null)
        .cast<String>()
        .toList()
      ..sort((a, b) {
        final na = compCtrl.getById(a)?.name ?? '';
        final nb = compCtrl.getById(b)?.name ?? '';
        return na.compareTo(nb);
      });
    if (allIds.contains(null)) sorted.add('__null__');

    final totalDebt =
        debtByCompany.values.fold(0.0, (s, v) => s + v);
    final totalOwed = owesMe.values.fold(0.0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label with totals
        Row(
          children: [
            Text(
              'DEBT & OWES ME',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            if (totalDebt > 0)
              _pill(AppUtils.formatAmountCompact(totalDebt),
                  AppColors.debtRed, AppColors.debtBg),
            if (totalDebt > 0 && totalOwed > 0) const SizedBox(width: 6),
            if (totalOwed > 0)
              _pill(AppUtils.formatAmountCompact(totalOwed),
                  AppColors.green, AppColors.greenBg),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1D21),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 5, child: _TH('COMPANY')),
                    Expanded(flex: 4, child: _TH('DEBT', right: true)),
                    Expanded(
                        flex: 4, child: _TH('OWES ME', right: true)),
                  ],
                ),
              ),
              // Rows
              ...sorted.asMap().entries.map((e) {
                final rawId = e.value;
                final id = rawId == '__null__' ? null : rawId;
                final company =
                    id != null ? compCtrl.getById(id) : null;
                final companyName =
                    company?.name ?? (id == null ? 'Cash' : 'Unknown');
                final debt = debtByCompany[id] ?? 0.0;
                final owed = id != null ? (owesMe[id] ?? 0.0) : 0.0;
                final isLast = e.key == sorted.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.key % 2 == 1
                        ? AppColors.surfaceAlt
                        : AppColors.surface,
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(
                                color: AppColors.border, width: 0.5)),
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(10))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(companyName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          debt > 0.0001
                              ? AppUtils.formatAmount(debt)
                              : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: debt > 0.0001
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: debt > 0.0001
                                ? AppColors.debtRed
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          owed > 0.0001
                              ? AppUtils.formatAmount(owed)
                              : '-',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: owed > 0.0001
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: owed > 0.0001
                                ? AppColors.green
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-pool report list
// ─────────────────────────────────────────────────────────────────────────────

class _PoolReportsSection extends StatefulWidget {
  final List<PaymentModel> payments;
  final PaymentController payCtrl;
  final CompanyController compCtrl;
  const _PoolReportsSection(
      {required this.payments, required this.payCtrl, required this.compCtrl});

  @override
  State<_PoolReportsSection> createState() => _PoolReportsSectionState();
}

class _PoolReportsSectionState extends State<_PoolReportsSection> {
  final Set<String> _loading = {};

  @override
  Widget build(BuildContext context) {
    final payments = widget.payments;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: payments.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final company = p.companyId != null
              ? widget.compCtrl.getById(p.companyId!)
              : null;
          final isLast = i == payments.length - 1;
          final isExporting = _loading.contains(p.id);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: i % 2 == 1 ? AppColors.surfaceAlt : AppColors.surface,
              borderRadius: isLast
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(10))
                  : null,
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(
                          color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                // Code badge
                if (p.code.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Text(
                      p.code,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                // Description + company
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.description.isNotEmpty ? p.description : p.code,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (company != null)
                        Text(
                          company.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppUtils.formatAmountCompact(p.amount),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    Text(
                      AppUtils.formatDateShort(p.date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Export button
                GestureDetector(
                  onTap: isExporting ? null : () => _exportPool(p),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: isExporting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                            color: AppColors.gold,
                          ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _exportPool(PaymentModel payment) async {
    setState(() => _loading.add(payment.id));
    try {
      await PdfReportService.exportPool(
        payment: payment,
        payCtrl: widget.payCtrl,
        compCtrl: widget.compCtrl,
      );
    } catch (e) {
      AppUtils.showError('Export Failed', e.toString());
    } finally {
      if (mounted) setState(() => _loading.remove(payment.id));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.6,
        ),
      );
}
