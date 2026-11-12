import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/lock_service.dart';
import '../../core/theme/app_theme.dart';

/// شاشة القفل: رقم سري + زرار البصمة
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _code = '';
  String? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lock = context.read<LockService>();
      if (lock.bio) lock.tryBio();
    });
  }

  void _press(String d) {
    if (_code.length >= 6) return;
    setState(() {
      _code += d;
      _err = null;
    });
    final lock = context.read<LockService>();
    if (_code.length >= 4 && lock.checkPin(_code)) return;
    if (_code.length == 6) {
      setState(() {
        _code = '';
        _err = 'الرقم السري غلط';
      });
    }
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('نسيت الرقم السري؟'),
        content: const Text('هيتقفل القفل ويتعمل خروج من الحساب، وتسجل دخول تاني باسم المستخدم والباسورد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final lock = context.read<LockService>();
    final auth = context.read<AuthService>();
    await lock.disable();
    await auth.logout();
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon}) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: Colors.white.withOpacity(0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () => _press(label),
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 28)
                : Text(label, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockService>();
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 44),
                const SizedBox(height: 10),
                const Text('رقابة الفيزا والكاش', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('اكتب الرقم السري', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    6,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _code.length ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: _err == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_err!, style: const TextStyle(color: Color(0xFFFFB4A9))),
                        ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [for (final d in r) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _key(d))],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: lock.bio
                                  ? _key('', icon: Icons.fingerprint, onTap: () => lock.tryBio())
                                  : const SizedBox(width: 76, height: 76),
                            ),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _key('0')),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _key('', icon: Icons.backspace_outlined, onTap: () {
                                if (_code.isNotEmpty) setState(() => _code = _code.substring(0, _code.length - 1));
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _forgot,
                  child: const Text('نسيت الرقم السري؟', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
