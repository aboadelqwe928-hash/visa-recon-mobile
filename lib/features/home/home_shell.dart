import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/home_service.dart';
import '../../core/services/nav_bus.dart';
import '../../core/services/offline_service.dart';
import '../backup/sync_backup_screen.dart';
import '../settings/settings_screen.dart';
import '../system/system_screen.dart';
import 'home_screen.dart';

/// 4 تبويبات: الرئيسية (ملخص + تنبيهات + اختصارات) | السيستم | المزامنة والنسخ | الحساب.
/// أي اختصار أو تنبيه في الرئيسية بيقلب على السيستم ويفتح الشاشة المطلوبة جواه.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _navTick = 0;
  NavBus? _bus;

  final _pages = const [
    HomeScreen(),
    SystemScreen(),
    SyncBackupScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // أول ما التطبيق يفتح: مزامنة في الخلفية لو الكمبيوتر متاح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OfflineService>().syncIfDue();
      _bus = context.read<NavBus>();
      _navTick = _bus!.tick;
      _bus!.addListener(_onNav);
    });
  }

  @override
  void dispose() {
    _bus?.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() {
    final b = _bus;
    if (b == null || b.tick == _navTick) return;
    _navTick = b.tick;
    if (mounted && _index != 1) setState(() => _index = 1);
  }

  void _select(int i) {
    if (i == 0 && _index != 0) context.read<HomeService>().refresh();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final off = context.watch<OfflineService>();
    final home = context.watch<HomeService>();
    final alerts = (home.data?['alerts'] is List) ? (home.data!['alerts'] as List).length : 0;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alerts > 0,
              label: Text('$alerts'),
              child: const Icon(Icons.home_outlined),
            ),
            selectedIcon: const Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
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
            label: 'المزامنة',
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
