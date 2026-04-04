import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/expense_reminder_service.dart';
import '../widgets/feedback_form_sheet.dart';
import 'backup_screen.dart';
import 'category_management_screen.dart';
import 'account_management_screen.dart';

/// Placeholder settings; extend as you add preferences (theme, currency, etc.).
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
              leading: Icon(Icons.notifications_off_outlined, color: Colors.grey.shade700),
              title: const Text('Daily reminder'),
              subtitle: const Text('Not available on web'),
            )
          else
            const _DailyReminderSettings(),
          const Divider(height: 1),
          _SectionHeader(title: 'General'),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: Colors.grey.shade700),
            title: const Text('App info'),
            subtitle: const Text('Version, developer, and details'),
            onTap: () => _showAppInfoDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: Colors.grey.shade700),
            title: const Text('Appearance'),
            subtitle: const Text('Theme & display — coming soon'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme options will be added here.')),
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
                MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_outlined, color: Colors.grey.shade700),
            title: const Text('Accounts'),
            subtitle: const Text('Banks and cash — used when adding income or expenses'),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
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
            subtitle: const Text('Sent with Web3Forms — your inbox is not in the app'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          secondary: Icon(Icons.notifications_active_outlined, color: Colors.grey.shade700),
          title: const Text('Daily reminder'),
          subtitle: Text(
            _enabled
                ? 'Tap below to change time · ${_formatTime(context)}'
                : 'Nudge to add today\'s expenses',
          ),
          value: _enabled,
          onChanged: (v) async {
            await ExpenseReminderService.instance.setReminderEnabled(v);
            if (mounted) {
              setState(() => _enabled = v);
              if (v) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reminder scheduled for ${_formatTime(context)}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
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
