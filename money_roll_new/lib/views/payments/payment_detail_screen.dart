import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/company_controller.dart';
import '../../models/enums.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../widgets/transfer_tree_widget.dart';

class PaymentDetailScreen extends StatelessWidget {
  final String paymentId;

  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    final payCtrl = Get.find<PaymentController>();
    final compCtrl = Get.find<CompanyController>();

    return Obx(() {
      // Establish reactive dependencies so this screen and the transfer tree
      // rebuild whenever payments or transfers change (e.g. a branch is added).
      final _ = payCtrl.payments.length + payCtrl.transfers.length;
      final payment = payCtrl.getPaymentById(paymentId);
      if (payment == null) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: const Center(
            child: Text(
              'Payment not found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      }

      final company = payment.companyId != null
          ? compCtrl.getById(payment.companyId!)
          : null;
      final isSent = payment.type == PaymentType.sent;
      final typeColor = isSent ? AppColors.red : AppColors.green;

      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text(
            'Payment Details',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.red,
                size: 20,
              ),
              onPressed: () => _confirmDelete(context, payCtrl),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSent
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 12,
                                color: typeColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSent ? 'SENT' : 'RECEIVED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            payment.code.isEmpty ? '—' : payment.code,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppUtils.formatDate(payment.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (payment.label != null &&
                        payment.label!.trim().isNotEmpty) ...[
                      Text(
                        payment.label!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      payment.description,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (company != null)
                      Row(
                        children: [
                          CompanyAvatar(name: company.name, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            company.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const CFDivider(),
                    const SizedBox(height: 16),
                    // Amount breakdown
                    _amountRow('Total Amount', payment.amount, typeColor),
                    const SizedBox(height: 8),
                    _amountRow(
                      'Forwarded',
                      payment.amount - payment.remainingAmount,
                      AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    _amountRow(
                      'Remaining',
                      payment.remainingAmount,
                      payment.remainingAmount > 0
                          ? AppColors.amber
                          : AppColors.textMuted,
                    ),
                    if (payment.totalDebt > 0) ...[
                      const SizedBox(height: 8),
                      _amountRow(
                        'Total Debt in Chain',
                        payment.totalDebt,
                        AppColors.debtRed,
                      ),
                    ],
                    if (payment.note != null && payment.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const CFDivider(),
                      const SizedBox(height: 12),
                      Text(
                        payment.note!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Transfer chain section
              const SectionHeader(title: 'Transfer Chain'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tap + buttons to add more transfers in the chain. Each company can forward their received amount.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tree
              TransferTreeWidget(paymentId: paymentId, allowAddTransfer: true),

              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    });
  }

  Widget _amountRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          AppUtils.formatAmount(amount),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, PaymentController payCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete Payment?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will delete the payment and all transfers in the chain. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              await payCtrl.deletePayment(paymentId);
              Get.back(); // leave detail screen
              AppUtils.showSuccess('Deleted', 'Payment removed');
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
