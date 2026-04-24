import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_account.dart';
import '../providers/account_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        centerTitle: true,
      ),
      body: Consumer<AccountProvider>(
        builder: (context, ap, _) {
          final list = ap.accounts;
          final archived = ap.archivedAccounts;
          if (list.isEmpty && archived.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_outlined,
                        size: 56, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No accounts yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap Add to create a bank or cash account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              ...list.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AccountRow(
                      account: a,
                      onEdit: () => _openEditor(context, a),
                      onArchive: () => _archiveAccount(context, a),
                    ),
                  )),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Archived',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...archived.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AccountRow(
                        account: a,
                        archived: true,
                        onEdit: () => _openEditor(context, a),
                        onArchive: () => _restoreAccount(context, a),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, AppAccount? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AccountEditorSheet(existing: existing),
    );
  }

  Future<void> _archiveAccount(BuildContext context, AppAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Archive account?'),
        content: Text(
          'Archive "${a.name}" so it no longer appears in account pickers? Existing transactions will keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AccountProvider>().archiveAccount(a);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archived "${a.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreAccount(BuildContext context, AppAccount a) async {
    await context.read<AccountProvider>().restoreAccount(a);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored "${a.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final AppAccount account;
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _AccountRow({
    required this.account,
    required this.onEdit,
    required this.onArchive,
    this.archived = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.account_balance_rounded,
              color: scheme.primary, size: 22),
        ),
        title: Text(
          account.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: archived ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        subtitle: archived
            ? Text(
                'Archived',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                color: archived ? scheme.primary : scheme.onSurfaceVariant,
              ),
              tooltip: archived ? 'Restore' : 'Archive',
              onPressed: onArchive,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountEditorSheet extends StatefulWidget {
  final AppAccount? existing;

  const _AccountEditorSheet({this.existing});

  @override
  State<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<_AccountEditorSheet> {
  late final TextEditingController _name;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name')),
      );
      return;
    }

    final provider = context.read<AccountProvider>();
    final expenseProv = context.read<ExpenseProvider>();
    final incomeProv = context.read<IncomeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final draft = AppAccount(
      id: widget.existing?.id,
      name: name,
      sortOrder: widget.existing?.sortOrder ?? 0,
    );

    try {
      if (_isEdit) {
        await provider.updateAccount(draft,
            previousName: widget.existing!.name);
      } else {
        await provider.addAccount(draft);
      }
      if (!mounted) return;
      await expenseProv.loadExpenses();
      if (!mounted) return;
      await incomeProv.loadIncomeForCurrentMonth();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Account updated' : 'Account added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final s = e.toString();
      final msg = s.contains('duplicate_name')
          ? 'An account with this name already exists.'
          : 'Could not save.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit account' : 'New account',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. HDFC Bank, Cash',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isEdit ? 'Save changes' : 'Add account'),
            ),
          ],
        ),
      ),
    );
  }
}
