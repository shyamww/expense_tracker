import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_lock_service.dart';
import '../services/expense_reminder_service.dart';
import '../widgets/feedback_form_sheet.dart';
import 'backup_screen.dart';
import 'category_management_screen.dart';
import 'account_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';
  static const String _developerName = 'Shyam Gautam';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: 'Notifications'),
          if (kIsWeb)
            ListTile(
              leading: Icon(Icons.notifications_off_outlined,
                  color: Colors.grey.shade700),
              title: const Text('Daily reminder'),
              subtitle: const Text('Not available on web'),
            )
          else
            const _DailyReminderSettings(),
          const Divider(height: 1),
          _SectionHeader(title: 'Privacy'),
          if (kIsWeb)
            ListTile(
              leading:
                  Icon(Icons.lock_outline_rounded, color: Colors.grey.shade700),
              title: const Text('App lock'),
              subtitle: const Text('Not available on web'),
            )
          else
            const _AppLockSettings(),
          const Divider(height: 1),
          _SectionHeader(title: 'General'),
          ListTile(
            leading:
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade700),
            title: const Text('App info'),
            subtitle: const Text('Version, developer, and details'),
            onTap: () => _showAppInfoDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: Colors.grey.shade700),
            title: const Text('Appearance'),
            subtitle: const Text('Switch between light and dark mode'),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => const _ThemeSettingsSheet(),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.category_outlined, color: Colors.grey.shade700),
            title: const Text('Categories'),
            subtitle: const Text('Add, edit, or delete expense categories'),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => const CategoryManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_outlined,
                color: Colors.grey.shade700),
            title: const Text('Accounts'),
            subtitle: const Text(
                'Banks and cash — used when adding income or expenses'),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => const AccountManagementScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Data'),
          ListTile(
            leading: Icon(Icons.folder_outlined, color: Colors.grey.shade700),
            title: const Text('Where your data lives'),
            subtitle: const Text(
              'Stored locally on this device. Use Backup to export or restore JSON.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.cloud_outlined, color: Colors.grey.shade700),
            title: const Text('Backup & restore'),
            subtitle: const Text('Export or import your data'),
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Support'),
          ListTile(
            leading: Icon(Icons.feedback_outlined, color: Colors.grey.shade700),
            title: const Text('Send feedback'),
            subtitle: const Text(
                'Sent with Web3Forms — your inbox is not in the app'),
            onTap: () => _openFeedbackSheet(context),
          ),
        ],
      ),
    );
  }

  static void _openFeedbackSheet(BuildContext context) {
    // Use the Settings scaffold’s messenger — the sheet’s own context may not find one.
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FeedbackFormSheet(scaffoldMessenger: messenger),
    );
  }

  static void _showAppInfoDialog(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense Tracker',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personal expense & income',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _AppInfoRow(label: 'Version', value: _appVersion),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Colors.grey.shade200),
                      ),
                      _AppInfoRow(label: 'Developer', value: _developerName),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Track income, expenses, and monthly balance. Your data stays on this device unless you export a backup from the Backup tab.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how the app looks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _ThemeChoiceTile(
              icon: Icons.light_mode_rounded,
              title: 'Light',
              subtitle: 'Bright surfaces and the current default look',
              selected: themeProvider.themeMode == ThemeMode.light,
              onTap: () async {
                await context
                    .read<ThemeProvider>()
                    .setThemeMode(ThemeMode.light);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _ThemeChoiceTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark',
              subtitle: 'Dimmed surfaces for night-time use',
              selected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () async {
                await context
                    .read<ThemeProvider>()
                    .setThemeMode(ThemeMode.dark);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : theme.dividerColor,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _AppInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyReminderSettings extends StatefulWidget {
  const _DailyReminderSettings();

  @override
  State<_DailyReminderSettings> createState() => _DailyReminderSettingsState();
}

class _DailyReminderSettingsState extends State<_DailyReminderSettings> {
  bool _loading = true;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(
    hour: ExpenseReminderService.defaultHour,
    minute: ExpenseReminderService.defaultMinute,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ExpenseReminderService.instance;
    final e = await s.isEnabled();
    final t = await s.reminderTime();
    if (mounted) {
      setState(() {
        _enabled = e;
        _time = t;
        _loading = false;
      });
    }
  }

  String _formatTime(BuildContext context) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      _time,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      await ExpenseReminderService.instance.setReminderTime(picked);
      if (mounted) setState(() => _time = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey.shade600,
          ),
        ),
        title: const Text('Daily reminder'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: Icon(Icons.notifications_active_outlined,
              color: Colors.grey.shade700),
          title: const Text('Daily reminder'),
          subtitle: Text(
            _enabled
                ? 'Tap below to change time · ${_formatTime(context)}'
                : 'Nudge to add today\'s expenses',
          ),
          value: _enabled,
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            final timeLabel = _formatTime(context);
            await ExpenseReminderService.instance.setReminderEnabled(v);
            if (!mounted) return;
            setState(() => _enabled = v);
            if (v) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Reminder scheduled for $timeLabel'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        if (_enabled)
          ListTile(
            leading: const SizedBox(width: 40),
            title: const Text('Reminder time'),
            subtitle: Text(
              _formatTime(context),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: const Icon(Icons.schedule_rounded),
            onTap: _pickTime,
          ),
      ],
    );
  }
}

class _AppLockSettings extends StatefulWidget {
  const _AppLockSettings();

  @override
  State<_AppLockSettings> createState() => _AppLockSettingsState();
}

class _AppLockSettingsState extends State<_AppLockSettings> {
  bool _loading = true;
  bool _lockOn = false;
  bool _bioOn = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppLockService.instance.load();
    final bio = await AppLockService.instance.deviceCanCheckBiometrics();
    if (!mounted) return;
    setState(() {
      _lockOn = AppLockService.instance.isLockEnabled;
      _bioOn = AppLockService.instance.isBiometricEnabled;
      _bioAvailable = bio;
      _loading = false;
    });
  }

  Future<void> _onLockToggle(bool wantOn) async {
    if (wantOn) {
      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SetPinDialog(title: 'Set PIN'),
      );
      if (pin == null || !mounted) return;
      await AppLockService.instance.setPin(pin);
      await AppLockService.instance.setLockEnabled(true);
      if (!mounted) return;
      context.read<AppLockProvider>().applyEnabledWithoutLocking();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'App lock is on. You can enable Face ID or fingerprint below.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DisableLockDialog(biometricEnabled: _bioOn),
      );
      if (ok != true || !mounted) return;
      await AppLockService.instance.clearLockAndPin();
      if (!mounted) return;
      context.read<AppLockProvider>().applyDisabled();
      await _load();
    }
  }

  Future<void> _onChangePin() async {
    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePinDialog(),
    );
    if (newPin == null || !mounted) return;
    await AppLockService.instance.setPin(newPin);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey.shade600,
          ),
        ),
        title: const Text('App lock'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary:
              Icon(Icons.lock_outline_rounded, color: Colors.grey.shade700),
          title: const Text('App lock'),
          subtitle: const Text(
              '4-digit PIN when opening the app or returning from background'),
          value: _lockOn,
          onChanged: _onLockToggle,
        ),
        if (_lockOn && _bioAvailable)
          SwitchListTile(
            secondary:
                Icon(Icons.fingerprint_rounded, color: Colors.grey.shade700),
            title: const Text('Face ID / fingerprint'),
            subtitle: const Text('Unlock with biometrics when available'),
            value: _bioOn,
            onChanged: (v) async {
              await AppLockService.instance.setBiometricEnabled(v);
              if (!context.mounted) return;
              await context.read<AppLockProvider>().reloadSettings();
              if (!context.mounted) return;
              await _load();
            },
          ),
        if (_lockOn)
          ListTile(
            leading: Icon(Icons.pin_outlined, color: Colors.grey.shade700),
            title: const Text('Change PIN'),
            onTap: _onChangePin,
          ),
      ],
    );
  }
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog({required this.title});

  final String title;

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _submit() {
    if (!AppLockService.isValidPinFormat(_a.text)) {
      setState(() => _err = 'Use exactly 4 digits.');
      return;
    }
    if (_a.text != _b.text) {
      setState(() => _err = 'PINs do not match.');
      return;
    }
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _a,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN (4 digits)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _b,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm PIN (4 digits)',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DisableLockDialog extends StatefulWidget {
  const _DisableLockDialog({required this.biometricEnabled});

  final bool biometricEnabled;

  @override
  State<_DisableLockDialog> createState() => _DisableLockDialogState();
}

class _DisableLockDialogState extends State<_DisableLockDialog> {
  final _pin = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryBio() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final ok = await AppLockService.instance.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _tryPin() async {
    if (!AppLockService.isValidPinFormat(_pin.text)) {
      setState(() => _err = 'Enter your 4-digit PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final ok = await AppLockService.instance.verifyPin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _err = 'Incorrect PIN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turn off app lock?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Confirm with your 4-digit PIN or biometrics.'),
            const SizedBox(height: 16),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN (4 digits)',
                counterText: '',
              ),
              onSubmitted: (_) => _tryPin(),
            ),
            if (widget.biometricEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _tryBio,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Use Face ID / fingerprint'),
              ),
            ],
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _tryPin,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _old = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _old.dispose();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!AppLockService.isValidPinFormat(_old.text)) {
      setState(() => _err = 'Enter your current 4-digit PIN.');
      return;
    }
    final oldOk = await AppLockService.instance.verifyPin(_old.text);
    if (!mounted) return;
    if (!oldOk) {
      setState(() => _err = 'Current PIN is incorrect.');
      return;
    }
    if (!AppLockService.isValidPinFormat(_a.text)) {
      setState(() => _err = 'New PIN must be 4 digits.');
      return;
    }
    if (_a.text != _b.text) {
      setState(() => _err = 'New PINs do not match.');
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _old,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _a,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New PIN (4 digits)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _b,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm new PIN (4 digits)',
                counterText: '',
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
