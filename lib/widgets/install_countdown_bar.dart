import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kInstallEpochKey = 'app_install_epoch_ms';

/// Days remaining from first launch (calendar days), for dev-build reinstall reminders.
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
      var ms = prefs.getInt(_kInstallEpochKey);
      if (ms == null) {
        ms = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_kInstallEpochKey, ms);
      }

      final install = DateTime.fromMillisecondsSinceEpoch(ms);
      final installDay = DateTime(install.year, install.month, install.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final elapsedDays = today.difference(installDay).inDays;
      var left = 7 - elapsedDays;
      if (left < 0) left = 0;
      if (left > 7) left = 7;

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
