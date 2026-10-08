import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'better_auth_token';
  static const String _userKey = 'better_auth_user';

  final Dio _dio;
  String baseUrl;

  String? _token;
  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  AuthService({
    required String defaultBaseUrl,
    Dio? dio,
  })  : baseUrl = defaultBaseUrl,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: defaultBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'X-Client-Platform': 'Flutter-Mobile',
                },
              ),
            );

  String? get token => _token;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
    notifyListeners();
  }

  /// Load persisted session from local device storage on app startup
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);

      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }

      // If we have a token, optionally verify session in the background
      if (_token != null) {
        _verifySessionInBackground();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Better Auth: POST /api/auth/sign-in/email
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.post(
        '/api/auth/sign-in/email',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      // Extract token from body, set-auth-token header, or session cookie
      String? extractedToken;
      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (data['token'] != null) {
          extractedToken = data['token'].toString();
        } else if (data['session'] != null && data['session']['token'] != null) {
          extractedToken = data['session']['token'].toString();
        }
      }

      // Check Better Auth 'set-auth-token' header
      if (extractedToken == null || extractedToken.isEmpty) {
        final headerToken = response.headers.value('set-auth-token');
        if (headerToken != null && headerToken.isNotEmpty) {
          extractedToken = headerToken;
        }
      }

      // Check cookie headers
      if (extractedToken == null || extractedToken.isEmpty) {
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (final cookie in cookies) {
            if (cookie.contains('better-auth.session_token=')) {
              final match = RegExp(r'better-auth\.session_token=([^;]+)').firstMatch(cookie);
              if (match != null) {
                extractedToken = match.group(1);
                break;
              }
            }
          }
        }
      }

      if (extractedToken == null || extractedToken.isEmpty) {
        throw Exception('Impossible d\'extraire le jeton de session Better Auth');
      }

      // Extract user
      AppUser user;
      if (data is Map<String, dynamic> && data['user'] != null) {
        user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        user = AppUser(
          id: 'user_1',
          name: email.split('@').first,
          email: email,
        );
      }

      _token = extractedToken;
      _currentUser = user;

      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, extractedToken);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      final msg = e.response?.data?['message'] ?? e.message ?? 'Erreur d\'authentification';
      throw Exception(msg);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Better Auth: GET /api/auth/get-session
  Future<void> _verifySessionInBackground() async {
    if (_token == null) return;
    try {
      final response = await _dio.get(
        '/api/auth/get-session',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
            'Cookie': 'better-auth.session_token=$_token',
          },
        ),
      );

      if (response.data != null && response.data['user'] != null) {
        _currentUser = AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Background session check failed (possibly offline): $e');
      // If offline, keep local session so representative can work in interior Wilayas
    }
  }

  /// Better Auth: POST /api/auth/sign-out
  Future<void> signOut() async {
    try {
      if (_token != null) {
        await _dio.post(
          '/api/auth/sign-out',
          options: Options(
            headers: {
              'Authorization': 'Bearer $_token',
              'Cookie': 'better-auth.session_token=$_token',
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Server sign out error: $e');
    } finally {
      await handleSessionExpired();
    }
  }

  /// Clear credentials when token expired or user signs out
  Future<void> handleSessionExpired() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
