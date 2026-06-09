import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_roll_new/utils/app_constants.dart';
import 'package:money_roll_new/utils/app_utils.dart';

class StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color? amountColor;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isCount; // Add this

  const StatCard({
    super.key,
    required this.label,
    required this.amount,
    this.amountColor,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.isCount = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.gold).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? AppColors.gold,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isCount
                  ? amount
                        .toInt()
                        .toString() // Show as integer for counts
                  : AppUtils.formatAmountCompact(amount),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: amountColor ?? AppColors.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanyAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? bgColor;

  const CompanyAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFE3ECF7),
      const Color(0xFFEDE7F6),
      const Color(0xFFE6F4EA),
      const Color(0xFFFCE8E6),
      const Color(0xFFFEF3E0),
    ];
    final colorIndex = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor ?? colors[colorIndex],
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          AppUtils.initials(name),
          style: GoogleFonts.spaceGrotesk(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class AmountBadge extends StatelessWidget {
  final double amount;
  final bool isPositive;
  final bool isDebt;

  const AmountBadge({
    super.key,
    required this.amount,
    required this.isPositive,
    this.isDebt = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (isDebt) {
      bg = AppColors.debtBg;
      fg = AppColors.debtRed;
    } else if (isPositive) {
      bg = AppColors.greenBg;
      fg = AppColors.green;
    } else {
      bg = AppColors.redBg;
      fg = AppColors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppUtils.formatAmount(amount),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 13, color: AppColors.gold),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              GoldButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSmall;
  final bool isOutlined;
  final IconData? icon;

  /// While true the button ignores taps and shows a spinner. Used to block
  /// duplicate submissions while an async action is in flight.
  final bool isLoading;

  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isSmall = false,
    this.isOutlined = false,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = isOutlined ? AppColors.gold : AppColors.onGold;
    return Opacity(
      opacity: isLoading ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 16 : 24,
            vertical: isSmall ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : AppColors.gold,
            borderRadius: BorderRadius.circular(10),
            border: isOutlined ? Border.all(color: AppColors.gold) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: isSmall ? 13 : 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CFDivider extends StatelessWidget {
  const CFDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.border, height: 1);
  }
}

/// Small chip showing a deadline, turning red/amber when due soon or overdue.
class DeadlineChip extends StatelessWidget {
  final DateTime deadline;
  final bool compact;

  const DeadlineChip({super.key, required this.deadline, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(deadline.year, deadline.month, deadline.day);
    final days = due.difference(today).inDays;

    Color fg;
    Color bg;
    String text;
    if (days < 0) {
      fg = AppColors.red;
      bg = AppColors.redBg;
      text = compact ? 'Overdue' : 'Overdue ${-days}d';
    } else if (days == 0) {
      fg = AppColors.amber;
      bg = AppColors.amberBg;
      text = 'Due today';
    } else if (days <= 3) {
      fg = AppColors.amber;
      bg = AppColors.amberBg;
      text = 'Due in ${days}d';
    } else {
      fg = AppColors.textSecondary;
      bg = AppColors.surfaceAlt;
      text = AppUtils.formatDateShort(deadline);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
