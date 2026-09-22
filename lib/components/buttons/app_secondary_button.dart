import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum SecondaryButtonVariant {
  tinted,
  outlined,
}

/// Secondary action button with tinted or outlined styling, 56px touch target
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = SecondaryButtonVariant.tinted,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.fullWidth = true,
    this.height = AppSpacing.minTouchTarget,
  });

  final String text;
  final VoidCallback? onPressed;
  final SecondaryButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    const textColor = AppColors.primary;

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          text,
          style: AppTypography.labelLg.copyWith(color: textColor),
          textAlign: TextAlign.center,
        ),
        if (!isLoading && trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 20, color: textColor),
        ],
      ],
    );

    if (variant == SecondaryButtonVariant.outlined) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.primaryTint,
          foregroundColor: textColor,
          disabledBackgroundColor: AppColors.disabledContainer,
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: content,
      ),
    );
  }
}
