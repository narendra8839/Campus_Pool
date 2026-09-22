import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum RideStatusType {
  active,
  available,
  pending,
  confirmed,
  completed,
  cancelled,
}

/// Pill status badge indicating ride/driver/request state
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.showDot = true,
  });

  final RideStatusType status;
  final String? customLabel;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      RideStatusType.active => (
          AppColors.secondaryTint,
          AppColors.secondary,
          customLabel ?? 'Active',
        ),
      RideStatusType.available => (
          AppColors.primaryTint,
          AppColors.primary,
          customLabel ?? 'Available',
        ),
      RideStatusType.confirmed => (
          AppColors.secondaryTint,
          AppColors.secondary,
          customLabel ?? 'Confirmed',
        ),
      RideStatusType.pending => (
          AppColors.warningTint,
          AppColors.tertiary,
          customLabel ?? 'Pending',
        ),
      RideStatusType.cancelled => (
          AppColors.errorTint,
          AppColors.error,
          customLabel ?? 'Cancelled',
        ),
      RideStatusType.completed => (
          AppColors.surfaceContainerLow,
          AppColors.onSurfaceVariant,
          customLabel ?? 'Completed',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusFull,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
