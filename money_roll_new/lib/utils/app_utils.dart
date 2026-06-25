import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'app_constants.dart';

class AppUtils {
  /// Show a success message, closing any snackbar already on screen so they
  /// never stack or linger after a form is submitted.
  static void showSuccess(String title, String message) {
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.greenBg,
      colorText: AppColors.green,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Show an error message, closing any snackbar already on screen first.
  static void showError(String title, String message) {
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.redBg,
      colorText: AppColors.red,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static String formatAmount(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##0.00');
    final formatted = formatter.format(amount.abs());
    if (showSymbol) {
      return '${AppConstants.currencySymbol} $formatted';
    }
    return formatted;
  }

  /// Like [formatAmount] but keeps the minus sign for negative values.
  /// Use where a value can legitimately be negative, e.g. cash in hand.
  static String formatAmountSigned(double amount, {bool showSymbol = true}) {
    final sign = amount < 0 ? '-' : '';
    return '$sign${formatAmount(amount, showSymbol: showSymbol)}';
  }

  static String formatAmountCompact(double amount) {
    if (amount >= 1000000) {
      return '${AppConstants.currencySymbol} ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${AppConstants.currencySymbol} ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return formatAmount(amount);
  }

  /// Plain number without currency symbol — used inside bracket lists like "(20, 49, 50)".
  static String formatAmountNum(double amount) {
    if (amount == amount.truncateToDouble()) {
      return NumberFormat('#,##0').format(amount);
    }
    return NumberFormat('#,##0.##').format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return formatDateShort(date);
  }

  static String initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }
}
