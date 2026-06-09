import 'package:get/get.dart';
import '../controllers/payment_controller.dart';
import '../controllers/company_controller.dart';
import '../controllers/dashboard_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CompanyController>(CompanyController(), permanent: true);
    Get.put<PaymentController>(PaymentController(), permanent: true);
    Get.put<DashboardController>(DashboardController(), permanent: true);
  }
}
