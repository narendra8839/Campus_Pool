import 'package:flutter/material.dart';

/// Campus Pool Shadow & Elevation Tokens
abstract final class AppShadows {
  // Level 1: Soft diffused shadow for standard cards and list tiles
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0, 0, 0, 0.05)
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  // Level 2: Pronounced shadow for FABs, floating sheets, active cards
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0, 0, 0, 0.10)
      blurRadius: 30,
      spreadRadius: 0,
      offset: Offset(0, 10),
    ),
  ];

  // Level 3: Elevated modals, alert banners, bottom bars
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x24000000), // rgba(0, 0, 0, 0.14)
      blurRadius: 36,
      spreadRadius: 0,
      offset: Offset(0, 12),
    ),
  ];

  // Top shadow for bottom navigation bar
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x0A000000), // rgba(0, 0, 0, 0.04)
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, -4),
    ),
  ];
}
