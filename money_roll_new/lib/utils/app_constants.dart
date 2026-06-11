import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light palette — clean off-white surfaces + deep amber gold accent
  static const Color bg = Color(0xFFF5F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEEF1F4);
  static const Color border = Color(0xFFE3E7EC);

  static const Color gold = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFD4A843);
  static const Color goldDark = Color(0xFF8A6308);

  // Foreground used on top of a solid gold fill (buttons, FABs).
  static const Color onGold = Color(0xFFFFFFFF);

  static const Color green = Color(0xFF1E8E3E);
  static const Color greenBg = Color(0xFFE6F4EA);
  static const Color red = Color(0xFFD93025);
  static const Color redBg = Color(0xFFFCE8E6);
  static const Color amber = Color(0xFFB06000);
  static const Color amberBg = Color(0xFFFEF3E0);
  static const Color blue = Color(0xFF1A73E8);
  static const Color blueBg = Color(0xFFE8F0FE);

  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF5F6571);
  static const Color textMuted = Color(0xFF9AA0AB);

  static const Color debtRed = Color(0xFFC5221F);
  static const Color debtBg = Color(0xFFFCE8E6);
}

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get titleLarge => GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelSmall => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );

  static TextStyle get amount => GoogleFonts.spaceGrotesk(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
    letterSpacing: -0.5,
  );

  static TextStyle get amountSmall => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.gold,
      surface: AppColors.surface,
      error: AppColors.red,
      onPrimary: AppColors.onGold,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      titleTextStyle: AppTextStyles.titleLarge,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      labelStyle: AppTextStyles.bodySmall,
      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerColor: AppColors.border,
    cardColor: AppColors.surface,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}

class AppConstants {
  static const String currency = 'AED';
  static const String currencySymbol = 'د.إ';
  static const String appName = 'MONEYROLL';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String boxPayments = 'payments';
  static const String boxTransfers = 'transfers';
  static const String boxCompanies = 'companies';
  static const String boxCashTx = 'cash_transactions';
  static const String boxDebtClearances = 'debt_clearances';
  static const String boxSettings = 'settings';
}
