import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models/user_model.dart';

/// Unified Authentication Service connecting to the KeyFlow Express backend.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService();

  AuthService({
    String? apiBase,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : _apiBase = apiBase ?? _defaultApiBase,
        _client = httpClient ?? http.Client(),
        _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _defaultApiBase =
      'https://keyflow-dnsd.onrender.com/api/v1';
  static const String _tokenKey = 'keyflow_jwt_token';
  static const String _userKey = 'keyflow_user_data';

  final String _apiBase;
  final http.Client _client;
  final FlutterSecureStorage _storage;

  String? _token;
  UserModel? _currentUser;
  bool _isInitialized = false;

  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isInitialized => _isInitialized;

  /// Restores persisted session from secure storage on app launch.
  Future<bool> initialize() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      final rawUser = await _storage.read(key: _userKey);

      if (rawUser != null && rawUser.isNotEmpty) {
        _currentUser = UserModel.fromJson(
          jsonDecode(rawUser) as Map<String, dynamic>,
        );
      }

      if (_token != null && _token!.isNotEmpty) {
        // Validate token with backend in background
        await fetchProfile();
      }
    } catch (e) {
      debugPrint('AuthService initialize error: $e');
      _token = null;
      _currentUser = null;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
    return isAuthenticated;
  }

  /// Sign in with email and password against the unified backend.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$_apiBase/auth/login');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final tokenStr = data['token'] as String? ?? '';
        final userObj = data['user'] != null
            ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
            : null;

        _token = tokenStr;
        _currentUser = userObj;

        await _storage.write(key: _tokenKey, value: tokenStr);
        if (userObj != null) {
          await _storage.write(key: _userKey, value: jsonEncode(userObj.toJson()));
        }

        notifyListeners();
        return AuthResponse(success: true, token: tokenStr, user: userObj);
      } else {
        final errorMsg = (data['error'] ?? data['message'] ?? 'Login failed').toString();
        return AuthResponse(success: false, errorMessage: errorMsg);
      }
    } on SocketException catch (_) {
      return const AuthResponse(
        success: false,
        errorMessage: 'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Register a new account against the unified backend.
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    String? organizationName,
  }) async {
    try {
      final url = Uri.parse('$_apiBase/auth/register');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'fullName': fullName.trim(),
          'organizationName': organizationName ?? 'Look Enterprise Org',
          'role': 'member',
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 || (response.statusCode >= 200 && response.statusCode < 300)) {
        final tokenStr = data['token'] as String? ?? '';
        final userObj = data['user'] != null
            ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
            : null;

        _token = tokenStr;
        _currentUser = userObj;

        await _storage.write(key: _tokenKey, value: tokenStr);
        if (userObj != null) {
          await _storage.write(key: _userKey, value: jsonEncode(userObj.toJson()));
        }

        notifyListeners();
        return AuthResponse(success: true, token: tokenStr, user: userObj);
      } else {
        final errorMsg = (data['error'] ?? data['message'] ?? 'Registration failed').toString();
        return AuthResponse(success: false, errorMessage: errorMsg);
      }
    } on SocketException catch (_) {
      return const AuthResponse(
        success: false,
        errorMessage: 'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Fetch latest user profile from GET /auth/me
  Future<UserModel?> fetchProfile() async {
    if (_token == null || _token!.isEmpty) return null;

    try {
      final url = Uri.parse('$_apiBase/auth/me');
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['user'] != null) {
          _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await _storage.write(key: _userKey, value: jsonEncode(_currentUser!.toJson()));
          notifyListeners();
          return _currentUser;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expired or invalid
        await logout();
      }
    } catch (e) {
      debugPrint('AuthService fetchProfile error: $e');
    }
    return null;
  }

  /// Sign out and clear stored tokens.
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
    notifyListeners();
  }
}
