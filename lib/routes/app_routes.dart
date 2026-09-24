import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auto_groups/auto_groups_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/find_rides_screen.dart';
import '../screens/navigation/main_navigation_shell.dart';
import '../screens/profile/edit_profile_screen.dart';

/// Central route definitions for Campus Pool application
class AppRoutes {
  static const String home = '/home';
  static const String rides = '/rides';
  static const String offer = '/offer';
  static const String alerts = '/alerts';
  static const String map = '/map';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String login = '/login';
  static const String register = '/register';
  static const String findRides = '/find-rides';
  static const String autoGroups = '/auto-groups';

  /// Named routes table
  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const MainNavigationShell(initialIndex: 0),
        rides: (context) => const MainNavigationShell(initialIndex: 1),
        offer: (context) => const MainNavigationShell(initialIndex: 2),
        alerts: (context) => const AlertsScreen(),
        map: (context) => const MainNavigationShell(initialIndex: 3),
        profile: (context) => const MainNavigationShell(initialIndex: 4),
        login: (context) => const LoginScreen(),
        register: (context) => const RegistrationScreen(),
        findRides: (context) => const FindRidesScreen(),
        autoGroups: (context) => const AutoGroupsScreen(),
      };

  /// Optional route generator for handling dynamic arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationShell(initialIndex: 0),
          settings: settings,
        );
      case rides:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationShell(initialIndex: 1),
          settings: settings,
        );
      case offer:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationShell(initialIndex: 2),
          settings: settings,
        );
      case alerts:
        return MaterialPageRoute(
          builder: (_) => const AlertsScreen(),
          settings: settings,
        );
      case map:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationShell(initialIndex: 3),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationShell(initialIndex: 4),
          settings: settings,
        );
      case editProfile:
        final user = settings.arguments as UserModel?;
        if (user != null) {
          return MaterialPageRoute(
            builder: (_) => EditProfileScreen(user: user),
            settings: settings,
          );
        }
        return null;
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case register:
        return MaterialPageRoute(
          builder: (_) => const RegistrationScreen(),
          settings: settings,
        );
      case findRides:
        return MaterialPageRoute(
          builder: (_) => const FindRidesScreen(),
          settings: settings,
        );
      case autoGroups:
        return MaterialPageRoute(
          builder: (_) => const AutoGroupsScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
