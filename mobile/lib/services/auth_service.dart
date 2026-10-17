import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  static String? _cachedToken;
  static String? _cachedUserId;
  static String? _cachedUsername;

  static String? get token => _cachedToken;
  static String? get userId => _cachedUserId;
  static String? get username => _cachedUsername;
  static bool get isAuthenticated => _cachedToken != null;

  /// Carrega o token salvo do armazenamento local
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedUserId = prefs.getString(_userIdKey);
    _cachedUsername = prefs.getString(_usernameKey);
  }

  /// Garante que o app tenha um token válido gerando uma sessão Guest rápida se necessário
  static Future<void> ensureAuthenticated() async {
    if (isAuthenticated) return;

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/guest');
      final res = await http.post(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveSession(
          token: data['access_token'],
          userId: data['user_id'],
          username: data['username'],
        );
      }
    } catch (e) {
      // Falha de rede inicial: segue em frente e tenta nas requisições
    }
  }

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String username,
  }) async {
    _cachedToken = token;
    _cachedUserId = userId;
    _cachedUsername = username;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
  }

  static Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUserId = null;
    _cachedUsername = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
