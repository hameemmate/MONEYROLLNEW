import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controllers/company_controller.dart';
import '../controllers/payment_controller.dart';
import '../models/payment_model.dart';
import '../models/transfer_model.dart';
import '../views/reports/pdf_preview_screen.dart';

class PdfReportService {
  static final _gold = PdfColor.fromHex('B8860B');
  static final _green = PdfColor.fromHex('1E8E3E');
  static final _red = PdfColor.fromHex('D93025');
  static final _debtRed = PdfColor.fromHex('C5221F');
  static final _amber = PdfColor.fromHex('B06000');
  static final _headerBg = PdfColor.fromHex('1A1D21');
  static final _rowAlt = PdfColor.fromHex('F8F9FA');
  static final _borderColor = PdfColor.fromHex('E3E7EC');
  static final _textPrimary = PdfColor.fromHex('1A1D21');
  static final _textSecondary = PdfColor.fromHex('5F6571');
  static final _textMuted = PdfColor.fromHex('9AA0AB');

  static pw.Font get _regular => pw.Font.helvetica();
  static pw.Font get _bold => pw.Font.helveticaBold();

  static String _fmt(double amount) {
    final f = NumberFormat('#,##0.00');
    return 'AED ${f.format(amount)}';
  }

  /// Short number without currency prefix — used inside brackets like "(20, 49)".
  static String _fmtCompact(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0);
    }
    final f = NumberFormat('#,##0.##');
    return f.format(amount);
  }

  static String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  static String _fmtDateTime(DateTime d) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(d);

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<void> exportPool({
    required PaymentModel payment,
    required PaymentController payCtrl,
    required CompanyController compCtrl,
  }) async {
    final doc = pw.Document(title: 'Pool ${payment.code} Report');
    _addPoolPages(doc, payment, payCtrl, compCtrl);
    final bytes = await doc.save();
    final filename =
        'moneyroll_${payment.code}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    Get.to(
      () => PdfPreviewScreen(
        title: 'Pool ${payment.code} Report',
        filename: filename,
        bytes: bytes,
      ),
    );
  }

  static Future<void> exportAll({
    required PaymentController payCtrl,
    required CompanyController compCtrl,
  }) async {
    final doc = pw.Document(title: 'MONEYROLL Full Report');
    doc.addPage(_buildSummaryPage(payCtrl, compCtrl));
    final bytes = await doc.save();
    final filename =
        'moneyroll_full_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    Get.to(
      () => PdfPreviewScreen(
        title: 'Full Report',
        filename: filename,
        bytes: bytes,
      ),
    );
  }

  // ── Summary / main report page ────────────────────────────────────────────

  static pw.MultiPage _buildSummaryPage(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final now = DateTime.now();

    // ── Group payments by company ─────────────────────────────────────────────
    final Map<String?, List<PaymentModel>> grouped = {};
    for (final p in payCtrl.payments) {
      (grouped[p.companyId] ??= []).add(p);
    }

    // Sorted company IDs (non-null first, alphabetical; null/cash last)
    final nonNullIds = grouped.keys
        .where((k) => k != null)
        .cast<String>()
        .toList()
      ..sort((a, b) {
        final na = compCtrl.getById(a)?.name ?? '';
        final nb = compCtrl.getById(b)?.name ?? '';
        return na.compareTo(nb);
      });
    final hasCash = grouped.containsKey(null);

    // Owes Me map
    final owesMe = <String, double>{
      for (final e in payCtrl.companiesThatOweMe) e.key: e.value,
    };

    // Debt per company — attributed to the actual creditor on each debt transfer,
    // not just the pool's root company. This handles the case where extra money
    // was added from a different company into the same pool.
    final Map<String?, double> debtByCompany = {};
    for (final p in payCtrl.payments) {
      for (final t in payCtrl.transfers.where((t) => t.paymentId == p.id && t.isDebt)) {
        final remaining = payCtrl.effectiveReceiptDebt(t);
        if (remaining > 0.0001) {
          debtByCompany[t.fromCompanyId] =
              (debtByCompany[t.fromCompanyId] ?? 0.0) + remaining;
        }
      }
    }

    final totalReceived =
        payCtrl.payments.fold(0.0, (s, p) => s + p.amount);
    final totalSent = payCtrl.payments
        .fold(0.0, (s, p) => s + (p.amount - p.remainingAmount));
    final totalBalance =
        payCtrl.payments.fold(0.0, (s, p) => s + p.remainingAmount);

    // ── Pre-build pool-level rows (one per pool, company on first of group) ───
    final List<String?> orderedIds = [...nonNullIds, if (hasCash) null];
    final List<pw.Widget> companyRows = [];
    var rowIndex = 0;

    for (final id in orderedIds) {
      final pools = grouped[id] ?? [];
      if (pools.isEmpty) continue;
      final companyName = id == null
          ? 'Cash'
          : (compCtrl.getById(id)?.name ?? 'Unknown');
      final nameColor = id == null ? _textMuted : _textPrimary;

      for (var i = 0; i < pools.length; i++) {
        final p = pools[i];
        final sent = p.amount - p.remainingAmount;
        // Format: "M1 (description)" when both present, else just one of them.
        final poolLabel = p.code.isNotEmpty
            ? (p.description.isNotEmpty && p.description != p.code
                ? '${p.code} (${p.description})'
                : p.code)
            : (p.description.isNotEmpty ? p.description : '-');
        final altBg = rowIndex % 2 == 1;

        companyRows.add(pw.Container(
          decoration: pw.BoxDecoration(
            color: altBg ? _rowAlt : PdfColors.white,
            border: pw.Border(
              bottom: pw.BorderSide(color: _borderColor, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Row(
            children: [
              // Company — only first row of each group
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  i == 0 ? companyName : '',
                  style: pw.TextStyle(
                      font: i == 0 ? _bold : _regular,
                      fontSize: 9,
                      color: nameColor),
                ),
              ),
              // Pool name
              pw.Expanded(
                flex: 4,
                child: pw.Text(poolLabel,
                    style: pw.TextStyle(
                        font: _regular,
                        fontSize: 8.5,
                        color: _textSecondary)),
              ),
              // Received (base + additions in brackets)
              pw.Expanded(
                flex: 3,
                child: pw.Text(() {
                  final extras = payCtrl.additionalReceipts(p);
                  if (extras.isEmpty) return _fmt(p.amount);
                  double base = p.amount;
                  if (p.rootTransferId != null) {
                    final root = payCtrl.getTransferById(p.rootTransferId!);
                    if (root != null) base = root.amount;
                  }
                  final parts = extras
                      .map((t) => _fmtCompact(t.amount))
                      .join(', ');
                  return '${_fmtCompact(base)} ($parts)';
                }(),
                textAlign: pw.TextAlign.right,
                    style:
                        pw.TextStyle(font: _bold, fontSize: 9, color: _gold)),
              ),
              // Sent
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  sent > 0.0001 ? _fmt(sent) : '-',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: _regular,
                      fontSize: 9,
                      color: sent > 0.0001 ? _textSecondary : _textMuted),
                ),
              ),
              // Balance
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  _fmt(p.remainingAmount),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: p.remainingAmount > 0.0001 ? _bold : _regular,
                      fontSize: 9,
                      color: p.remainingAmount > 0.0001 ? _amber : _textMuted),
                ),
              ),
              // Date
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  _fmtDate(p.date),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: _regular, fontSize: 8.5, color: _textMuted),
                ),
              ),
            ],
          ),
        ));
        rowIndex++;
      }

      // Company subtotal row
      final compReceived = pools.fold(0.0, (s, p) => s + p.amount);
      final compSent =
          pools.fold(0.0, (s, p) => s + (p.amount - p.remainingAmount));
      final compBalance = pools.fold(0.0, (s, p) => s + p.remainingAmount);

      // amber tint — clearly distinct from dark header (#1A1D21) and white rows
      final _subtotalBg = PdfColor.fromHex('FEF3E0');
      final _subtotalBorder = PdfColor.fromHex('E8C87A');

      companyRows.add(pw.Container(
        decoration: pw.BoxDecoration(
          color: _subtotalBg,
          border: pw.Border(
            top: pw.BorderSide(color: _subtotalBorder, width: 0.5),
            bottom: pw.BorderSide(color: _subtotalBorder, width: 0.5),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                companyName,
                style: pw.TextStyle(font: _bold, fontSize: 9, color: _amber),
              ),
            ),
            pw.Expanded(
              flex: 4,
              child: pw.Text(
                'TOTAL',
                style: pw.TextStyle(
                    font: _bold,
                    fontSize: 8,
                    color: _amber,
                    letterSpacing: 0.5),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(_fmt(compReceived),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _bold, fontSize: 9, color: _gold)),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(_fmt(compSent),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: _bold, fontSize: 9, color: _textSecondary)),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(_fmt(compBalance),
                  textAlign: pw.TextAlign.right,
                  style:
                      pw.TextStyle(font: _bold, fontSize: 9, color: _amber)),
            ),
            pw.Expanded(flex: 3, child: pw.SizedBox()),
          ],
        ),
      ));
    }

    // ── Pre-build debt/owes rows ──────────────────────────────────────────────
    final List<pw.Widget> debtOwesWidgets = [];
    final allDebtOwesIds = <String?>{...debtByCompany.keys, ...owesMe.keys};

    if (allDebtOwesIds.isNotEmpty) {
      final debtNonNull = allDebtOwesIds
          .where((k) => k != null)
          .cast<String>()
          .toList()
        ..sort((a, b) {
          final na = compCtrl.getById(a)?.name ?? '';
          final nb = compCtrl.getById(b)?.name ?? '';
          return na.compareTo(nb);
        });
      final debtOrderedIds = <String?>[
        ...debtNonNull,
        if (allDebtOwesIds.contains(null)) null,
      ];

      debtOwesWidgets.add(pw.SizedBox(height: 24));
      debtOwesWidgets.add(_sectionLabel('DEBT & OWES ME'));
      debtOwesWidgets.add(pw.SizedBox(height: 8));
      debtOwesWidgets.add(pw.Container(
        decoration: pw.BoxDecoration(color: _headerBg),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 5, child: _hdr('COMPANY')),
            pw.Expanded(flex: 4, child: _hdr('DEBT', right: true)),
            pw.Expanded(flex: 4, child: _hdr('OWES ME', right: true)),
          ],
        ),
      ));

      for (var i = 0; i < debtOrderedIds.length; i++) {
        final id = debtOrderedIds[i];
        final companyName = id == null
            ? 'Cash'
            : (compCtrl.getById(id)?.name ?? 'Unknown');
        final debt = debtByCompany[id] ?? 0.0;
        final owed = id != null ? (owesMe[id] ?? 0.0) : 0.0;

        debtOwesWidgets.add(pw.Container(
          decoration: pw.BoxDecoration(
            color: i % 2 == 1 ? _rowAlt : PdfColors.white,
            border: pw.Border(
              bottom: pw.BorderSide(color: _borderColor, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text(companyName,
                    style: pw.TextStyle(
                        font: _bold, fontSize: 10, color: _textPrimary)),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  debt > 0.0001 ? _fmt(debt) : '-',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: debt > 0.0001 ? _bold : _regular,
                      fontSize: 10,
                      color: debt > 0.0001 ? _debtRed : _textMuted),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  owed > 0.0001 ? _fmt(owed) : '-',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: owed > 0.0001 ? _bold : _regular,
                      fontSize: 10,
                      color: owed > 0.0001 ? _green : _textMuted),
                ),
              ),
            ],
          ),
        ));
      }
    }

    // ── Assemble page ─────────────────────────────────────────────────────────
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      header: (_) => _summaryHeader(now, payCtrl),
      footer: _footer,
      build: (ctx) {
        final widgets = <pw.Widget>[
          pw.SizedBox(height: 14),

          // Overview strip
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                _statCell(
                  'Cash in Hand',
                  _fmt(payCtrl.cashInHand.value),
                  payCtrl.cashInHand.value < 0 ? _red : _green,
                  isFirst: true,
                ),
                _dividerV(),
                _statCell(
                    'Owes You', _fmt(payCtrl.totalOutstanding), _green),
                _dividerV(),
                _statCell('You Owe', _fmt(payCtrl.totalDebtOwedByMe), _red,
                    isLast: true),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          _sectionLabel('PAYMENT SUMMARY / POOL SUMMARY'),
          pw.SizedBox(height: 8),

          // Table header
          pw.Container(
            decoration: pw.BoxDecoration(color: _headerBg),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 3, child: _hdr('COMPANY')),
                pw.Expanded(flex: 4, child: _hdr('NAME')),
                pw.Expanded(
                    flex: 3, child: _hdr('RECEIVED', right: true)),
                pw.Expanded(
                    flex: 3,
                    child: _hdr('FORWARDED / SENT', right: true)),
                pw.Expanded(
                    flex: 3, child: _hdr('BALANCE', right: true)),
                pw.Expanded(flex: 3, child: _hdr('DATE', right: true)),
              ],
            ),
          ),

          // Company rows (pre-built)
          ...companyRows,

          // Totals row
          pw.Container(
            decoration: pw.BoxDecoration(color: _headerBg),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text('TOTAL',
                      style: pw.TextStyle(
                          font: _bold,
                          fontSize: 9,
                          color: PdfColors.white)),
                ),
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    '${payCtrl.payments.length} pools',
                    style: pw.TextStyle(
                        font: _regular,
                        fontSize: 8.5,
                        color: PdfColors.grey400),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(_fmt(totalReceived),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: _bold, fontSize: 9, color: _gold)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(_fmt(totalSent),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: _bold,
                          fontSize: 9,
                          color: PdfColors.white)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(_fmt(totalBalance),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: _bold, fontSize: 9, color: _amber)),
                ),
                pw.Expanded(flex: 3, child: pw.SizedBox()),
              ],
            ),
          ),

          // Debt & Owes Me (pre-built, empty if nothing to show)
          ...debtOwesWidgets,
        ];

        return widgets;
      },
    );
  }

  static pw.Widget _summaryHeader(
      DateTime now, PaymentController payCtrl) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MONEYROLL',
                  style: pw.TextStyle(
                      font: _bold,
                      fontSize: 18,
                      color: _gold,
                      letterSpacing: 2)),
              pw.SizedBox(height: 4),
              pw.Text('Report Generated: ${_fmtDateTime(now)}',
                  style: pw.TextStyle(
                      font: _regular,
                      fontSize: 8.5,
                      color: PdfColors.grey400)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('FULL REPORT',
                  style: pw.TextStyle(
                      font: _bold,
                      fontSize: 10,
                      color: PdfColors.white,
                      letterSpacing: 1.5)),
              pw.SizedBox(height: 4),
              pw.Text('${payCtrl.payments.length} pools',
                  style: pw.TextStyle(
                      font: _regular,
                      fontSize: 8.5,
                      color: PdfColors.grey400)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pool detail pages ─────────────────────────────────────────────────────

  static void _addPoolPages(
    pw.Document doc,
    PaymentModel payment,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final company = payment.companyId != null
        ? compCtrl.getById(payment.companyId!)
        : null;
    final transfers = _flattenTransfers(payment, payCtrl, compCtrl);
    final clearances =
        payCtrl.debtClearances.where((c) => c.paymentId == payment.id).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final forwarded = payment.amount - payment.remainingAmount;
    final forwardedPct =
        payment.amount > 0 ? (forwarded / payment.amount * 100) : 0.0;
    final available = payCtrl.availableFromPool(payment);
    final branchCount = payCtrl
        .getPaymentTransfers(payment.id)
        .where((t) => t.id != payment.rootTransferId)
        .length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (ctx) => _poolPageHeader(payment, company),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 14),

          // ─ Financial summary stats ────────────────────────────────────────
          _sectionLabel('FINANCIAL SUMMARY'),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                _statCell('Total Amount', () {
                  final extras = payCtrl.additionalReceipts(payment);
                  if (extras.isEmpty) return _fmt(payment.amount);
                  double base = payment.amount;
                  if (payment.rootTransferId != null) {
                    final root = payCtrl.getTransferById(payment.rootTransferId!);
                    if (root != null) base = root.amount;
                  }
                  final parts = extras.map((t) => _fmtCompact(t.amount)).join(', ');
                  return '${_fmtCompact(base)} ($parts)';
                }(), _gold, isFirst: true),
                _dividerV(),
                _statCell('Forwarded', _fmt(forwarded), _textSecondary),
                _dividerV(),
                _statCell(
                  'Remaining',
                  _fmt(payment.remainingAmount),
                  payment.remainingAmount > 0.0001 ? _amber : _textMuted,
                ),
                _dividerV(),
                _statCell(
                  'Available',
                  _fmt(available),
                  available > 0.0001 ? _green : _textMuted,
                ),
                _dividerV(),
                _statCell(
                  'Total Debt',
                  payment.totalDebt > 0.0001 ? _fmt(payment.totalDebt) : '-',
                  payment.totalDebt > 0.0001 ? _debtRed : _textMuted,
                  isLast: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // ─ Forwarded progress bar ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _rowAlt,
              border: pw.Border.all(color: _borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Forwarded: ${forwardedPct.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    font: _bold,
                    fontSize: 8.5,
                    color: _textSecondary,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (forwardedPct > 0.5)
                        pw.Expanded(
                          flex: forwardedPct.clamp(1, 100).round(),
                          child: pw.Container(
                            height: 6,
                            decoration: pw.BoxDecoration(
                              color: forwardedPct >= 100 ? _green : _gold,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      if (forwardedPct < 99.5)
                        pw.Expanded(
                          flex: (100 - forwardedPct).clamp(1, 100).round(),
                          child: pw.Container(
                            height: 6,
                            decoration: pw.BoxDecoration(
                              color: _borderColor,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  '$branchCount branch${branchCount == 1 ? '' : 'es'}',
                  style: pw.TextStyle(
                    font: _regular,
                    fontSize: 8,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Additional receipts block
          ..._buildAdditionalReceiptsSection(payment, payCtrl, compCtrl),

          if (transfers.isNotEmpty) ...[
            pw.SizedBox(height: 16),

            // ─ Transfer chain ───────────────────────────────────────────────
            _sectionLabel('TRANSFER CHAIN'),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1.0), // Code
                1: pw.FlexColumnWidth(1.8), // From
                2: pw.FlexColumnWidth(1.8), // To
                3: pw.FlexColumnWidth(1.5), // Amount
                4: pw.FlexColumnWidth(1.4), // Debt
                5: pw.FlexColumnWidth(1.6), // Status
                6: pw.FlexColumnWidth(1.3), // Date
              },
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              children: [
                _headerRow(
                    ['CODE', 'FROM', 'TO', 'AMOUNT', 'DEBT', 'STATUS', 'DATE']),
                ...transfers.asMap().entries.map((e) {
                  final idx = e.key;
                  final row = e.value;
                  final t = row.transfer;

                  final remaining = payCtrl.effectiveReceiptDebt(t);
                  final cleared = payCtrl.clearedForTransfer(t.id);
                  String debtText;
                  String statusText;
                  PdfColor debtColor;
                  PdfColor statusColor;

                  if (!t.isDebt) {
                    debtText = '-';
                    statusText = 'OK';
                    debtColor = _textMuted;
                    statusColor = _green;
                  } else if (remaining <= 0.0001) {
                    debtText = _fmt(t.debtAmount);
                    statusText = 'Cleared';
                    debtColor = _textSecondary;
                    statusColor = _green;
                  } else {
                    debtText = _fmt(remaining);
                    statusText = cleared > 0.0001
                        ? 'Partial\n(${_fmt(cleared)} clrd)'
                        : 'Outstanding';
                    debtColor = _debtRed;
                    statusColor = _debtRed;
                  }

                  final indent = '  ' * row.depth;
                  return _dataRow(idx, [
                    _cell(
                      '$indent${t.code.isEmpty ? "—" : t.code}',
                      bold: true,
                      color: _gold,
                    ),
                    _cell(row.fromName),
                    _cell(row.toName),
                    _cell(_fmt(t.amount)),
                    _cell(debtText, color: debtColor),
                    _cell(statusText, color: statusColor),
                    _cell(_fmtDate(t.createdAt), color: _textMuted),
                  ]);
                }),
              ],
            ),

            // ─ Transfer notes (only if any transfer has a note/deadline) ────
            if (transfers.any(
              (r) =>
                  (r.transfer.note?.isNotEmpty ?? false) ||
                  r.transfer.deadline != null,
            )) ...[
              pw.SizedBox(height: 10),
              _sectionLabel('BRANCH NOTES & DEADLINES'),
              pw.SizedBox(height: 6),
              ...transfers
                  .where(
                    (r) =>
                        (r.transfer.note?.isNotEmpty ?? false) ||
                        r.transfer.deadline != null,
                  )
                  .map(
                    (r) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 4),
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: _rowAlt,
                        border: pw.Border.all(color: _borderColor, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            r.transfer.code.isEmpty ? '-' : r.transfer.code,
                            style: pw.TextStyle(
                              font: _bold,
                              fontSize: 8,
                              color: _gold,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (r.transfer.note?.isNotEmpty ?? false)
                                  pw.Text(
                                    r.transfer.note!,
                                    style: pw.TextStyle(
                                      font: _regular,
                                      fontSize: 8,
                                      color: _textSecondary,
                                    ),
                                  ),
                                if (r.transfer.deadline != null)
                                  pw.Text(
                                    'Deadline: ${_fmtDate(r.transfer.deadline!)}',
                                    style: pw.TextStyle(
                                      font: _bold,
                                      fontSize: 8,
                                      color: _amber,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],

          if (clearances.isNotEmpty) ...[
            pw.SizedBox(height: 16),

            // ─ Debt clearances ───────────────────────────────────────────────
            _sectionLabel('DEBT CLEARANCES'),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(2.0),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.2),
              },
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              children: [
                _headerRow(['DATE', 'COMPANY', 'AMOUNT', 'BRANCH', 'SOURCE']),
                ...clearances.asMap().entries.map((e) {
                  final c = e.value;
                  final company = compCtrl.getById(c.companyId);
                  // Find the branch code for this clearance
                  final branchTransfer = payCtrl.transfers.where(
                    (t) => t.id == c.transferId,
                  ).firstOrNull;
                  return _dataRow(e.key, [
                    _cell(_fmtDate(c.date)),
                    _cell(company?.name ?? 'Unknown'),
                    _cell(_fmt(c.amount), color: _green),
                    _cell(
                      branchTransfer?.code.isNotEmpty == true
                          ? branchTransfer!.code
                          : '-',
                      color: _textSecondary,
                    ),
                    _cell(c.source.name, color: _textMuted),
                  ]);
                }),
              ],
            ),

            // Clearance summary
            pw.SizedBox(height: 6),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: pw.BoxDecoration(
                color: _rowAlt,
                border: pw.Border.all(color: _borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Total Cleared: ',
                    style: pw.TextStyle(
                        font: _regular, fontSize: 8.5, color: _textSecondary),
                  ),
                  pw.Text(
                    _fmt(clearances.fold(0.0, (s, c) => s + c.amount)),
                    style: pw.TextStyle(font: _bold, fontSize: 8.5, color: _green),
                  ),
                  if (payment.totalDebt > 0) ...[
                    pw.SizedBox(width: 16),
                    pw.Text(
                      'Remaining Debt: ',
                      style: pw.TextStyle(
                          font: _regular, fontSize: 8.5, color: _textSecondary),
                    ),
                    pw.Text(
                      _fmt(payment.totalDebt),
                      style: pw.TextStyle(
                        font: _bold,
                        fontSize: 8.5,
                        color: payment.totalDebt > 0.0001
                            ? _debtRed
                            : _textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (payment.note != null && payment.note!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionLabel('NOTES'),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _rowAlt,
                border: pw.Border.all(color: _borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                payment.note!,
                style: pw.TextStyle(
                  font: _regular,
                  fontSize: 10,
                  color: _textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pool page header ──────────────────────────────────────────────────────

  static pw.Widget _poolPageHeader(PaymentModel payment, dynamic company) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MONEYROLL',
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 14,
                  color: _gold,
                  letterSpacing: 1.8,
                ),
              ),
              pw.Text(
                'POOL REPORT',
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 9,
                  color: PdfColors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Code badge
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _gold,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  payment.code.isEmpty ? 'M?' : payment.code,
                  style: pw.TextStyle(
                      font: _bold, fontSize: 12, color: PdfColors.white),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (payment.label != null && payment.label!.isNotEmpty)
                      pw.Text(
                        payment.label!,
                        style: pw.TextStyle(
                            font: _regular,
                            fontSize: 9,
                            color: PdfColors.grey400),
                      ),
                    pw.Text(
                      payment.description,
                      style: pw.TextStyle(
                          font: _bold, fontSize: 13, color: PdfColors.white),
                    ),
                    pw.Text(
                      company != null
                          ? 'From: ${company.name}'
                          : 'Cash / Free Entry',
                      style: pw.TextStyle(
                          font: _regular,
                          fontSize: 9,
                          color: PdfColors.grey400),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _fmtDate(payment.date),
                    style: pw.TextStyle(
                        font: _regular,
                        fontSize: 9,
                        color: PdfColors.grey400),
                  ),
                  if (payment.deadline != null)
                    pw.Text(
                      'Due: ${_fmtDate(payment.deadline!)}',
                      style: pw.TextStyle(
                          font: _bold, fontSize: 9, color: _gold),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MONEYROLL  •  ${_fmtDateTime(DateTime.now())}',
            style: pw.TextStyle(font: _regular, fontSize: 7, color: _textMuted),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: _regular, fontSize: 7, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // ── Additional receipts section ───────────────────────────────────────────

  static List<pw.Widget> _buildAdditionalReceiptsSection(
    PaymentModel payment,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final extras = payCtrl.additionalReceipts(payment);
    if (extras.isEmpty) return [];

    double originalAmt = payment.amount;
    if (payment.rootTransferId != null) {
      final root = payCtrl.getTransferById(payment.rootTransferId!);
      if (root != null) originalAmt = root.amount;
    }

    final labelStyle = pw.TextStyle(
      font: _bold,
      fontSize: 8,
      color: _textMuted,
    );
    final cellStyle = pw.TextStyle(
      font: _regular,
      fontSize: 8.5,
      color: _textPrimary,
    );

    return [
      pw.SizedBox(height: 12),
      _sectionLabel('ADDITIONAL RECEIPTS'),
      pw.SizedBox(height: 6),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            // Header row
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _rowAlt,
                borderRadius: const pw.BorderRadius.vertical(
                    top: pw.Radius.circular(6)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Source', style: labelStyle)),
                  pw.SizedBox(width: 8),
                  pw.Text('Date', style: labelStyle),
                  pw.SizedBox(width: 24),
                  pw.SizedBox(
                    width: 72,
                    child: pw.Text('Amount',
                        style: labelStyle,
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ),
            // Base row
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: _borderColor, width: 0.5)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                      child: pw.Text('Base received', style: cellStyle)),
                  pw.SizedBox(width: 8),
                  pw.Text(_fmtDate(payment.date), style: cellStyle),
                  pw.SizedBox(width: 24),
                  pw.SizedBox(
                    width: 72,
                    child: pw.Text(_fmt(originalAmt),
                        style: cellStyle,
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ),
            // Addition rows
            ...extras.map((t) {
              final srcLabel = t.sourcePaymentId != null
                  ? 'From Pool ${payCtrl.getPaymentById(t.sourcePaymentId!)?.code ?? '?'}'
                  : t.fromCompanyId != null
                      ? (compCtrl.getById(t.fromCompanyId!)?.name ?? '?')
                      : 'Free cash';
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: _borderColor, width: 0.5)),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 6,
                      height: 6,
                      margin: const pw.EdgeInsets.only(right: 6, top: 1),
                      decoration: pw.BoxDecoration(
                        color: _green,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                        child: pw.Text(srcLabel, style: cellStyle)),
                    pw.SizedBox(width: 8),
                    pw.Text(_fmtDate(t.createdAt), style: cellStyle),
                    pw.SizedBox(width: 24),
                    pw.SizedBox(
                      width: 72,
                      child: pw.Text(
                        '+${_fmt(t.amount)}',
                        style: cellStyle.copyWith(color: _green),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  // ── Shared PDF widget helpers ─────────────────────────────────────────────

  static pw.Widget _sectionLabel(String text) => pw.Text(
        text,
        style: pw.TextStyle(
          font: _bold,
          fontSize: 9,
          color: _textMuted,
          letterSpacing: 1.2,
        ),
      );

  static pw.Widget _statCell(
    String label,
    String value,
    PdfColor valueColor, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return pw.Expanded(
      child: pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                  font: _regular, fontSize: 7.5, color: _textMuted),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style:
                  pw.TextStyle(font: _bold, fontSize: 10, color: valueColor),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _dividerV() =>
      pw.Container(width: 0.5, height: 44, color: _borderColor);

  // Header cell for flex-row tables (not pw.Table)
  static pw.Widget _hdr(String text, {bool right = false}) => pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: _bold,
          fontSize: 8,
          color: PdfColors.grey400,
          letterSpacing: 0.6,
        ),
      );

  static pw.TableRow _headerRow(List<String> labels) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _headerBg),
      children: labels
          .map(
            (l) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: pw.Text(
                l,
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 7,
                  color: PdfColors.grey400,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.TableRow _dataRow(int idx, List<pw.Widget> cells) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: idx % 2 == 1 ? _rowAlt : PdfColors.white,
      ),
      children: cells,
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? _bold : _regular,
          fontSize: 8.5,
          color: color ?? _textSecondary,
        ),
      ),
    );
  }

  // ── Transfer tree flattening ──────────────────────────────────────────────

  static List<_TransferRow> _flattenTransfers(
    PaymentModel payment,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    final rows = <_TransferRow>[];
    final rootBranches = payCtrl
        .getPaymentTransfers(payment.id)
        .where(
          (t) =>
              t.parentTransferId == null && t.id != payment.rootTransferId,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final t in rootBranches) {
      _collectNode(t, 0, payment, payCtrl, compCtrl, rows);
    }
    return rows;
  }

  static void _collectNode(
    TransferModel t,
    int depth,
    PaymentModel payment,
    PaymentController payCtrl,
    CompanyController compCtrl,
    List<_TransferRow> rows,
  ) {
    final fromName = t.fromCompanyId == null
        ? 'Me'
        : compCtrl.getNameById(t.fromCompanyId);
    final toName = t.toCompanyId == null
        ? 'Me (returned)'
        : compCtrl.getNameById(t.toCompanyId);

    rows.add(_TransferRow(
      transfer: t,
      fromName: fromName,
      toName: toName,
      depth: depth,
    ));

    final children = payCtrl.getChildTransfers(t.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final child in children) {
      _collectNode(child, depth + 1, payment, payCtrl, compCtrl, rows);
    }
  }
}

class _TransferRow {
  final TransferModel transfer;
  final String fromName;
  final String toName;
  final int depth;

  const _TransferRow({
    required this.transfer,
    required this.fromName,
    required this.toName,
    required this.depth,
  });
}
