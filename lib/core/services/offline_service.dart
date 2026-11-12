import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'auth_service.dart';

class BackupFile {
  final File file;
  final DateTime at;
  final int size;
  BackupFile(this.file, this.at, this.size);
}

/// نسخة كاملة من بيانات البرنامج على الموبايل:
/// - offline.html: نفس شاشات البرنامج والمحرك (بيتنزل من الكمبيوتر لما الإصدار يتغير)
/// - data.js: آخر نسخة من قاعدة البيانات (من غير الباسوردات)
/// - backups/: نسخ احتياطية .sqlite تتسترجع على الكمبيوتر من الإعدادات ← استرجاع نسخة
class OfflineService extends ChangeNotifier with WidgetsBindingObserver {
  final ApiClient api;
  final AuthService auth;
  OfflineService(this.api, this.auth);

  Directory? _dir;
  bool _syncing = false;
  String? _error;
  DateTime? _lastSync;
  String? _snapAt;
  String? _serverVersion;
  int _snapSize = 0;
  Timer? _timer;

  // الإعدادات
  bool autoSync = true;
  String backupMode = 'daily'; // every | daily | off
  int keep = 10;

  /// عرض النسخة المحفوظة حتى لو الكمبيوتر متاح (مثلاً لما تفتح نسخة احتياطية قديمة)
  bool forceOffline = false;
  bool viewingBackup = false;
  int reloadTick = 0;

  void reloadSystem({bool? offline}) {
    if (offline != null) forceOffline = offline;
    reloadTick++;
    notifyListeners();
  }

  /// قفل عرض النسخة الاحتياطية والرجوع لآخر مزامنة
  Future<void> closeBackupView() async {
    final d = await dir;
    final live = File('${d.path}/data.live.js');
    if (await live.exists()) await live.rename('${d.path}/data.js');
    final p = await SharedPreferences.getInstance();
    _snapAt = p.getString('off_snap_at');
    viewingBackup = false;
    reloadSystem(offline: false);
  }

  bool get syncing => _syncing;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  String? get snapAt => _snapAt;
  String? get serverVersion => _serverVersion;
  int get snapSize => _snapSize;

  Future<Directory> get dir async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/offline');
    if (!await d.exists()) await d.create(recursive: true);
    final b = Directory('${d.path}/backups');
    if (!await b.exists()) await b.create(recursive: true);
    _dir = d;
    return d;
  }

  Future<String> get htmlPath async => '${(await dir).path}/offline.html';
  /// النسخة المحفوظة لازم تكون بتاعة نفس المستخدم اللي داخل دلوقتي
  Future<bool> get hasOffline async {
    final p = await SharedPreferences.getInstance();
    final owner = p.getString('off_user');
    if (owner == null || owner != auth.user?.username) return false;
    return await File(await htmlPath).exists() && await File('${(await dir).path}/data.js').exists();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    autoSync = p.getBool('off_auto') ?? true;
    backupMode = p.getString('off_backup') ?? 'daily';
    keep = p.getInt('off_keep') ?? 10;
    final ls = p.getInt('off_last');
    _lastSync = ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls);
    _snapAt = p.getString('off_snap_at');
    _serverVersion = p.getString('off_html_ver');
    _snapSize = p.getInt('off_snap_size') ?? 0;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => syncIfDue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncIfDue();
  }

  Future<void> saveSettings({bool? auto, String? mode, int? keepN}) async {
    final p = await SharedPreferences.getInstance();
    if (auto != null) {
      autoSync = auto;
      await p.setBool('off_auto', auto);
    }
    if (mode != null) {
      backupMode = mode;
      await p.setString('off_backup', mode);
    }
    if (keepN != null) {
      keep = keepN;
      await p.setInt('off_keep', keepN);
      await _prune();
    }
    notifyListeners();
  }

  /// مزامنة تلقائية لو فات 10 دقايق على آخر مرة
  Future<void> syncIfDue() async {
    if (!autoSync || viewingBackup || _syncing || !auth.isLoggedIn || !api.isConfigured) return;
    if (_lastSync != null && DateTime.now().difference(_lastSync!) < const Duration(minutes: 10)) return;
    if (!await api.ping()) return;
    await sync(silent: true);
  }

  /// مزامنة كاملة: صفحة البرنامج (لو اتحدثت) + كل البيانات + نسخة احتياطية حسب الإعداد
  Future<bool> sync({bool silent = false, bool forceBackup = false}) async {
    if (_syncing) return false;
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final d = await dir;
      final info = await api.call('sync.info');
      final ver = info is Map ? '${info['version']}' : '';
      final html = File(await htmlPath);
      if (!await html.exists() || ver != _serverVersion) {
        final r = await Dio(BaseOptions(receiveTimeout: const Duration(minutes: 3), responseType: ResponseType.plain))
            .get<String>('${api.baseUrl}/offline.html');
        final body = r.data ?? '';
        if (!body.contains('VROffline')) throw ApiException('برنامج الكمبيوتر محتاج يتحدث لـ 2.6.0 أو أحدث');
        await html.writeAsString(body, flush: true);
        _serverVersion = ver;
      }
      final snap = await api.call('sync.snapshot');
      if (snap is! Map || snap['b64'] == null) throw ApiException('رد غير متوقع من الكمبيوتر');
      final b64 = snap['b64'] as String;
      final at = '${snap['at'] ?? DateTime.now().toIso8601String()}';
      final user = snap['user'] is Map ? Map<String, dynamic>.from(snap['user'] as Map) : <String, dynamic>{};
      await _writeData(d, b64, at, user['username']?.toString() ?? auth.user?.username ?? '');
      _snapAt = at;
      viewingBackup = false;
      try {
        await File('${d.path}/data.live.js').delete();
      } catch (_) {}
      _snapSize = (b64.length * 3) ~/ 4;
      _lastSync = DateTime.now();
      // نسخة احتياطية
      final list = await backups();
      final due = forceBackup ||
          backupMode == 'every' ||
          (backupMode == 'daily' && (list.isEmpty || DateTime.now().difference(list.first.at) > const Duration(hours: 20)));
      if (due && backupMode != 'off' || forceBackup) {
        final t = DateTime.now();
        String two(int x) => x.toString().padLeft(2, '0');
        final name = 'raqaba-${t.year}-${two(t.month)}-${two(t.day)}_${two(t.hour)}-${two(t.minute)}.sqlite';
        await File('${d.path}/backups/$name').writeAsBytes(base64Decode(b64), flush: true);
        await _prune();
      }
      final p = await SharedPreferences.getInstance();
      await p.setInt('off_last', _lastSync!.millisecondsSinceEpoch);
      await p.setString('off_snap_at', at);
      await p.setString('off_html_ver', _serverVersion ?? '');
      await p.setInt('off_snap_size', _snapSize);
      await p.setString('off_user', auth.user?.username ?? '');
      return true;
    } catch (e) {
      _error = '$e'.contains('أمر غير معروف')
          ? 'برنامج الكمبيوتر محتاج يتحدث لـ 2.6.0 أو أحدث'
          : (e is ApiException && e.code == 403)
              ? 'النسخة الأوفلاين مش متاحة لصلاحية حسابك'
              : '$e';
      if (kDebugMode) print('offline sync: $e');
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _writeData(Directory d, String b64, String at, String username) async {
    final f = File('${d.path}/data.js.tmp');
    final sink = f.openWrite();
    sink.write('window.VR_SNAP={"at":${jsonEncode(at)},"user":{"username":${jsonEncode(username)}},"b64":"');
    sink.write(b64);
    sink.write('"};');
    await sink.flush();
    await sink.close();
    await f.rename('${d.path}/data.js');
  }

  Future<List<BackupFile>> backups() async {
    final d = Directory('${(await dir).path}/backups');
    final out = <BackupFile>[];
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.sqlite')) {
        final st = await e.stat();
        out.add(BackupFile(e, st.modified, st.size));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<void> _prune() async {
    final list = await backups();
    for (final b in list.skip(keep)) {
      try {
        await b.file.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteBackup(BackupFile b) async {
    await b.file.delete();
    notifyListeners();
  }

  /// نعرض نسخة قديمة أوفلاين بدل آخر مزامنة
  Future<void> openBackupAsOffline(BackupFile b) async {
    final d = await dir;
    final bytes = await b.file.readAsBytes();
    final cur = File('${d.path}/data.js');
    if (!viewingBackup && await cur.exists()) await cur.rename('${d.path}/data.live.js');
    await _writeData(d, base64Encode(bytes), b.at.toIso8601String(), auth.user?.username ?? '');
    _snapAt = b.at.toIso8601String();
    viewingBackup = true;
    reloadSystem(offline: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
