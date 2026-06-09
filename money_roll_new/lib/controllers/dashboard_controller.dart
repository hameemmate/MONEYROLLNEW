import 'package:get/get.dart';
import 'payment_controller.dart';
import 'company_controller.dart';

class DashboardController extends GetxController {
  final PaymentController paymentCtrl = Get.find();
  final CompanyController companyCtrl = Get.find();

  final RxInt selectedTab = 0.obs;

  // Top companies by outstanding balance
  List<MapEntry<String, double>> get topOwingCompanies {
    final balances = paymentCtrl.companyBalances;
    final positive = balances.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return positive.take(5).toList();
  }

  List<MapEntry<String, double>> get topDebtCompanies {
    final balances = paymentCtrl.companyBalances;
    final negative = balances.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return negative.take(5).toList();
  }

  // Monthly chart data (last 6 months)
  List<Map<String, dynamic>> get monthlyChartData {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final sent = paymentCtrl.payments
          .where(
            (p) =>
                p.date.year == month.year &&
                p.date.month == month.month &&
                p.type.name == 'sent',
          )
          .fold(0.0, (sum, p) => sum + p.amount);
      final received = paymentCtrl.payments
          .where(
            (p) =>
                p.date.year == month.year &&
                p.date.month == month.month &&
                p.type.name == 'received',
          )
          .fold(0.0, (sum, p) => sum + p.amount);
      result.add({'month': month, 'sent': sent, 'received': received});
    }
    return result;
  }
}
