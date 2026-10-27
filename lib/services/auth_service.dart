import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'api_service.dart';

class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException();

  @override
  String toString() =>
      'Verify your @vit.edu email using the link we sent before logging in.';
}

class AuthService {
  static const String _userKey = 'auth_current_user';
  static const String _pendingProfileKey = 'pending_verified_profile';
  static UserModel? _cachedUser;

  static FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase must be initialized before authentication.');
    }
    return FirebaseAuth.instance;
  }

  static UserModel? get cachedUser => _cachedUser;

  static Future<String?> getIdToken() async =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.getIdToken();

  static bool _isCampusEmail(String email) {
    final parts = email.trim().toLowerCase().split('@');
    return parts.length == 2 &&
        parts.first.isNotEmpty &&
        parts.last == 'vit.edu';
  }

  static Future<bool> isLoggedIn() async =>
      Firebase.apps.isNotEmpty && (_auth.currentUser?.emailVerified ?? false);

  static Future<UserModel?> loadSession() async {
    if (Firebase.apps.isEmpty) return null;
    var firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _cachedUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      return null;
    }

    await firebaseUser.reload();
    firebaseUser = _auth.currentUser;
    if (firebaseUser == null || !firebaseUser.emailVerified) {
      await _auth.signOut();
      _cachedUser = null;
      return null;
    }

    ApiService.resetUnauthorizedState();
    return _provisionBackendProfile(firebaseUser);
  }

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String college = '',
    String rollNumber = '',
    String gender = 'prefer_not_to_say',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isCampusEmail(normalizedEmail)) {
      throw Exception('Only @vit.edu email addresses are allowed.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Firebase did not create an account.');

      await user.updateDisplayName(name.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingProfileKey,
        jsonEncode({
          'email': normalizedEmail,
          'name': name.trim(),
          'phone': phone.trim(),
          'college': college.trim(),
          'rollNumber': rollNumber.trim(),
          'gender': gender,
        }),
      );
      await user.sendEmailVerification();
      await _auth.signOut();
      _cachedUser = null;
    } on FirebaseAuthException catch (error) {
      if (credential?.user != null) await _auth.signOut();
      throw Exception(_firebaseErrorMessage(error));
    } catch (_) {
      if (credential?.user != null) await _auth.signOut();
      rethrow;
    }
  }

  static Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isCampusEmail(normalizedEmail)) {
      throw Exception('Only @vit.edu accounts can use Campus Pool.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Firebase did not return an account.');
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('Could not refresh your Firebase sign-in.');
      }
      if (!refreshedUser.emailVerified) {
        await _auth.signOut();
        await _clearCachedUser();
        throw const EmailVerificationRequiredException();
      }
      ApiService.resetUnauthorizedState();
      return _provisionBackendProfile(refreshedUser);
    } on FirebaseAuthException catch (error) {
      if (credential?.user != null) await _auth.signOut();
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  static Future<void> resendVerificationLink({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isCampusEmail(normalizedEmail)) {
      throw Exception('Only @vit.edu accounts can use Campus Pool.');
    }

    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }

    try {
      final user = credential.user;
      if (user == null) throw Exception('Firebase did not return an account.');
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('Could not refresh your Firebase sign-in.');
      }
      if (refreshedUser.emailVerified) {
        await _auth.signOut();
        throw Exception('Your email is already verified. Please log in.');
      }
      await refreshedUser.sendEmailVerification();
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      await _auth.signOut();
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isCampusEmail(normalizedEmail)) {
      throw Exception('Enter your @vit.edu email address.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  static Future<UserModel> getMe() async {
    final response = await ApiService.get('/auth/me', requiresAuth: true);
    if (response is Map<String, dynamic> &&
        response['success'] == true &&
        response['data'] is Map<String, dynamic>) {
      final user = UserModel.fromJson(
        response['data'] as Map<String, dynamic>,
        token: await getIdToken(),
      );
      await _saveLocalUser(user);
      _cachedUser = user;
      return user;
    }
    throw ApiException('Failed to retrieve your student profile.');
  }

  static Future<UserModel> _provisionBackendProfile(User firebaseUser) async {
    await firebaseUser.getIdToken(true);
    final prefs = await SharedPreferences.getInstance();
    final pendingProfile = prefs.getString(_pendingProfileKey);
    final Map<String, dynamic> pendingData = pendingProfile == null
        ? <String, dynamic>{}
        : jsonDecode(pendingProfile) as Map<String, dynamic>;
    final pendingEmail = pendingData.remove('email');
    final profile = pendingEmail == firebaseUser.email?.toLowerCase()
        ? pendingData
        : <String, dynamic>{};
    final response = await ApiService.post(
      '/auth/profile',
      requiresAuth: true,
      body: profile,
    );
    if (response is! Map<String, dynamic> ||
        response['success'] != true ||
        response['data'] is! Map<String, dynamic>) {
      throw ApiException('The verified account profile could not be loaded.');
    }

    final user = UserModel.fromJson(
      response['data'] as Map<String, dynamic>,
      token: await firebaseUser.getIdToken(),
    );
    await _saveLocalUser(user);
    await prefs.remove(_pendingProfileKey);
    _cachedUser = user;
    return user;
  }

  static Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? college,
    String? rollNumber,
    String? gender,
    String? avatar,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelation,
  }) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name.trim();
    if (phone != null) body['phone'] = phone.trim();
    if (college != null) body['college'] = college.trim();
    if (rollNumber != null) body['rollNumber'] = rollNumber.trim();
    if (gender != null) body['gender'] = gender;
    if (avatar != null) body['avatar'] = avatar;
    if (emergencyName != null) body['emergencyName'] = emergencyName.trim();
    if (emergencyPhone != null) body['emergencyPhone'] = emergencyPhone.trim();
    if (emergencyRelation != null) {
      body['emergencyRelation'] = emergencyRelation.trim();
    }

    final response = await ApiService.put(
      '/users/profile',
      requiresAuth: true,
      body: body,
    );
    if (response is Map<String, dynamic> &&
        response['success'] == true &&
        response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      final mergedJson = {...?_cachedUser?.toJson(), ...data};
      final user = UserModel.fromJson(mergedJson, token: await getIdToken());
      await _saveLocalUser(user);
      _cachedUser = user;
      return user;
    }
    throw ApiException('Failed to update your profile.');
  }

  static Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_pendingProfileKey);
    _cachedUser = null;
  }

  static Future<void> _clearCachedUser() async {
    _cachedUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  static Future<void> _saveLocalUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static String _firebaseErrorMessage(FirebaseAuthException error) {
    if (error.code == 'configuration-not-found' ||
        error.message?.contains('CONFIGURATION_NOT_FOUND') == true) {
      return 'Firebase Authentication is not configured for this app. In '
          'Firebase Console, open project campuspool-afb48, go to '
          'Authentication > Sign-in method, and enable Email/Password. '
          'Confirm the Android app package is com.example.campus_pool, then '
          'rebuild and reinstall the app.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Please log in.';
      case 'invalid-email':
        return 'Enter a valid @vit.edu email address.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'network-request-failed':
        return 'Could not reach Firebase. Check your network and retry.';
      default:
        return error.message ?? 'Firebase authentication failed.';
    }
  }
}
