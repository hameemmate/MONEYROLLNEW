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

class AddPaymentScreen extends StatefulWidget {
  /// When provided, the screen edits this payment instead of creating one.
  final PaymentModel? existing;

  const AddPaymentScreen({super.key, this.existing});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final payCtrl = Get.find<PaymentController>();
  final compCtrl = Get.find<CompanyController>();

  PaymentType _type = PaymentType.received;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  String? _selectedCompanyId;
  DateTime _selectedDate = DateTime.now();
  DateTime? _deadline;
  bool _loading = false;
  bool _isDebt = true;

  bool get _isEdit => widget.existing != null;

  /// The company is locked once the payment has real branches, so the debt
  /// records in the tree stay consistent. The root receipt record does not
  /// count as a branch.
  bool _companyLocked = false;

  /// The pool can never shrink below what was already used from it.
  double _minAmount = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _descCtrl.text = e.description;
      _noteCtrl.text = e.note ?? '';
      _labelCtrl.text = e.label ?? '';
      _selectedCompanyId = e.companyId;
      _selectedDate = e.date;
      _deadline = e.deadline;
      _companyLocked = payCtrl
          .getPaymentTransfers(e.id)
          .any((t) => t.id != e.rootTransferId);
      final used = e.amount - payCtrl.availableFromPool(e);
      _minAmount = used > 0 ? used : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          _isEdit ? 'Edit Payment' : 'New Payment',
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
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation card. Payments are always "received" pools now —
              // sending money is only possible by branching from a pool.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _type == PaymentType.sent
                            ? 'Legacy sent payment — cash left your hand when it was created.'
                            : 'Creates a pool of received cash. Cash received from a company is debt you owe them. Send money onward by branching from the pool.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.green.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Amount
              Text('Amount', style: _labelStyle()),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '${AppConstants.currencySymbol} ',
                  prefixStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                  hintText: '0.00',
                  helperText: _minAmount > 0
                      ? 'Minimum ${AppUtils.formatAmount(_minAmount, showSymbol: false)} — already used from this pool'
                      : null,
                  helperStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text('Description', style: _labelStyle()),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'What is this payment for?',
                ),
              ),
              const SizedBox(height: 16),

              // Optional label (code like M1 is auto-assigned)
              Row(
                children: [
                  Text('Label', style: _labelStyle()),
                  const SizedBox(width: 6),
                  Text(
                    '· code auto-assigned (M1, M2…)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _labelCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Optional name, e.g. "October payroll"',
                ),
              ),
              const SizedBox(height: 16),

              // Company
              Text(
                _type == PaymentType.sent ? 'Sent To' : 'Receive From',
                style: _labelStyle(),
              ),
              const SizedBox(height: 8),
              Obx(
                () => DropdownButtonFormField<String>(
                  value: _selectedCompanyId,
                  dropdownColor: AppColors.surfaceAlt,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _type == PaymentType.received
                        ? 'Optional – free entry allowed'
                        : 'Select company',
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        _type == PaymentType.received
                            ? 'Free / No company'
                            : 'Select...',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
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
                  onChanged: _companyLocked
                      ? null
                      : (val) => setState(() {
                            _selectedCompanyId = val;
                            if (val == null) _isDebt = true;
                          }),
                ),
              ),
              // Debt toggle — shown only when receiving from a specific company
              if (_type == PaymentType.received && _selectedCompanyId != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isDebt ? AppColors.redBg : AppColors.greenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isDebt
                          ? AppColors.debtRed.withOpacity(0.4)
                          : AppColors.green.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDebt ? 'I owe this back' : 'No obligation',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isDebt ? AppColors.debtRed : AppColors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isDebt
                                  ? 'Tracked as debt — counts toward what you owe this company.'
                                  : 'Received freely — no debt entry will be created.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDebt,
                        onChanged: (val) => setState(() => _isDebt = val),
                        activeColor: AppColors.debtRed,
                        inactiveThumbColor: AppColors.green,
                        inactiveTrackColor: AppColors.greenBg,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),

              // Date
              Text('Date', style: _labelStyle()),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppUtils.formatDate(_selectedDate),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Deadline (optional)
              Text('Deadline (Optional)', style: _labelStyle()),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                        _deadline == null
                            ? 'No deadline'
                            : AppUtils.formatDate(_deadline!),
                        style: TextStyle(
                          color: _deadline == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (_deadline != null)
                        GestureDetector(
                          onTap: () => setState(() => _deadline = null),
                          child: const Icon(
                            Icons.clear,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Text('Note (Optional)', style: _labelStyle()),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Any additional notes...',
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : GoldButton(
                        label: _isEdit ? 'Save Changes' : 'Create Payment Pool',
                        icon: _isEdit ? Icons.check : Icons.arrow_downward,
                        onTap: _submit,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() => const TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
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
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (_loading) return; // block duplicate submissions while in flight

    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      AppUtils.showError('Error', 'Enter valid amount');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      AppUtils.showError('Error', 'Enter description');
      return;
    }
    if (_isEdit && amt < _minAmount - 0.0001) {
      AppUtils.showError(
        'Error',
        'Amount cannot go below ${AppUtils.formatAmount(_minAmount)} — already used from this pool',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await payCtrl.updatePayment(
          widget.existing!.id,
          description: _descCtrl.text.trim(),
          label: _labelCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          date: _selectedDate,
          deadline: _deadline,
          amount: amt,
          companyId: _selectedCompanyId,
        );
        Get.back();
        AppUtils.showSuccess(
          'Payment Updated',
          'Saved changes to ${widget.existing!.code}',
        );
        return;
      }

      await payCtrl.createPayment(
        type: _type,
        amount: amt,
        description: _descCtrl.text.trim(),
        companyId: _selectedCompanyId,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        date: _selectedDate,
        deadline: _deadline,
        isDebt: _isDebt,
      );

      Get.back();
      AppUtils.showSuccess(
        'Payment Created',
        '${_type == PaymentType.sent ? 'Sent' : 'Received'} ${AppUtils.formatAmount(amt)}',
      );
    } catch (e) {
      AppUtils.showError('Error', e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
}
