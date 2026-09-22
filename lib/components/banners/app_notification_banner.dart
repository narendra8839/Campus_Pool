import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum NotificationBannerType {
  info,
  success,
  warning,
  error,
}

/// In-app notification & biker match alert banner matching Stitch notification designs
class AppNotificationBanner extends StatelessWidget {
  const AppNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    this.type = NotificationBannerType.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.leadingWidget,
  });

  final String title;
  final String message;
  final NotificationBannerType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final Widget? leadingWidget;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, defaultIcon) = switch (type) {
      NotificationBannerType.info => (
          AppColors.primaryTint,
          AppColors.primaryContainer.withValues(alpha: 0.3),
          AppColors.primary,
          Icons.info_outline_rounded,
        ),
      NotificationBannerType.success => (
          AppColors.secondaryTint,
          AppColors.secondaryLight.withValues(alpha: 0.3),
          AppColors.secondary,
          Icons.check_circle_outline_rounded,
        ),
      NotificationBannerType.warning => (
          AppColors.warningTint,
          AppColors.tertiaryLight.withValues(alpha: 0.3),
          AppColors.tertiary,
          Icons.warning_amber_rounded,
        ),
      NotificationBannerType.error => (
          AppColors.errorTint,
          AppColors.error.withValues(alpha: 0.3),
          AppColors.error,
          Icons.error_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: border, width: 1.2),
        boxShadow: AppShadows.level2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leadingWidget ??
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(defaultIcon, color: fg, size: 20),
              ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (onDismiss != null)
                      GestureDetector(
                        onTap: onDismiss,
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: AppTypography.labelMd.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
