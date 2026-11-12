import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/offline_service.dart';

/// السيستم كله جوه التطبيق.
/// - متصل بالكمبيوتر: نفس شاشات البرنامج مباشرة.
/// - مش متصل: نفس الشاشات من آخر مزامنة (offline.html + data.js) من غير أي شريط على الشاشة.
/// الصور وملفات Excel/PDF بتيجي من قناة VRBridge وتتفتح للمشاركة.
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

enum _Mode { none, online, offline }

class _SystemScreenState extends State<SystemScreen> with AutomaticKeepAliveClientMixin {
  late final WebViewController _c;
  _Mode _mode = _Mode.none;
  bool _deciding = false;
  bool _failed = false;
  bool _sharing = false;
  int _progress = 0;
  String? _key;
  String? _shownSnap;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F5F8))
      ..addJavaScriptChannel('VRBridge', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) {
          if (_mode == _Mode.online) context.read<OfflineService>().syncIfDue();
        },
        onWebResourceError: (e) {
          // الكمبيوتر وقع وإحنا شغالين: نقلب على الأوفلاين بهدوء
          if ((e.isForMainFrame ?? true) && _mode == _Mode.online) _decide(force: true);
        },
        onNavigationRequest: (r) {
          final base = context.read<AuthService>().serverUrl ?? '\u0000';
          final ok = r.url.startsWith(base) || r.url.startsWith('file:') || r.url.startsWith('data:') || r.url.startsWith('blob:');
          return ok ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    final off = context.watch<OfflineService>();
    final key = '${auth.serverUrl}|${auth.token}|${off.reloadTick}';
    if (key != _key) {
      _key = key;
      _decide(force: true);
    } else if (_mode == _Mode.offline && off.snapAt != _shownSnap) {
      // مزامنة جديدة وإحنا أوفلاين: نعرض البيانات الجديدة
      _loadOffline();
    }
  }

  Future<void> _decide({bool force = false}) async {
    if (_deciding) return;
    _deciding = true;
    try {
      final auth = context.read<AuthService>();
      final off = context.read<OfflineService>();
      final api = context.read<ApiClient>();
      final url = auth.serverUrl;
      final token = auth.token;
      final wantOffline = off.forceOffline;
      final online = !wantOffline && url != null && url.isNotEmpty && token != null && await api.ping();
      if (online) {
        _mode = _Mode.online;
        _failed = false;
        await _c.loadRequest(Uri.parse('$url/?vrt=${Uri.encodeComponent(token)}#dashboard'));
      } else if (await off.hasOffline) {
        await _loadOffline();
      } else {
        _mode = _Mode.none;
        _failed = true;
      }
    } finally {
      _deciding = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadOffline() async {
    final off = context.read<OfflineService>();
    _mode = _Mode.offline;
    _failed = false;
    _shownSnap = off.snapAt;
    await _c.loadFile(await off.htmlPath);
    if (mounted) setState(() {});
  }

  Future<void> _onMessage(String msg) async {
    try {
      final m = jsonDecode(msg);
      if (m is! Map) return;
      if (m['t'] == 'logout') {
        if (mounted) await context.read<AuthService>().logout();
        return;
      }
      if (m['t'] == 'file') {
        if (_sharing) return;
        setState(() => _sharing = true);
        final bytes = base64Decode(m['b64'] as String);
        final dir = await getTemporaryDirectory();
        final name = ((m['name'] as String?) ?? 'ملف').replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
        final f = File('${dir.path}/$name');
        await f.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(f.path, mimeType: m['mime'] as String?, name: name)], subject: name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('مقدرتش أجهز الملف: $e')));
      }
    } finally {
      if (mounted && _sharing) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          await _c.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _c),
              // خط تحميل رفيع بس (من غير أي كلام على الشاشة)
              if (_progress < 100 && _mode != _Mode.none)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100, minHeight: 2),
                ),
              if (_sharing)
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator())),
                ),
              if (_mode == _Mode.none) Positioned.fill(child: _empty(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      color: t.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: _deciding && !_failed
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: t.colorScheme.primary),
                  const SizedBox(height: 14),
                  const Text('مفيش اتصال ولا نسخة محفوظة لسه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'اتصل بالكمبيوتر مرة واحدة (نفس الواي فاي و"الوصول من الموبايل" شغال)، والتطبيق هيحفظ نسخة كاملة تشتغل بعد كده من غير نت.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _decide(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('حاول تاني'),
                  ),
                ],
              ),
      ),
    );
  }
}
