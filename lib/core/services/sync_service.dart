import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../api/api_client.dart';
import '../db/local_db.dart';
import 'auth_service.dart';

enum SyncStatus { idle, syncing, success, offline, error }

class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  final ApiClient api;
  final AuthService auth;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncAt;
  bool _autoEnabled = true;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySub;
  bool _wasOnline = false;

  // Current period the user is viewing (used for sync)
  String? periodFrom;
  String? periodTo;

  SyncService(this.api, this.auth);

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get isOnline => _status != SyncStatus.offline && _status != SyncStatus.error;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lastSyncAt = await LocalDb.lastSuccessfulSync();

    // Listen to connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !_wasOnline && auth.isLoggedIn && _autoEnabled) {
        // Just came online → try auto sync
        Future.delayed(const Duration(seconds: 1), () => syncIfPossible());
      }
      _wasOnline = online;
    });

    // Periodic light check every 2 minutes when app is active
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_autoEnabled && auth.isLoggedIn) syncIfPossible(silent: true);
    });

    // Initial attempt
    if (auth.isLoggedIn) {
      await syncIfPossible(silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && auth.isLoggedIn && _autoEnabled) {
      syncIfPossible(silent: true);
    }
  }

  Future<bool> _canReachServer() async {
    if (!api.isConfigured || !auth.isLoggedIn) return false;
    try {
      return await api.ping();
    } catch (_) {
      return false;
    }
  }

  /// Main entry: try to sync if server is reachable
  Future<void> syncIfPossible({bool silent = false, String? from, String? to}) async {
    if (_status == SyncStatus.syncing) return;
    if (!auth.isLoggedIn) return;

    final reachable = await _canReachServer();
    if (!reachable) {
      _status = SyncStatus.offline;
      if (!silent) notifyListeners();
      return;
    }

    await forceSync(from: from ?? periodFrom, to: to ?? periodTo, silent: silent);
  }

  /// Force a full sync of important data
  Future<void> forceSync({String? from, String? to, bool silent = false}) async {
    if (_status == SyncStatus.syncing) return;
    if (!auth.isLoggedIn) return;

    _status = SyncStatus.syncing;
    _lastError = null;
    if (!silent) notifyListeners();

    try {
      // Default period: last 7 days if not provided
      final now = DateTime.now();
      final defaultTo = _fmt(now);
      final defaultFrom = _fmt(now.subtract(const Duration(days: 6)));
      final pFrom = from ?? defaultFrom;
      final pTo = to ?? defaultTo;

      periodFrom = pFrom;
      periodTo = pTo;

      // 1. Dashboard
      final dashboard = await api.call('r.dashboard', {'from': pFrom, 'to': pTo});
      await LocalDb.put('dashboard:$pFrom:$pTo', dashboard, from: pFrom, to: pTo);
      await LocalDb.put('dashboard:latest', dashboard, from: pFrom, to: pTo);

      // 2. Branches report
      final branches = await api.call('r.branches', {'from': pFrom, 'to': pTo});
      await LocalDb.put('branches:$pFrom:$pTo', branches, from: pFrom, to: pTo);

      // 3. Cashiers
      final cashiers = await api.call('r.cashiers', {'from': pFrom, 'to': pTo});
      await LocalDb.put('cashiers:$pFrom:$pTo', cashiers, from: pFrom, to: pTo);

      // 4. Balance (زيادة وعجز)
      final balance = await api.call('r.balance', {'from': pFrom, 'to': pTo});
      await LocalDb.put('balance:$pFrom:$pTo', balance, from: pFrom, to: pTo);

      // 5. Gaps
      final gaps = await api.call('r.gaps', {'from': pFrom, 'to': pTo});
      await LocalDb.put('gaps:$pFrom:$pTo', gaps, from: pFrom, to: pTo);

      // 6. General / summary
      final general = await api.call('r.general', {'from': pFrom, 'to': pTo});
      await LocalDb.put('general:$pFrom:$pTo', general, from: pFrom, to: pTo);

      // 7. Meta (user + period)
      await LocalDb.setMeta('last_period_from', pFrom);
      await LocalDb.setMeta('last_period_to', pTo);

      _lastSyncAt = DateTime.now();
      await LocalDb.logSync(success: true, message: 'تمت المزامنة ($pFrom → $pTo)');
      _status = SyncStatus.success;
    } catch (e) {
      _lastError = e.toString();
      await LocalDb.logSync(success: false, message: _lastError);
      _status = SyncStatus.error;
      if (kDebugMode) print('Sync error: $e');
    }

    notifyListeners();
  }

  /// Read cached data (works offline)
  Future<dynamic> getCached(String type, {String? from, String? to}) async {
    if (from != null && to != null) {
      final specific = await LocalDb.getData('$type:$from:$to');
      if (specific != null) return specific;
    }
    // fallback to latest
    if (type == 'dashboard') {
      return LocalDb.getData('dashboard:latest');
    }
    final lastFrom = await LocalDb.getMeta('last_period_from');
    final lastTo = await LocalDb.getMeta('last_period_to');
    if (lastFrom != null && lastTo != null) {
      return LocalDb.getData('$type:$lastFrom:$lastTo');
    }
    return null;
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
