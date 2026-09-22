import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Role and transport mode selector chip (e.g. Scooter, Bike, Carpool, Rider)
class AppRoleChip extends StatelessWidget {
  const AppRoleChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.badgeText,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? AppColors.primary : AppColors.surface;
    final fgColor = isSelected ? AppColors.onPrimary : AppColors.onSurface;
    final borderColor = isSelected ? AppColors.primary : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.radiusFull,
        onTap: () => onSelected(!isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppSpacing.radiusFull,
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.onPrimary.withValues(alpha: 0.2)
                        : AppColors.secondaryTint,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                  child: Text(
                    badgeText!,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? AppColors.onPrimary : AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
