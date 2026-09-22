import 'package:flutter/material.dart';

/// Campus Pool Spacing, Radius, and Dimension Tokens
abstract final class AppSpacing {
  // Base Spacing Scale (4px rhythm)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Layout Specifics
  static const double gutter = 16.0;
  static const double marginMobile = 16.0;
  static const double marginDesktop = 40.0;

  // Touch Targets & Heights
  static const double minTouchTarget = 56.0;
  static const double minHitArea = 48.0;
  static const double iconButtonSize = 44.0;
  static const double badgeHeight = 28.0;
  static const double chipHeight = 36.0;

  // Radius Scale
  static const double radiusXsValue = 4.0;
  static const double radiusSmValue = 8.0;
  static const double radiusMdValue = 12.0;
  static const double radiusLgValue = 16.0; // Standard cards & inputs
  static const double radiusXlValue = 24.0; // Sheets & modals
  static const double radiusFullValue = 9999.0; // Pills & chips

  // Predefined BorderRadius
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(radiusXsValue));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(radiusSmValue));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(radiusMdValue));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(radiusLgValue));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(radiusXlValue));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(radiusFullValue));
  
  // Sheet Top Radius
  static const BorderRadius radiusSheetTop = BorderRadius.only(
    topLeft: Radius.circular(radiusXlValue),
    topRight: Radius.circular(radiusXlValue),
  );

  // Common Edge Insets
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: marginMobile, vertical: md);
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets paddingCard = EdgeInsets.all(md);
}
