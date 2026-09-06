import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const String _userKey = 'auth_current_user';
  static UserModel? _cachedUser;

  /// Get in-memory or stored user profile
  static UserModel? get cachedUser => _cachedUser;

  /// Check if user has an active session token
  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Load session from local storage on app start
  static Future<UserModel?> loadSession() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      _cachedUser = null;
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(userJson);
        _cachedUser = UserModel.fromJson(data, token: token);
        return _cachedUser;
      } catch (_) {
        // Fall back to server refresh
      }
    }

    // Try fetching fresh profile from backend
    try {
      final user = await getMe();
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Login with email and password
  static Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    if (response is Map && response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';

      if (token.isNotEmpty) {
        await ApiService.saveToken(token);
      }

      final user = UserModel.fromJson(data, token: token);
      await _saveLocalUser(user);
      _cachedUser = user;
      return user;
    }

    throw ApiException('Login response was invalid.');
  }

  /// Register a new student user
  static Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String college = '',
    String rollNumber = '',
    String gender = 'prefer_not_to_say',
    List<String> roles = const ['rider'],
    VehicleModel? vehicle,
  }) async {
    final Map<String, dynamic> body = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'phone': phone.trim(),
      'college': college.trim(),
      'rollNumber': rollNumber.trim(),
      'gender': gender,
      'roles': roles,
    };

    if (vehicle != null && (roles.contains('driver') || roles.contains('both'))) {
      body['vehicle'] = vehicle.toJson();
    }

    final response = await ApiService.post('/auth/register', body: body);

    if (response is Map && response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';

      if (token.isNotEmpty) {
        await ApiService.saveToken(token);
      }

      final user = UserModel.fromJson(data, token: token);
      await _saveLocalUser(user);
      _cachedUser = user;
      return user;
    }

    throw ApiException('Registration response was invalid.');
  }

  /// Fetch currently authenticated user profile from backend
  static Future<UserModel> getMe() async {
    final response = await ApiService.get('/auth/me', requiresAuth: true);

    if (response is Map && response['success'] == true && response['data'] != null) {
      final token = await ApiService.getToken();
      final data = response['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data, token: token);
      await _saveLocalUser(user);
      _cachedUser = user;
      return user;
    }

    throw ApiException('Failed to retrieve user profile.');
  }

  /// Logout and clear stored credentials
  static Future<void> logout() async {
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _cachedUser = null;
  }

  /// Cache user JSON locally
  static Future<void> _saveLocalUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }
}
