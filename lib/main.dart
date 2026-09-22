import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'models/user_model.dart';
import 'routes/app_navigator.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/navigation/main_navigation_shell.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hybrid composition avoids blank/black native map views on some Android
  // devices and MIUI emulator images.
  MapLibreMap.useHybridComposition = true;
  ApiService.onUnauthorized = _handleExpiredSession;
  runApp(const CampusPoolApp());
}

Future<void> _handleExpiredSession() async {
  await AuthService.logout();

  final navigator = AppNavigator.key.currentState;
  if (navigator == null) return;

  navigator.pushNamedAndRemoveUntil(
    AppRoutes.login,
    (route) => false,
    arguments: LoginRouteArguments(
      returnRoute: AppNavigator.returnRoute,
      sessionExpired: true,
    ),
  );
}

class CampusPoolApp extends StatelessWidget {
  const CampusPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Pool',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

/// Gatekeeper widget to determine whether to show Login or HomeDashboard on startup
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<UserModel?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = AuthService.loadSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return const MainNavigationShell(initialIndex: 0);
        }

        return const LoginScreen();
      },
    );
  }
}
