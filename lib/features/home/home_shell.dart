import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/offline_service.dart';
import '../backup/sync_backup_screen.dart';
import '../settings/settings_screen.dart';
import '../system/system_screen.dart';

/// 3 تبويبات بس، ومن غير أي شريط حالة فوق السيستم: الشاشة كلها للبيانات.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    SystemScreen(),
    SyncBackupScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // أول ما التطبيق يفتح: مزامنة في الخلفية لو الكمبيوتر متاح
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OfflineService>().syncIfDue());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final off = context.watch<OfflineService>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'السيستم',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: off.error != null,
              smallSize: 8,
              child: off.syncing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_sync_outlined),
            ),
            selectedIcon: const Icon(Icons.cloud_sync),
            label: 'المزامنة والنسخ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: auth.user?.displayName ?? 'الحساب',
          ),
        ],
      ),
    );
  }
}
