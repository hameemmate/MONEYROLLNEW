import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/company_model.dart';
import '../utils/app_constants.dart';

class CompanyController extends GetxController {
  late Box<CompanyModel> _box;
  final _uuid = const Uuid();

  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _box = Hive.box<CompanyModel>(AppConstants.boxCompanies);
    _loadCompanies();
    _box.listenable().addListener(_loadCompanies);
  }

  void _loadCompanies() {
    companies.value = _box.values.where((c) => !c.isArchived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  CompanyModel? getById(String id) {
    try {
      return _box.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  String getNameById(String? id) {
    if (id == null) return 'Me';
    return getById(id)?.name ?? 'Unknown';
  }

  Future<CompanyModel> addCompany({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final company = CompanyModel(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim(),
      notes: notes?.trim(),
      createdAt: DateTime.now(),
    );
    await _box.put(company.id, company);
    return company;
  }

  Future<void> updateCompany(CompanyModel company) async {
    await _box.put(company.id, company);
  }

  Future<void> archiveCompany(String id) async {
    final company = getById(id);
    if (company != null) {
      company.isArchived = true;
      await _box.put(id, company);
      _loadCompanies();
    }
  }

  Future<void> deleteCompany(String id) async {
    await _box.delete(id);
    _loadCompanies();
  }

  List<CompanyModel> get activeCompanies =>
      companies.where((c) => !c.isArchived).toList();

  // Returns companies with balance summary
  // balance > 0 means they owe ME, balance < 0 means I owe THEM
  Map<String, double> getCompanyBalances(List<dynamic> transfers) {
    // Calculated in PaymentController, exposed here for UI
    return {};
  }

  // Add to CompanyController class
  Future<void> deleteAllCompanies() async {
    await _box.clear();
    _loadCompanies();
  }
}
