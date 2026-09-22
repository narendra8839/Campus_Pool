import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Campus Pool Search Bar with quick filter action and clear option
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search campus pickup, drop-off, or route...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.onClear,
    this.hasFilter = true,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;
  final bool hasFilter;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.minTouchTarget,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller?.text.isNotEmpty ?? false)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.onSurfaceVariant),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                    onChanged?.call('');
                  },
                ),
              if (hasFilter) ...[
                Container(
                  height: 24,
                  width: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                  onPressed: onFilterTap,
                  tooltip: 'Filter',
                ),
              ],
            ],
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
