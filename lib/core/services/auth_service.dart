import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../db/local_db.dart';

class AuthService extends ChangeNotifier {
  final ApiClient api;
  final _secure = const FlutterSecureStorage();

  User? _user;
  String? _token;
  String? _serverUrl;
  bool _loading = true;

  AuthService(this.api);

  User? get user => _user;
  String? get token => _token;
  String? get serverUrl => _serverUrl;
  bool get isLoggedIn => _token != null && _user != null;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString('server_url');
      _token = await _secure.read(key: 'token');
      final userJson = await _secure.read(key: 'user');

      if (_serverUrl != null && _serverUrl!.isNotEmpty) {
        api.configure(_serverUrl!, token: _token);
      }

      if (_token != null && userJson != null) {
        _user = User.fromJson(jsonDecode(userJson));
        // Try to validate token quietly (if online)
        try {
          final me = await api.call('auth.me');
          if (me is Map) {
            _user = User.fromJson(Map<String, dynamic>.from(me));
            await _secure.write(key: 'user', value: jsonEncode(_user!.toJson()));
          }
        } catch (_) {
          // offline or invalid — keep cached user for offline mode
        }
      }
    } catch (e) {
      if (kDebugMode) print('Auth init error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) throw Exception('اكتب عنوان السيرفر');
    _serverUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', clean);
    api.configure(clean, token: _token);
    notifyListeners();
  }

  Future<User> login(String username, String password) async {
    if (!api.isConfigured) {
      throw ApiException('حدد عنوان السيرفر الأول من الإعدادات');
    }
    final result = await api.call('auth.login', {
      'username': username.trim(),
      'password': password,
    });

    if (result is! Map) throw ApiException('رد غير متوقع من السيرفر');

    _token = result['token']?.toString();
    final userMap = result['user'];
    if (_token == null || userMap is! Map) {
      throw ApiException('فشل تسجيل الدخول');
    }

    _user = User.fromJson(Map<String, dynamic>.from(userMap));
    api.setToken(_token);

    await _secure.write(key: 'token', value: _token);
    await _secure.write(key: 'user', value: jsonEncode(_user!.toJson()));

    notifyListeners();
    return _user!;
  }

  Future<void> logout({bool remote = true}) async {
    if (remote && api.isConfigured && _token != null) {
      try {
        await api.call('auth.logout');
      } catch (_) {}
    }
    _token = null;
    _user = null;
    api.setToken(null);
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'user');
    notifyListeners();
  }

  /// Clear everything including server URL and offline data
  Future<void> fullReset() async {
    await logout(remote: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_url');
    _serverUrl = null;
    api.clear();
    await LocalDb.clearCache();
    notifyListeners();
  }
}
