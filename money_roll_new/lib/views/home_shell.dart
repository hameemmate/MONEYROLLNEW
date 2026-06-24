import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_roll_new/views/companies/companies_screen.dart';
import 'package:money_roll_new/views/dashboard/dashboard_screen.dart';
import 'package:money_roll_new/views/payments/add_payment_screen.dart';
import 'package:money_roll_new/views/payments/payments_screen.dart';
import 'package:money_roll_new/views/settings/settings_screen.dart';
import '../../controllers/dashboard_controller.dart';
import '../../utils/app_constants.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final dashCtrl = Get.find<DashboardController>();

    return Obx(() {
      final tab = dashCtrl.selectedTab.value;
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(
          index: tab,
          children: const [
            DashboardScreen(),
            PaymentsScreen(),
            CompaniesScreen(),
            SettingsScreen(),
          ],
        ),
        floatingActionButton: tab == 0 || tab == 1
            ? FloatingActionButton(
                heroTag: 'home_fab_$tab',
                onPressed: () => Get.to(() => const AddPaymentScreen()),
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.onGold,
                child: const Icon(Icons.add, size: 26),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(context, 0, Icons.dashboard_outlined,
                      Icons.dashboard, 'Home', dashCtrl),
                  _navItem(context, 1, Icons.receipt_long_outlined,
                      Icons.receipt_long, 'Payments', dashCtrl),
                  const SizedBox(width: 60),
                  _navItem(context, 2, Icons.business_outlined,
                      Icons.business, 'Companies', dashCtrl),
                  _navItem(context, 3, Icons.settings_outlined,
                      Icons.settings, 'Settings', dashCtrl),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
    DashboardController ctrl,
  ) {
    final selected = ctrl.selectedTab.value == index;
    return GestureDetector(
      onTap: () => ctrl.selectedTab.value = index,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? iconFilled : iconOutlined,
              size: 20,
              color: selected ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
