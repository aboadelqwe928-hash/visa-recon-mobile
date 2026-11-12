import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/auth_service.dart';

/// السيستم كله: نفس شاشات برنامج الكمبيوتر (فيزا + كاش + الإجمالي) جوه التطبيق.
/// التطبيق بيبعت التوكن للصفحة (?vrt=)، والصفحة بتبعت الصور وملفات Excel/PDF
/// للتطبيق من قناة VRBridge، والتطبيق بيفتح المشاركة (واتساب، Drive، ...).
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> with AutomaticKeepAliveClientMixin {
  WebViewController? _c;
  String? _loadedFor;
  int _progress = 0;
  String? _error;
  bool _sharing = false;

  @override
  bool get wantKeepAlive => true;

  void _ensure(AuthService auth) {
    final url = auth.serverUrl;
    final token = auth.token;
    if (url == null || url.isEmpty || token == null || token.isEmpty) return;
    final key = '$url|$token';
    if (_loadedFor == key) return;
    _loadedFor = key;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F5F8))
      ..addJavaScriptChannel('VRBridge', onMessageReceived: (m) => _onMessage(m.message, auth))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = null);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            if (mounted) setState(() => _error = e.description);
          }
        },
        // الصفحات اللي برا السيستم ما تتفتحش جوه التطبيق
        onNavigationRequest: (r) => r.url.startsWith(url) || r.url.startsWith('data:') || r.url.startsWith('blob:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
    c.loadRequest(Uri.parse('$url/?vrt=${Uri.encodeComponent(token)}#dashboard'));
    _c = c;
  }

  Future<void> _onMessage(String msg, AuthService auth) async {
    try {
      final m = jsonDecode(msg);
      if (m is! Map) return;
      if (m['t'] == 'logout') {
        await auth.logout();
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
    final auth = context.watch<AuthService>();
    _ensure(auth);
    final c = _c;
    if (c == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('محتاج تتصل بالكمبيوتر وتسجل دخول الأول', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await c.canGoBack()) {
          await c.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: c),
              if (_progress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100, minHeight: 3),
                ),
              if (_sharing)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_error != null)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 48),
                        const SizedBox(height: 12),
                        const Text('مش قادر أوصل لبرنامج الكمبيوتر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'اتأكد إن الموبايل على نفس الواي فاي، وإن "الوصول من الموبايل" شغال في البرنامج.\n${auth.serverUrl ?? ''}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _error = null);
                            c.reload();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('حاول تاني'),
                        ),
                        const SizedBox(height: 8),
                        const Text('تقدر تشوف آخر بيانات اتحفظت من تبويب "ملخص سريع" تحت.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: _error == null
            ? FloatingActionButton.small(
                heroTag: 'reload',
                tooltip: 'تحديث',
                onPressed: () => c.reload(),
                child: const Icon(Icons.refresh),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }
}
