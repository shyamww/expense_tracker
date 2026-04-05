import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kInstallEpochKey = 'app_install_epoch_ms';
const _kInstallBuildIdKey = 'app_install_countdown_build_id';
const _kDevStampKey = 'app_install_countdown_dev_stamp';

/// Optional: pass a new value each deploy to force a fresh 7-day window without
/// bumping pubspec, e.g. `flutter run --dart-define=INSTALL_COUNTDOWN_STAMP=2`
const String _kDevStampFromEnv =
    String.fromEnvironment('INSTALL_COUNTDOWN_STAMP', defaultValue: '');

/// Days remaining in a 7×24h window from the stored install instant.
///
/// The epoch resets when [PackageInfo] `version+buildNumber` changes (bump
/// `version: x.y.z+N` in pubspec). In-place `flutter run` keeps UserDefaults on
/// iOS, so the same +N keeps the old countdown until you delete the app, bump
/// the build, or set [INSTALL_COUNTDOWN_STAMP].
class InstallCountdownBar extends StatefulWidget {
  const InstallCountdownBar({super.key});

  @override
  State<InstallCountdownBar> createState() => _InstallCountdownBarState();
}

class _InstallCountdownBarState extends State<InstallCountdownBar>
    with WidgetsBindingObserver {
  int? _daysLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final buildId = '${info.version}+${info.buildNumber}';
      final storedBuildId = prefs.getString(_kInstallBuildIdKey);
      final devStampStored = prefs.getString(_kDevStampKey);

      final buildChanged = storedBuildId != buildId;
      final devStampChanged = _kDevStampFromEnv.isNotEmpty &&
          devStampStored != _kDevStampFromEnv;

      var ms = prefs.getInt(_kInstallEpochKey);
      if (ms == null || buildChanged || devStampChanged) {
        ms = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_kInstallEpochKey, ms);
        await prefs.setString(_kInstallBuildIdKey, buildId);
        if (_kDevStampFromEnv.isNotEmpty) {
          await prefs.setString(_kDevStampKey, _kDevStampFromEnv);
        }
      }

      final install = DateTime.fromMillisecondsSinceEpoch(ms);
      final end = install.add(const Duration(days: 7));
      final now = DateTime.now();
      final leftMillis = end.difference(now).inMilliseconds;

      int left;
      if (leftMillis <= 0) {
        left = 0;
      } else {
        left = (leftMillis / Duration.millisecondsPerDay).ceil();
        if (left > 7) left = 7;
      }

      if (mounted) setState(() => _daysLeft = left);
    } catch (_) {
      if (mounted) setState(() => _daysLeft = 7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _daysLeft;
    final label = left == null
        ? '7 days left'
        : '$left day${left == 1 ? '' : 's'} left';

    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        height: 1.2,
        color: left == null
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
