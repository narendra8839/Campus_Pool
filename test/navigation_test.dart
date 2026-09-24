import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_pool/components/navigation/app_bottom_nav_bar.dart';
import 'package:campus_pool/routes/app_routes.dart';
import 'package:campus_pool/screens/navigation/main_navigation_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRoutes tests', () {
    test('Route constants are defined', () {
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.rides, '/rides');
      expect(AppRoutes.offer, '/offer');
      expect(AppRoutes.alerts, '/alerts');
      expect(AppRoutes.profile, '/profile');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.register, '/register');
    });

    test('routes table contains core destinations', () {
      final routes = AppRoutes.routes;
      expect(routes.containsKey(AppRoutes.home), isTrue);
      expect(routes.containsKey(AppRoutes.rides), isTrue);
      expect(routes.containsKey(AppRoutes.offer), isTrue);
      expect(routes.containsKey(AppRoutes.alerts), isTrue);
      expect(routes.containsKey(AppRoutes.profile), isTrue);
      expect(routes.containsKey(AppRoutes.login), isTrue);
      expect(routes.containsKey(AppRoutes.register), isTrue);
    });
  });

  group('MainNavigationShell widget tests', () {
    testWidgets('Renders all 5 bottom navigation items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(initialIndex: 0),
        ),
      );

      // Verify bottom nav bar is rendered
      expect(find.byType(AppBottomNavBar), findsOneWidget);

      // Verify all 5 tab labels exist
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Rides'), findsOneWidget);
      expect(find.text('Offer'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Loads directly with initialIndex for specific tab (Profile)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(initialIndex: 4),
        ),
      );

      // Verify Profile screen is the visible item in the stack
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);

      final IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 4);
    });

    testWidgets('Tapping bottom nav tab switches the active tab',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(initialIndex: 0),
        ),
      );

      final indexedStackFinder = find.byType(IndexedStack);
      IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      // Tap 'Profile' tab
      await tester.tap(find.text('Profile'));
      await tester.pump();

      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 4);

      // Tap 'Rides' tab
      await tester.tap(find.text('Rides'));
      await tester.pump();

      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 1);
    });
  });
}
