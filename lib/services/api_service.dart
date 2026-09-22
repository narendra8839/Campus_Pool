import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String _tokenKey = 'auth_jwt_token';
  static String? _workingBaseUrl;
  static Future<void> Function()? onUnauthorized;
  static bool _unauthorizedHandled = false;

  /// Candidate base URLs in order of preference
  static List<String> get _candidateBaseUrls {
    final envVar = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final List<String> urls = <String>[];
    if (envVar.isNotEmpty) {
      urls.add(envVar);
    }

    // Add fallback URLs, avoiding duplicates
    final List<String> fallback = _getFallbackBaseUrls();
    for (final url in fallback) {
      if (!urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  static List<String> _getFallbackBaseUrls() {
    if (kIsWeb) {
      return ['http://localhost:5000/api'];
    }

    try {
      if (Platform.isAndroid) {
        return [
          'http://localhost:5000/api', // Physical device with adb reverse
          'http://10.0.2.2:5000/api', // Android Studio Emulator
          'http://10.82.163.170:5000/api', // Host machine Wi-Fi LAN IP
        ];
      }
    } catch (_) {
      // Ignore
    }

    return [
      'http://localhost:5000/api',
      'http://127.0.0.1:5000/api',
      'http://10.82.163.170:5000/api',
    ];
  }

  /// Current base API URL
  static String get baseUrl => _workingBaseUrl ?? _candidateBaseUrls.first;

  /// Get stored JWT token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Save JWT token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    // A fresh login starts a new session, so a future expiry must be handled.
    _unauthorizedHandled = false;
  }

  /// Clear stored JWT token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Default headers with optional JWT authorization
  static Future<Map<String, String>> _headers({
    bool requiresAuth = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Generic POST request with automatic candidate URL fallback
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final headers = await _headers(requiresAuth: requiresAuth);
    final urls = _workingBaseUrl != null
        ? [
            _workingBaseUrl!,
            ..._candidateBaseUrls.where((u) => u != _workingBaseUrl),
          ]
        : _candidateBaseUrls;

    ApiException? lastApiException;

    for (final base in urls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final response = await http
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 8));

        _workingBaseUrl = base;
        return await _handleResponse(response, requiresAuth: requiresAuth);
      } catch (e) {
        if (e is ApiException) {
          // If server returned a 4xx / 5xx error, server is reachable! Don't try other hosts.
          rethrow;
        }
        // SocketException / Timeout / connection refused -> try next candidate URL
        lastApiException = ApiException(
          'Unable to connect to server. Please check your network or ensure backend is running.',
        );
      }
    }

    throw lastApiException ?? ApiException('Unable to connect to server.');
  }

  /// Generic GET request with automatic candidate URL fallback
  static Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final headers = await _headers(requiresAuth: requiresAuth);
    final urls = _workingBaseUrl != null
        ? [
            _workingBaseUrl!,
            ..._candidateBaseUrls.where((u) => u != _workingBaseUrl),
          ]
        : _candidateBaseUrls;

    ApiException? lastApiException;

    for (final base in urls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));

        _workingBaseUrl = base;
        return await _handleResponse(response, requiresAuth: requiresAuth);
      } catch (e) {
        if (e is ApiException) {
          rethrow;
        }
        lastApiException = ApiException(
          'Unable to connect to server. Please check your network or ensure backend is running.',
        );
      }
    }

    throw lastApiException ?? ApiException('Unable to connect to server.');
  }

  /// Generic PATCH request with automatic candidate URL fallback.
  static Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final headers = await _headers(requiresAuth: requiresAuth);
    final urls = _workingBaseUrl != null
        ? [
            _workingBaseUrl!,
            ..._candidateBaseUrls.where((u) => u != _workingBaseUrl),
          ]
        : _candidateBaseUrls;

    ApiException? lastApiException;
    for (final base in urls) {
      try {
        final response = await http
            .patch(
              Uri.parse('$base$endpoint'),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 8));
        _workingBaseUrl = base;
        return await _handleResponse(response, requiresAuth: requiresAuth);
      } catch (e) {
        if (e is ApiException) rethrow;
        lastApiException = ApiException(
          'Unable to connect to server. Please check your network or ensure backend is running.',
        );
      }
    }
    throw lastApiException ?? ApiException('Unable to connect to server.');
  }

  /// Generic PUT request with automatic candidate URL fallback.
  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final headers = await _headers(requiresAuth: requiresAuth);
    final urls = _workingBaseUrl != null
        ? [
            _workingBaseUrl!,
            ..._candidateBaseUrls.where((u) => u != _workingBaseUrl),
          ]
        : _candidateBaseUrls;

    ApiException? lastApiException;
    for (final base in urls) {
      try {
        final response = await http
            .put(
              Uri.parse('$base$endpoint'),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 8));
        _workingBaseUrl = base;
        return await _handleResponse(response, requiresAuth: requiresAuth);
      } catch (e) {
        if (e is ApiException) rethrow;
        lastApiException = ApiException(
          'Unable to connect to server. Please check your network or ensure backend is running.',
        );
      }
    }
    throw lastApiException ?? ApiException('Unable to connect to server.');
  }

  /// Generic DELETE request with automatic candidate URL fallback.
  static Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final headers = await _headers(requiresAuth: requiresAuth);
    final urls = _workingBaseUrl != null
        ? [
            _workingBaseUrl!,
            ..._candidateBaseUrls.where((u) => u != _workingBaseUrl),
          ]
        : _candidateBaseUrls;

    ApiException? lastApiException;
    for (final base in urls) {
      try {
        final response = await http
            .delete(Uri.parse('$base$endpoint'), headers: headers)
            .timeout(const Duration(seconds: 8));
        _workingBaseUrl = base;
        return await _handleResponse(response, requiresAuth: requiresAuth);
      } catch (e) {
        if (e is ApiException) rethrow;
        lastApiException = ApiException(
          'Unable to connect to server. Please check your network or ensure backend is running.',
        );
      }
    }
    throw lastApiException ?? ApiException('Unable to connect to server.');
  }

  /// Process HTTP Response and extract JSON data or error messages
  static Future<dynamic> _handleResponse(
    http.Response response, {
    required bool requiresAuth,
  }) async {
    dynamic responseData;
    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      responseData = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    final message = (responseData is Map && responseData['message'] != null)
        ? responseData['message']
        : 'Request failed with status code ${response.statusCode}';

    if (response.statusCode == 401 && requiresAuth) {
      await _handleUnauthorized();
    }

    throw ApiException(message.toString(), statusCode: response.statusCode);
  }

  static Future<void> _handleUnauthorized() async {
    // Multiple in-flight requests can all receive a 401. Only the first one
    // should clear the session and redirect the user.
    if (_unauthorizedHandled) return;
    _unauthorizedHandled = true;
    await onUnauthorized?.call();
  }
}
