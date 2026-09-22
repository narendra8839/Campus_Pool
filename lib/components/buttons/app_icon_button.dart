import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Campus Pool circular/rounded icon button with accessible touch target
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = AppSpacing.iconButtonSize,
    this.iconSize = 20.0,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.onSurface,
    this.hasBorder = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool hasBorder;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.radiusMd,
        border: hasBorder ? Border.all(color: AppColors.border, width: 1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppSpacing.radiusMd,
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: iconSize, color: foregroundColor),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
