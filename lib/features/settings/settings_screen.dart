import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/local_db.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? _lastSync;
  final _serverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMeta();
    final auth = context.read<AuthService>();
    _serverCtrl.text = auth.serverUrl ?? '';
  }

  Future<void> _loadMeta() async {
    final t = await LocalDb.lastSuccessfulSync();
    if (mounted) setState(() => _lastSync = t);
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('الحساب والإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      (user?.displayName.isNotEmpty == true)
                          ? user!.displayName.characters.first
                          : '؟',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _roleLabel(user?.role),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        if (user?.branches.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            user!.branches.join('، '),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('السيرفر', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _serverCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'عنوان السيرفر',
                      hintText: 'http://192.168.1.10:8642',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await auth.setServerUrl(_serverCtrl.text.trim());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ عنوان السيرفر')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: const Text('حفظ العنوان'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('المزامنة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    sync.status == SyncStatus.offline ? Icons.cloud_off : Icons.cloud_done,
                    color: AppColors.primary,
                  ),
                  title: const Text('آخر مزامنة ناجحة'),
                  subtitle: Text(_lastSync == null
                      ? 'لم تتم بعد'
                      : '${_lastSync!.year}/${_lastSync!.month.toString().padLeft(2, '0')}/${_lastSync!.day.toString().padLeft(2, '0')}  ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')}'),
                  trailing: sync.isSyncing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.sync),
                          onPressed: () async {
                            await sync.forceSync();
                            await _loadMeta();
                          },
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('مسح البيانات المحفوظة'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تأكيد'),
                        content: const Text('هتتمسح كل التقارير المحفوظة على الموبايل. هتحتاج مزامنة تاني.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('مسح', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await LocalDb.clearCache();
                      await _loadMeta();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('اتمسحت البيانات المحلية')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تسجيل خروج'),
                    content: const Text('هتخرج من الحساب. البيانات المحفوظة هتفضل موجودة.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
                    ],
                  ),
                );
                if (ok == true) await auth.logout();
              },
              icon: const Icon(Icons.logout, color: AppColors.danger),
              label: const Text('تسجيل خروج', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'branch':
        return 'مدير فرع';
      case 'viewer':
        return 'مشاهد';
      default:
        return role ?? '';
    }
  }
}
