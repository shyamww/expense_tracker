import 'package:flutter/material.dart';

/// Placeholder settings; extend as you add preferences (theme, currency, etc.).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';

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
          _SectionHeader(title: 'General'),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: Colors.grey.shade700),
            title: const Text('About'),
            subtitle: Text('Expense Tracker · v$_appVersion'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Expense Tracker',
                applicationVersion: _appVersion,
                applicationLegalese: 'Personal finance data stays on this device unless you export a backup.',
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Track income, expenses, and monthly balance. Backup from the Backup tab when you change devices.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              );
            },
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
            subtitle: const Text('Open the Backup tab in the bottom bar'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Support'),
          ListTile(
            leading: Icon(Icons.feedback_outlined, color: Colors.grey.shade700),
            title: const Text('Send feedback'),
            subtitle: const Text('Ideas and bug reports — link your email or form later'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add a mailto: link or in-app form when you are ready.'),
                ),
              );
            },
          ),
        ],
      ),
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
