import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/discovery_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _scanning = false;
  double _scanProgress = 0;
  String? _error;
  List<DiscoveredServer> _found = [];
  bool _manualServer = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    if (auth.serverUrl != null && auth.serverUrl!.isNotEmpty) {
      _serverCtrl.text = auth.serverUrl!;
    } else {
      // Auto-scan on first open
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanProgress = 0;
      _found = [];
      _error = null;
    });

    try {
      final list = await DiscoveryService.scan(
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _scanProgress = total == 0 ? 0 : done / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _found = list;
        _scanning = false;
        if (list.isNotEmpty) {
          _serverCtrl.text = list.first.url;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'فشل البحث عن السيرفر: $e';
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();

    try {
      final url = _serverCtrl.text.trim();
      if (url.isEmpty) {
        throw ApiException('مفيش عنوان سيرفر. دوس بحث أو اكتبه يدوي.');
      }
      await auth.setServerUrl(url);
      await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('₤', style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'مطابقة الفيزا',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سجّل دخول عشان تكمل',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Server discovery card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wifi_tethering, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('السيرفر على الشبكة', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              if (!_scanning)
                                TextButton.icon(
                                  onPressed: _scan,
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('بحث'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                            ],
                          ),
                          if (_scanning) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _scanProgress > 0 ? _scanProgress : null,
                              backgroundColor: AppColors.border,
                              color: AppColors.primary,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'جاري البحث على الشبكة المحلية...',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ] else if (_found.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._found.map((s) => _ServerTile(
                                  server: s,
                                  selected: _serverCtrl.text == s.url,
                                  onTap: () => setState(() {
                                    _serverCtrl.text = s.url;
                                    _manualServer = false;
                                  }),
                                )),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'مفيش سيرفر ظاهر. تأكد إن البرنامج شغال و"الوصول من الموبايل" مفعّل، ودوس بحث.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _manualServer = !_manualServer),
                            child: Text(_manualServer ? 'إخفاء الإدخال اليدوي' : 'إدخال العنوان يدوي'),
                          ),
                          if (_manualServer) ...[
                            TextField(
                              controller: _serverCtrl,
                              textDirection: TextDirection.ltr,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'عنوان السيرفر',
                                hintText: 'http://192.168.1.10:8642',
                                isDense: true,
                                prefixIcon: Icon(Icons.dns_outlined, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Credentials
                  TextField(
                    controller: _userCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'الباسورد',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_loading || _scanning) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('دخول', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final DiscoveredServer server;
  final bool selected;
  final VoidCallback onTap;

  const _ServerTile({
    required this.server,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.host,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.text,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                      Text(
                        'منفذ ${server.port}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
