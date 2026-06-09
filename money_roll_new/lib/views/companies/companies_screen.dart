import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_roll_new/views/companies/company_balance_screen.dart';
import '../../controllers/company_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../models/company_model.dart';
import '../../utils/app_constants.dart';
import '../widgets/common_widgets.dart';
import '../payments/payments_screen.dart';

class CompaniesScreen extends StatelessWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compCtrl = Get.find<CompanyController>();
    final payCtrl = Get.find<PaymentController>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Companies & Partners',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Balance button to see who owes whom
          IconButton(
            icon: const Icon(Icons.balance, color: AppColors.gold),
            onPressed: () => Get.to(() => const CompanyBalanceScreen()),
          ),
          // Add company button
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _showAddEditSheet(context, compCtrl),
          ),
        ],
      ),
      body: Obx(() {
        if (compCtrl.companies.isEmpty) {
          return EmptyState(
            icon: Icons.business_outlined,
            title: 'No companies yet',
            subtitle: 'Add companies and partners to track payments',
            actionLabel: 'Add Company',
            onAction: () => _showAddEditSheet(context, compCtrl),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: compCtrl.companies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final company = compCtrl.companies[i];

            return Dismissible(
              key: Key(company.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.red),
              ),
              confirmDismiss: (_) => _confirmDelete(context, company, compCtrl),
              child: GestureDetector(
                onTap: () {
                  // Navigate to payments screen filtered for this company
                  Get.to(
                    () => const PaymentsScreen(),
                    transition: Transition.cupertino,
                    duration: const Duration(milliseconds: 280),
                    arguments: {
                      'filterCompanyId': company.id,
                      'companyName': company.name,
                    },
                  );
                },
                onLongPress: () =>
                    _showAddEditSheet(context, compCtrl, editing: company),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
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
                            if (company.phone != null &&
                                company.phone!.isNotEmpty)
                              Text(
                                company.phone!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (company.notes != null &&
                                company.notes!.isNotEmpty)
                              Text(
                                company.notes!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            // Payment count
                            Obx(() {
                              final count = payCtrl.payments
                                  .where((p) => p.companyId == company.id)
                                  .length;
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$count payment${count == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => _showAddEditSheet(
                              context,
                              compCtrl,
                              editing: company,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "companies_fab", // Unique tag
        onPressed: () => _showAddEditSheet(context, compCtrl),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Company',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showAddEditSheet(
    BuildContext context,
    CompanyController compCtrl, {
    CompanyModel? editing,
  }) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
              editing == null
                  ? 'Add Company / Partner'
                  : 'Edit ${editing.name}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter company name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '+1234567890',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional information...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (editing != null)
                  Expanded(
                    child: GoldButton(
                      label: 'Delete',
                      isOutlined: true,
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await _confirmDelete(
                          context,
                          editing,
                          compCtrl,
                        );
                        if (confirm == true) {
                          await compCtrl.deleteCompany(editing.id);
                        }
                      },
                    ),
                  ),
                if (editing != null) const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(
                    label: editing == null ? 'Add Company' : 'Save Changes',
                    onTap: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Name is required',
                          backgroundColor: AppColors.redBg,
                          colorText: AppColors.red,
                        );
                        return;
                      }

                      if (editing == null) {
                        await compCtrl.addCompany(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        );
                      } else {
                        editing.name = nameCtrl.text.trim();
                        editing.phone = phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim();
                        editing.notes = notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim();
                        await compCtrl.updateCompany(editing);
                      }
                      Navigator.pop(context);
                      Get.snackbar(
                        'Success',
                        editing == null ? 'Company added' : 'Company updated',
                        backgroundColor: AppColors.greenBg,
                        colorText: AppColors.green,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    CompanyModel company,
    CompanyController compCtrl,
  ) async {
    final paymentCount = Get.find<PaymentController>().payments
        .where((p) => p.companyId == company.id)
        .length;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete ${company.name}?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This company has $paymentCount payment(s).',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting this company will remove it from all payments and transfers. This action cannot be undone.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
