import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/company_model.dart';
import 'models/payment_model.dart';
import 'models/transfer_model.dart';
import 'models/cash_transaction_model.dart';
import 'models/enums.dart';
import 'bindings/initial_binding.dart';
import 'utils/app_constants.dart';
import 'utils/app_theme.dart';
import 'views/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Init Hive
  await Hive.initFlutter();

  // Register all adapters manually — no codegen
  Hive.registerAdapter(CompanyModelAdapter());
  Hive.registerAdapter(PaymentModelAdapter());
  Hive.registerAdapter(TransferModelAdapter());
  Hive.registerAdapter(CashTransactionModelAdapter());
  Hive.registerAdapter(PaymentTypeAdapter());
  Hive.registerAdapter(TransferSourceTypeAdapter());
  Hive.registerAdapter(CashTxTypeAdapter());

  // Open all boxes
  await Hive.openBox<CompanyModel>(AppConstants.boxCompanies);
  await Hive.openBox<PaymentModel>(AppConstants.boxPayments);
  await Hive.openBox<TransferModel>(AppConstants.boxTransfers);
  await Hive.openBox<CashTransactionModel>(AppConstants.boxCashTx);
  await Hive.openBox(AppConstants.boxSettings);

  runApp(const CashFlowApp());
}

class CashFlowApp extends StatelessWidget {
  const CashFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      home: const HomeShell(),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
