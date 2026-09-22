import 'package:flutter/material.dart';
import '../../components/navigation/app_bottom_nav_bar.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';
import '../alerts/alerts_screen.dart';
import '../home/home_dashboard_screen.dart';
import '../offer_ride_screen.dart';
import '../profile/profile_screen.dart';
import '../rides/my_rides_screen.dart';

/// Main navigation shell hosting persistent bottom navigation bar across core app routes
/// Preserves state across tabs via IndexedStack
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  /// Helper to programmatically switch tabs from any descendant widget
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationShellState>();
    if (state != null) {
      state.setTabIndex(index);
    }
  }

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _recordCurrentRoute();
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex.clamp(0, 4);
    }
  }

  void setTabIndex(int index) {
    if (index >= 0 && index < 5 && _currentIndex != index) {
      setState(() => _currentIndex = index);
      _recordCurrentRoute();
    }
  }

  void _recordCurrentRoute() {
    const routes = [
      AppRoutes.home,
      AppRoutes.rides,
      AppRoutes.offer,
      AppRoutes.alerts,
      AppRoutes.profile,
    ];
    AppNavigator.recordProtectedRoute(routes[_currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeDashboardScreen(embeddedInShell: true),
            MyRidesScreen(),
            OfferRideScreen(embeddedInShell: true),
            AlertsScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentIndex,
          onTap: setTabIndex,
          items: const [
            AppNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
            AppNavItem(
              icon: Icons.two_wheeler_outlined,
              selectedIcon: Icons.two_wheeler_rounded,
              label: 'Rides',
            ),
            AppNavItem(
              icon: Icons.add_circle_outline_rounded,
              selectedIcon: Icons.add_circle_rounded,
              label: 'Offer',
            ),
            AppNavItem(
              icon: Icons.notifications_none_rounded,
              selectedIcon: Icons.notifications_rounded,
              label: 'Alerts',
            ),
            AppNavItem(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
