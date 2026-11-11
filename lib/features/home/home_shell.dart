import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync status bar
          if (sync.status != SyncStatus.idle)
            Material(
              color: _statusColor(sync.status),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      if (sync.isSyncing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        Icon(_statusIcon(sync.status), size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText(sync),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      if (sync.status == SyncStatus.error || sync.status == SyncStatus.offline)
                        TextButton(
                          onPressed: () => sync.syncIfPossible(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('إعادة', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'لوحة التحكم',
              ),
              const NavigationDestination(
                icon: Icon(Icons.assessment_outlined),
                selectedIcon: Icon(Icons.assessment),
                label: 'التقارير',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: auth.user?.displayName ?? 'الحساب',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(SyncStatus s) {
    switch (s) {
      case SyncStatus.syncing:
        return AppColors.primary;
      case SyncStatus.success:
        return AppColors.success;
      case SyncStatus.offline:
        return AppColors.warning;
      case SyncStatus.error:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  IconData _statusIcon(SyncStatus s) {
    switch (s) {
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.error:
        return Icons.error_outline;
      default:
        return Icons.cloud_sync;
    }
  }

  String _statusText(SyncService sync) {
    switch (sync.status) {
      case SyncStatus.syncing:
        return 'جاري المزامنة...';
      case SyncStatus.success:
        final t = sync.lastSyncAt;
        if (t == null) return 'تمت المزامنة';
        return 'آخر مزامنة: ${_timeAgo(t)}';
      case SyncStatus.offline:
        return 'أوفلاين — بتعرض البيانات المحفوظة';
      case SyncStatus.error:
        return sync.lastError ?? 'فشل المزامنة';
      default:
        return '';
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
    if (d.inHours < 24) return 'منذ ${d.inHours} س';
    return 'منذ ${d.inDays} يوم';
  }
}
