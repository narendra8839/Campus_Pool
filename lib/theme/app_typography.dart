import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Campus Pool Typography System using Inter font
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  // Base TextStyle helper using GoogleFonts.inter
  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double? letterSpacing,
    Color color = AppColors.onSurface,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height != null ? height / fontSize : null,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // Headline Styles
  static TextStyle get headlineLg => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40,
        letterSpacing: -0.64, // -0.02em
      );

  static TextStyle get headlineLgMobile => _inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32,
        letterSpacing: -0.24, // -0.01em
      );

  static TextStyle get headlineMd => _inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28,
      );

  static TextStyle get headlineSm => _inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24,
      );

  // Body Styles
  static TextStyle get bodyLg => _inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28,
      );

  static TextStyle get bodyMd => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24,
      );

  static TextStyle get bodySm => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20,
        color: AppColors.onSurfaceVariant,
      );

  // Label / Action Styles
  static TextStyle get labelLg => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 20,
      );

  static TextStyle get labelMd => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 16,
        letterSpacing: 0.14, // 0.01em
      );

  static TextStyle get labelSm => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 14,
      );

  static TextStyle get caption => _inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14,
        color: AppColors.onSurfaceVariant,
      );

  // Material 3 TextTheme Generator
  static TextTheme createTextTheme([Color defaultColor = AppColors.onSurface]) {
    return TextTheme(
      displayLarge: headlineLg.copyWith(color: defaultColor),
      displayMedium: headlineLgMobile.copyWith(color: defaultColor),
      displaySmall: headlineMd.copyWith(color: defaultColor),
      headlineLarge: headlineLgMobile.copyWith(color: defaultColor),
      headlineMedium: headlineMd.copyWith(color: defaultColor),
      headlineSmall: headlineSm.copyWith(color: defaultColor),
      titleLarge: headlineMd.copyWith(color: defaultColor),
      titleMedium: headlineSm.copyWith(color: defaultColor),
      titleSmall: labelLg.copyWith(color: defaultColor),
      bodyLarge: bodyLg.copyWith(color: defaultColor),
      bodyMedium: bodyMd.copyWith(color: defaultColor),
      bodySmall: bodySm.copyWith(color: AppColors.onSurfaceVariant),
      labelLarge: labelLg.copyWith(color: defaultColor),
      labelMedium: labelMd.copyWith(color: defaultColor),
      labelSmall: labelSm.copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}
