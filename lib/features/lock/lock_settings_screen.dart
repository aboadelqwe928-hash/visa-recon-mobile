import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/lock_service.dart';

/// إعدادات قفل التطبيق
class LockSettingsScreen extends StatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  bool _canBio = false;

  @override
  void initState() {
    super.initState();
    context.read<LockService>().canUseBio().then((v) {
      if (mounted) setState(() => _canBio = v);
    });
  }

  Future<String?> _askPin(String title) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          textDirection: TextDirection.ltr,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '4 لـ 6 أرقام'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('تمام')),
        ],
      ),
    );
    return r;
  }

  Future<bool> _newPin() async {
    final a = await _askPin('الرقم السري الجديد');
    if (a == null) return false;
    if (a.length < 4) {
      _snack('الرقم السري لازم 4 أرقام على الأقل');
      return false;
    }
    final b = await _askPin('اكتبه تاني');
    if (b == null) return false;
    if (a != b) {
      _snack('الرقمين مش زي بعض');
      return false;
    }
    if (!mounted) return false;
    await context.read<LockService>().setPin(a);
    _snack('اتحفظ الرقم السري');
    return true;
  }

  Future<bool> _confirmOld() async {
    final lock = context.read<LockService>();
    final p = await _askPin('الرقم السري الحالي');
    if (p == null) return false;
    if (!lock.checkPin(p)) {
      _snack('الرقم السري غلط');
      return false;
    }
    return true;
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockService>();
    return Scaffold(
      appBar: AppBar(title: const Text('قفل التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('قفل برقم سري'),
                  subtitle: const Text('التطبيق يطلب الرقم كل ما يتفتح، أو يرجع بعد أكتر من 30 ثانية'),
                  value: lock.enabled,
                  onChanged: (v) async {
                    if (v) {
                      await _newPin();
                    } else if (await _confirmOld()) {
                      await lock.disable();
                      _snack('القفل اتشال');
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('البصمة / الوش'),
                  subtitle: Text(_canBio ? 'تفتح بالبصمة، والرقم السري بديل لو البصمة ما اشتغلتش' : 'الموبايل ده مفيهوش بصمة متسجلة'),
                  value: lock.bio,
                  onChanged: !lock.enabled || !_canBio
                      ? null
                      : (v) async {
                          if (v) {
                            await lock.setBio(true);
                            final ok = await lock.tryBio();
                            if (!ok) {
                              await lock.setBio(false);
                              _snack('البصمة ما اتأكدتش، جرب تاني');
                            }
                          } else {
                            await lock.setBio(false);
                          }
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: lock.enabled,
                  leading: const Icon(Icons.password),
                  title: const Text('تغيير الرقم السري'),
                  onTap: () async {
                    if (await _confirmOld()) await _newPin();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لو نسيت الرقم السري: من شاشة القفل دوس "نسيت الرقم السري؟"، وهيتعمل خروج وتسجل دخول تاني بالباسورد.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
