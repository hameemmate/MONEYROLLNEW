import 'package:get/get.dart';
import 'package:money_roll_new/models/payment_model.dart';
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
      final monthPayments = paymentCtrl.payments.where(
        (p) => p.date.year == month.year && p.date.month == month.month,
      );
      final received = monthPayments
          .where((p) => p.type.name == 'received')
          .fold(0.0, (sum, p) => sum + p.amount);
      final debt = monthPayments
          .where((p) => p.type.name == 'received')
          .fold(0.0, (sum, p) => sum + p.totalDebt);
      result.add({'month': month, 'debt': debt, 'received': received});
    }
    return result;
  }

  /// Payments that have a deadline (on the payment or any branch) that is today or in the past.
  List<PaymentModel> get upcomingDeadlinePayments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <PaymentModel>[];

    for (final payment in paymentCtrl.payments) {
      bool hasDeadline = false;

      // Check payment's own deadline
      if (payment.deadline != null) {
        final d = DateTime(
          payment.deadline!.year,
          payment.deadline!.month,
          payment.deadline!.day,
        );
        if (d.compareTo(today) <= 0) hasDeadline = true;
      }

      // Check any transfer (branch) deadlines
      if (!hasDeadline) {
        for (final t in paymentCtrl.transfers.where(
          (t) => t.paymentId == payment.id,
        )) {
          if (t.deadline != null) {
            final d = DateTime(
              t.deadline!.year,
              t.deadline!.month,
              t.deadline!.day,
            );
            if (d.compareTo(today) <= 0) {
              hasDeadline = true;
              break;
            }
          }
        }
      }

      if (hasDeadline) result.add(payment);
    }

    // Sort by the earliest deadline (payment or any of its branches)
    result.sort((a, b) {
      DateTime? earliestFor(PaymentModel p) {
        DateTime? earliest = p.deadline;
        for (final t in paymentCtrl.transfers.where(
          (t) => t.paymentId == p.id,
        )) {
          if (t.deadline != null) {
            if (earliest == null || t.deadline!.isBefore(earliest)) {
              earliest = t.deadline;
            }
          }
        }
        return earliest;
      }

      final aDate = earliestFor(a);
      final bDate = earliestFor(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    return result;
  }
}
