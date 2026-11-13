import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/services/home_service.dart';
import 'core/services/lock_service.dart';
import 'core/services/nav_bus.dart';
import 'core/services/offline_service.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/lock/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // أسماء الأيام والشهور بالعربي (الرئيسية)
  try {
    await initializeDateFormatting('ar');
  } catch (_) {}
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final api = ApiClient();
  final auth = AuthService(api);
  await auth.init();

  // الكاش القديم (ملخص سريع) اتشال: النسخة الكاملة بقت في OfflineService
  final sync = SyncService(api, auth);

  final offline = OfflineService(api, auth);
  await offline.init();

  final lock = LockService();
  await lock.init();

  // 1.3.0: الشاشة الرئيسية + فتح شاشات السيستم منها
  final home = HomeService(api, auth);
  await home.init();
  final nav = NavBus();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: lock),
        ChangeNotifierProvider.value(value: offline),
        ChangeNotifierProvider.value(value: home),
        ChangeNotifierProvider.value(value: nav),
      ],
      child: const VisaReconApp(),
    ),
  );
}

class VisaReconApp extends StatelessWidget {
  const VisaReconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رقابة الفيزا والكاش',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: Consumer2<AuthService, LockService>(
        builder: (context, auth, lock, _) {
          if (auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isLoggedIn) {
            // شاشة القفل فوق التطبيق (التطبيق يفضل شغال تحتها)
            return Stack(
              children: [
                const HomeShell(),
                if (lock.locked) const Positioned.fill(child: LockScreen()),
              ],
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
