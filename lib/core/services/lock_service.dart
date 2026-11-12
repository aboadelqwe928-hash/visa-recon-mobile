import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// قفل التطبيق: رقم سري، ومعاه بصمة (أو الوش) لو الموبايل بيدعمها.
/// بيتقفل عند فتح التطبيق، ولما يرجع من الخلفية بعد أكتر من 30 ثانية.
class LockService extends ChangeNotifier with WidgetsBindingObserver {
  final _s = const FlutterSecureStorage();
  final _la = LocalAuthentication();

  String _mode = 'none'; // none | pin | bio
  String? _pin;
  bool _locked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  String get mode => _mode;
  bool get enabled => _mode != 'none';
  bool get bio => _mode == 'bio';
  bool get locked => _locked;

  Future<void> init() async {
    try {
      _pin = await _s.read(key: 'lock_pin');
      _mode = await _s.read(key: 'lock_mode') ?? 'none';
    } catch (_) {
      _mode = 'none';
    }
    if (_pin == null || _pin!.isEmpty) _mode = 'none';
    _locked = enabled;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled || _busy) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (p != null && DateTime.now().difference(p) > const Duration(seconds: 30)) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  Future<bool> canUseBio() async {
    try {
      return await _la.isDeviceSupported() && await _la.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryBio() async {
    if (!bio || _busy) return false;
    _busy = true;
    try {
      final ok = await _la.authenticate(
        localizedReason: 'افتح رقابة الفيزا والكاش',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) unlock();
      return ok;
    } catch (e) {
      if (kDebugMode) print('bio error: $e');
      return false;
    } finally {
      _busy = false;
      _pausedAt = null;
    }
  }

  bool checkPin(String p) {
    if (_pin != null && p == _pin) {
      unlock();
      return true;
    }
    return false;
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _pin = pin;
    if (_mode == 'none') _mode = 'pin';
    await _s.write(key: 'lock_pin', value: pin);
    await _s.write(key: 'lock_mode', value: _mode);
    notifyListeners();
  }

  Future<void> setBio(bool on) async {
    if (_pin == null) return;
    _mode = on ? 'bio' : 'pin';
    await _s.write(key: 'lock_mode', value: _mode);
    notifyListeners();
  }

  Future<void> disable() async {
    _mode = 'none';
    _pin = null;
    _locked = false;
    await _s.delete(key: 'lock_pin');
    await _s.write(key: 'lock_mode', value: 'none');
    notifyListeners();
  }
}
