import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/widgets.dart';

import '../services/app_lock_service.dart';

/// Drives when the lock UI is shown (cold start + returning from background).
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppLockProvider() {
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
    _bootstrap();
  }

  bool _ready = false;
  bool _lockEnabled = false;
  bool _locked = false;

  bool get isReady => _ready;
  bool get shouldShowLock => !kIsWeb && _ready && _lockEnabled && _locked;

  Future<void> _bootstrap() async {
    await AppLockService.instance.load();
    _lockEnabled = AppLockService.instance.isLockEnabled;
    if (_lockEnabled) {
      _locked = true;
    }
    _ready = true;
    notifyListeners();
  }

  /// After user enables lock in Settings (same session stays unlocked).
  void applyEnabledWithoutLocking() {
    _lockEnabled = true;
    _locked = false;
    notifyListeners();
  }

  /// After user disables lock in Settings.
  void applyDisabled() {
    _lockEnabled = false;
    _locked = false;
    notifyListeners();
  }

  /// Reload flags from storage without forcing lock (e.g. toggled biometric).
  Future<void> reloadSettings() async {
    await AppLockService.instance.load();
    _lockEnabled = AppLockService.instance.isLockEnabled;
    if (!_lockEnabled) _locked = false;
    notifyListeners();
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !_lockEnabled) return;
    if (state == AppLifecycleState.paused) {
      _locked = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
