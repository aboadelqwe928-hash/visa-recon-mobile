import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'auth_service.dart';

/// بيانات الشاشة الرئيسية (أمر m.home في البرنامج 2.8.0 أو أحدث).
/// آخر رد بيتحفظ على الموبايل، فالرئيسية بتفتح حتى لو الكمبيوتر مش متاح.
class HomeService extends ChangeNotifier {
  final ApiClient api;
  final AuthService auth;
  HomeService(this.api, this.auth);

  Map<String, dynamic>? data;
  DateTime? at;
  bool loading = false;
  bool fromCache = false;
  String? error;

  /// البرنامج على الكمبيوتر أقدم من 2.8.0 (مفيهوش m.home)
  bool oldServer = false;

  String get _key => 'home_cache_${auth.user?.username ?? ''}';

  Future<void> init() async {
    // مستخدم جديد: ما نعرضش بيانات اللي قبله
    data = null;
    at = null;
    error = null;
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_key);
      if (s != null) {
        final j = jsonDecode(s);
        if (j is Map && j['data'] is Map) {
          data = Map<String, dynamic>.from(j['data'] as Map);
          at = DateTime.tryParse('${j['at']}');
          fromCache = true;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refresh({String? day}) async {
    if (loading) return;
    if (!auth.isLoggedIn) return;
    loading = true;
    notifyListeners();
    try {
      final r = await api.call('m.home', day == null ? {} : {'day': day});
      if (r is Map) {
        data = Map<String, dynamic>.from(r);
        at = DateTime.now();
        fromCache = false;
        error = null;
        oldServer = false;
        final p = await SharedPreferences.getInstance();
        await p.setString(_key, jsonEncode({'at': at!.toIso8601String(), 'data': data}));
      }
    } on ApiException catch (e) {
      error = e.message;
      oldServer = e.message.contains('أمر غير معروف');
      fromCache = data != null;
    } catch (e) {
      error = '$e';
      fromCache = data != null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    data = null;
    at = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
    notifyListeners();
  }
}
