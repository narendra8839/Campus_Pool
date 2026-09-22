import 'package:flutter/material.dart';

/// Shared navigation state used when an authenticated API request expires.
///
/// Keeping this outside individual screens lets API failures redirect exactly
/// once, even when several requests fail at the same time.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static String _returnRoute = '/home';

  static String get returnRoute => _returnRoute;

  /// Records the last protected, named destination a user was viewing.
  static void recordProtectedRoute(String routeName) {
    _returnRoute = routeName;
  }
}

/// Arguments supplied when authentication redirects a user to login.
class LoginRouteArguments {
  const LoginRouteArguments({required this.returnRoute, this.sessionExpired = false});

  final String returnRoute;
  final bool sessionExpired;
}
