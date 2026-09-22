import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_pool/components/buttons/app_primary_button.dart';
import 'package:campus_pool/models/user_model.dart';
import 'package:campus_pool/screens/profile/edit_profile_screen.dart';
import 'package:campus_pool/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'usr_123',
    name: 'Aditi Rao',
    email: 'aditi.rao@campus.edu',
    phone: '9876543210',
    college: 'VIT Pune',
    rollNumber: '23BCE2048',
    gender: 'female',
    emergencyName: 'Rajesh Rao',
    emergencyPhone: '9123456780',
    emergencyRelation: 'Father',
    roles: const ['rider', 'driver'],
    ratingAvg: 4.8,
  );

  group('UserModel Profile & Emergency Contact Tests', () {
    test('JSON serialization preserves emergency contact fields', () {
      final json = testUser.toJson();
      expect(json['emergencyName'], 'Rajesh Rao');
      expect(json['emergencyPhone'], '9123456780');
      expect(json['emergencyRelation'], 'Father');

      final deserialized = UserModel.fromJson(json);
      expect(deserialized.name, 'Aditi Rao');
      expect(deserialized.emergencyName, 'Rajesh Rao');
      expect(deserialized.emergencyPhone, '9123456780');
      expect(deserialized.emergencyRelation, 'Father');
    });

    test('copyWith updates emergency contact and profile fields', () {
      final updated = testUser.copyWith(
        name: 'Aditi Sharma',
        emergencyName: 'Pooja Rao',
        emergencyRelation: 'Mother',
      );
      expect(updated.name, 'Aditi Sharma');
      expect(updated.emergencyName, 'Pooja Rao');
      expect(updated.emergencyRelation, 'Mother');
      expect(updated.email, 'aditi.rao@campus.edu');
    });
  });

  group('EditProfileScreen Widget Tests', () {
    testWidgets('Populates initial values from user model', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(user: testUser),
        ),
      );

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Aditi Rao'), findsOneWidget);
      expect(find.text('aditi.rao@campus.edu'), findsOneWidget);
      expect(find.text('23BCE2048'), findsOneWidget);
      expect(find.text('VIT Pune'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Rajesh Rao'), findsOneWidget);
      expect(find.text('9123456780'), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
    });

    testWidgets('Validates required fields when emptied', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(user: testUser),
        ),
      );

      // Clear the name field
      final nameFinder = find.widgetWithText(TextFormField, 'Aditi Rao');
      await tester.enterText(nameFinder, '');

      // Tap Save Changes button
      final saveButtonFinder = find.widgetWithText(AppPrimaryButton, 'Save Changes');
      await tester.tap(saveButtonFinder);
      await tester.pump();

      // Expect validation error
      expect(find.text('Full name is required'), findsOneWidget);
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders student profile with Edit Profile buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(initialUser: testUser),
        ),
      );

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Aditi Rao'), findsOneWidget);
      expect(find.text('Student Information'), findsOneWidget);
      expect(find.text('Emergency Contact & Safety'), findsOneWidget);
      expect(find.text('Rajesh Rao'), findsOneWidget);
      expect(find.text('Edit Profile Information'), findsOneWidget);
    });
  });
}
