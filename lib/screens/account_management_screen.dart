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
          if (list.isEmpty) {
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = list[i];
              return Material(
                color: scheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.account_balance_rounded,
                        color: scheme.primary, size: 22),
                  ),
                  title: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () => _openEditor(context, a),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, a),
                      ),
                    ],
                  ),
                ),
              );
            },
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

  Future<void> _confirmDelete(BuildContext context, AppAccount a) async {
    final accountProv = context.read<AccountProvider>();
    final expenseProv = context.read<ExpenseProvider>();
    final incomeProv = context.read<IncomeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final expCount = await accountProv.expenseCountFor(a.name);
    final incCount = await accountProv.incomeHistoryCountFor(a.name);
    if (!context.mounted) return;

    String? reassignTo;
    if (expCount + incCount > 0) {
      final others = accountProv.accounts.where((x) => x.id != a.id).toList();
      if (others.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete: $expCount expense(s) and $incCount income row(s), and no other account to move them to.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      var targetAccount = others.first.name;
      final picked = await showDialog<String>(
        context: context,
        builder: (dCtx) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Move transactions first'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$expCount expense(s) and $incCount income entr${incCount == 1 ? 'y' : 'ies'} use "${a.name}". Choose an account to reassign them to:',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetAccount,
                    decoration: const InputDecoration(labelText: 'Move to'),
                    items: others
                        .map(
                          (o) => DropdownMenuItem(
                              value: o.name, child: Text(o.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => targetAccount = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx, targetAccount),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ),
      );
      if (picked == null || picked.isEmpty) return;
      reassignTo = picked;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Delete account?'),
          content: Text('Remove "${a.name}"? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    try {
      await accountProv.deleteAccount(a, reassignTo: reassignTo);
      if (!context.mounted) return;
      await expenseProv.loadExpenses();
      if (!context.mounted) return;
      await incomeProv.loadIncomeForCurrentMonth();
      if (!context.mounted) return;
      await accountProv.refresh();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${a.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (e) {
      if (!context.mounted) return;
      final s = e.toString();
      final msg = s.contains('reassign_required')
          ? 'Pick an account to move transactions to.'
          : 'Could not delete account.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
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
