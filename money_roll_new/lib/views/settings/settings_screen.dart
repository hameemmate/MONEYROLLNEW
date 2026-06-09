import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/company_model.dart';
import '../../models/payment_model.dart';
import '../../models/transfer_model.dart';
import '../../models/cash_transaction_model.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          'Settings',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Obx(
              () => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _summaryItem(
                          'Cash in Hand',
                          AppUtils.formatAmount(payCtrl.cashInHand.value),
                          AppColors.gold,
                        ),
                        _summaryItem(
                          'Payments',
                          '${payCtrl.payments.length}',
                          AppColors.blue,
                        ),
                        _summaryItem(
                          'Companies',
                          '${compCtrl.companies.length}',
                          AppColors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Data'),
            _settingsTile(
              icon: Icons.file_download_outlined,
              label: 'Export JSON Backup',
              subtitle: 'Save backup file to device',
              iconColor: AppColors.blue,
              onTap: () => _exportData(payCtrl, compCtrl),
            ),
            _settingsTile(
              icon: Icons.file_upload_outlined,
              label: 'Import JSON Backup',
              subtitle: 'Restore data from backup file',
              iconColor: AppColors.green,
              onTap: () => _importData(payCtrl, compCtrl),
            ),
            _settingsTile(
              icon: Icons.copy_outlined,
              label: 'Copy Data to Clipboard',
              subtitle: 'Copy JSON to clipboard',
              iconColor: AppColors.amber,
              onTap: () => _copyToClipboard(payCtrl),
            ),
            const SizedBox(height: 16),

            _sectionLabel('App Info'),
            _infoTile('App Name', AppConstants.appName),
            _infoTile('Version', AppConstants.appVersion),
            _infoTile(
              'Currency',
              '${AppConstants.currency} (${AppConstants.currencySymbol})',
            ),
            _infoTile('Storage', 'Hive (local, offline)'),
            const SizedBox(height: 16),

            _sectionLabel('About'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MONEYROLL',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'An offline-first cash management app for HR professionals. '
                    'Track cash in hand, send/receive payments, and follow the full '
                    'transfer chain from company to company — all locally, no internet needed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const CFDivider(),
                  const SizedBox(height: 12),
                  _featurePoint('Track cash in hand with full ledger history'),
                  _featurePoint(
                    'Transfer chain: A → B → C with tree visualization',
                  ),
                  _featurePoint('Debt tracking when transfers exceed balance'),
                  _featurePoint('Source-based and total-based transfer splits'),
                  _featurePoint('Company/partner balance overview'),
                  _featurePoint('JSON export backup'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
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

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _featurePoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppColors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Export Method ====================
  Future<void> _exportData(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) async {
    try {
      // Prepare export data
      final exportData = _prepareExportData(payCtrl, compCtrl);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Convert string to bytes
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Save file
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: Platform.isIOS ? 'Save to Files' : 'Save Backup',
        fileName: 'moneyroll_backup_$timestamp.json',
        allowedExtensions: ['json'],
        lockParentWindow: true,
        bytes: bytes,
      );

      if (outputFile != null) {
        _showSuccessSnackbar('Backup saved successfully');
        debugPrint('Backup saved at: $outputFile');
      } else {
        _showErrorSnackbar('Backup cancelled');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to save backup: ${e.toString()}');
    }
  }

  Map<String, dynamic> _prepareExportData(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) {
    return {
      'companies': compCtrl.companies
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'phone': c.phone,
              'notes': c.notes,
              'createdAt': c.createdAt.toIso8601String(),
              'isArchived': c.isArchived,
            },
          )
          .toList(),
      'payments': payCtrl.payments
          .map(
            (p) => {
              'id': p.id,
              'code': p.code,
              'label': p.label,
              'type': p.type.name,
              'amount': p.amount,
              'description': p.description,
              'date': p.date.toIso8601String(),
              'createdAt': p.createdAt.toIso8601String(),
              'rootTransferId': p.rootTransferId,
              'remainingAmount': p.remainingAmount,
              'totalDebt': p.totalDebt,
              'companyId': p.companyId,
              'note': p.note,
              'deadline': p.deadline?.toIso8601String(),
            },
          )
          .toList(),
      'transfers': payCtrl.transfers
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
              'deadline': t.deadline?.toIso8601String(),
              'createdAt': t.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'cashTransactions': payCtrl.cashTransactions
          .map(
            (tx) => {
              'id': tx.id,
              'txType': tx.txType.name,
              'amount': tx.amount,
              'description': tx.description,
              'relatedPaymentId': tx.relatedPaymentId,
              'relatedTransferId': tx.relatedTransferId,
              'fromCompanyId': tx.fromCompanyId,
              'date': tx.date.toIso8601String(),
              'createdAt': tx.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'companyBalances': payCtrl.companyBalances,
      'cashInHand': payCtrl.cashInHand.value,
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': AppConstants.appVersion,
    };
  }

  // ==================== Import Method ====================
  Future<void> _importData(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) async {
    try {
      // Show confirmation dialog before import
      final bool? proceed = await _showImportConfirmationDialog();

      if (proceed != true) {
        return; // User cancelled
      }

      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        // Show loading indicator
        Get.dialog(
          const Center(
            child: Material(
              color: Colors.transparent,
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
          barrierDismissible: false,
        );

        final filePath = result.files.single.path!;
        final contents = await File(filePath).readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);

        await _clearExistingData(payCtrl, compCtrl);
        await _importDataFromMap(data, payCtrl, compCtrl);

        // Close loading dialog
        Get.back();

        _showSuccessSnackbar('Data imported successfully');
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) Get.back();
      _showErrorSnackbar('Failed to import data: $e');
    }
  }

  Future<bool?> _showImportConfirmationDialog() async {
    return await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Import Data',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please note:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.redBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '⚠️ This will replace ALL existing data with imported data.',
                style: TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure you have a backup before proceeding.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Where to find backup files:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• Backup files can be saved anywhere on your device',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '• Look in your Downloads folder or Files app',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '• File name format: moneyroll_backup_[timestamp].json',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.onGold,
            ),
            child: const Text('Proceed & Replace'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _clearExistingData(
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) async {
    // Clear all Hive boxes
    await payCtrl.deleteAllData(); // You need to add this method
    await compCtrl.deleteAllCompanies(); // You need to add this method
  }

  Future<void> _importDataFromMap(
    Map<String, dynamic> data,
    PaymentController payCtrl,
    CompanyController compCtrl,
  ) async {
    final companies = _asList(data['companies'])
        .map(_companyFromJson)
        .toList();
    final payments = _asList(data['payments']).map(_paymentFromJson).toList();
    final transfers = _asList(data['transfers']).map(_transferFromJson).toList();
    final cashTransactions = _asList(data['cashTransactions'])
        .map(_cashTxFromJson)
        .toList();

    await compCtrl.importCompanies(companies);
    await payCtrl.importData(
      payments: payments,
      transfers: transfers,
      cashTransactions: cashTransactions,
    );
  }

  // ==================== JSON Parsing Helpers ====================

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  CompanyModel _companyFromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      isArchived: (json['isArchived'] as bool?) ?? false,
    );
  }

  PaymentModel _paymentFromJson(Map<String, dynamic> json) {
    final date = _toDate(json['date']) ?? DateTime.now();
    return PaymentModel(
      id: json['id'] as String,
      type: PaymentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentType.received,
      ),
      amount: _toDouble(json['amount']),
      companyId: json['companyId'] as String?,
      rootTransferId: json['rootTransferId'] as String?,
      description: (json['description'] as String?) ?? '',
      date: date,
      createdAt: _toDate(json['createdAt']) ?? date,
      remainingAmount: _toDouble(json['remainingAmount']),
      totalDebt: _toDouble(json['totalDebt']),
      note: json['note'] as String?,
      code: (json['code'] as String?) ?? '',
      label: json['label'] as String?,
      deadline: _toDate(json['deadline']),
    );
  }

  TransferModel _transferFromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'] as String,
      paymentId: json['paymentId'] as String,
      parentTransferId: json['parentTransferId'] as String?,
      amount: _toDouble(json['amount']),
      fromCompanyId: json['fromCompanyId'] as String?,
      toCompanyId: json['toCompanyId'] as String?,
      sourceType: TransferSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => TransferSourceType.fromTotal,
      ),
      specificParentTransferId: json['specificParentTransferId'] as String?,
      note: json['note'] as String?,
      // Older backups used 'date' for the transfer timestamp.
      createdAt: _toDate(json['createdAt']) ?? _toDate(json['date']) ??
          DateTime.now(),
      isDebt: (json['isDebt'] as bool?) ?? false,
      debtAmount: _toDouble(json['debtAmount']),
      code: (json['code'] as String?) ?? '',
      label: json['label'] as String?,
      deadline: _toDate(json['deadline']),
    );
  }

  CashTransactionModel _cashTxFromJson(Map<String, dynamic> json) {
    final date = _toDate(json['date']) ?? DateTime.now();
    return CashTransactionModel(
      id: json['id'] as String,
      txType: CashTxType.values.firstWhere(
        // Newer backups use 'txType'; older clipboard exports used 'type'.
        (e) => e.name == (json['txType'] ?? json['type']),
        orElse: () => CashTxType.add,
      ),
      amount: _toDouble(json['amount']),
      description: (json['description'] as String?) ?? '',
      relatedPaymentId: json['relatedPaymentId'] as String?,
      relatedTransferId: json['relatedTransferId'] as String?,
      fromCompanyId: json['fromCompanyId'] as String?,
      date: date,
      createdAt: _toDate(json['createdAt']) ?? date,
    );
  }

  // ==================== Copy to Clipboard ====================
  Future<void> _copyToClipboard(PaymentController payCtrl) async {
    try {
      final data = payCtrl.exportAllData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      _showSuccessSnackbar('Data copied to clipboard');
    } catch (e) {
      _showErrorSnackbar('Failed to copy: ${e.toString()}');
    }
  }

  // ==================== Helper Methods ====================
  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: AppColors.greenBg,
      colorText: AppColors.green,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: AppColors.redBg,
      colorText: AppColors.red,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
