import 'package:flutter/material.dart';

/// Campus Pool Design System Color Palette
/// Extracted from Stitch design specifications for CampusFlow MVP Mobile UI.
abstract final class AppColors {
  // Primary (Campus Blue)
  static const Color primary = Color(0xFF0058BE);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF004395);
  static const Color primaryContainer = Color(0xFF2170E4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFEFCFF);
  static const Color primaryFixed = Color(0xFFD8E2FF);
  static const Color primaryFixedDim = Color(0xFFADC6FF);
  static const Color primaryTint = Color(0xFFEFF6FF);

  // Secondary (Transit Teal)
  static const Color secondary = Color(0xFF006C49);
  static const Color secondaryLight = Color(0xFF10B981);
  static const Color secondaryContainer = Color(0xFF6CF8BB);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF00714D);
  static const Color secondaryFixed = Color(0xFF6FFBBE);
  static const Color secondaryFixedDim = Color(0xFF4EDEA3);
  static const Color secondaryTint = Color(0xFFECFDF5);

  // Tertiary / Warning (Transit Amber)
  static const Color tertiary = Color(0xFF825100);
  static const Color tertiaryLight = Color(0xFFF59E0B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color tertiaryContainer = Color(0xFFFFDDB8);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF2A1700);
  static const Color warningTint = Color(0xFFFFFBEB);

  // Error (Critical Red)
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color errorTint = Color(0xFFFEF2F2);

  // Canvas & Surfaces
  static const Color background = Color(0xFFF9F9FF);
  static const Color onBackground = Color(0xFF151C27);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF151C27);
  static const Color onSurfaceVariant = Color(0xFF424754);
  static const Color surfaceDim = Color(0xFFD3DAEA);
  static const Color surfaceBright = Color(0xFFF9F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainer = Color(0xFFE7EEFE);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F8);
  static const Color surfaceContainerHighest = Color(0xFFDCE2F3);

  // Neutral / Outlines / Borders
  static const Color outline = Color(0xFF727785);
  static const Color outlineVariant = Color(0xFFC2C6D6);
  static const Color border = Color(0xFFE2E8F8);
  static const Color borderSubtle = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFF0F3FF);
  static const Color disabled = Color(0xFF9CA3AF);
  static const Color disabledContainer = Color(0xFFE5E7EB);
}
