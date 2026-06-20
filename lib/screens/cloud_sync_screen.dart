import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../db/database_helper.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/cloud_auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../widgets/web_dashboard_shell.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshAppData() async {
    await DatabaseHelper().reconnectCloudStore();
    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    await Future.wait([
      expenseProvider.loadExpenses(notify: false),
      incomeProvider.loadIncomeForCurrentMonth(notify: false),
      categoryProvider.loadCategories(notify: false),
      accountProvider.refresh(notify: false),
    ]);
    expenseProvider.forceNotify();
    incomeProvider.forceNotify();
    categoryProvider.forceNotify();
    accountProvider.forceNotify();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _message = 'Enter an email and a 6+ character password.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final auth = context.read<CloudAuthProvider>();
      if (_createAccount) {
        await auth.signUp(email: email, password: password);
      } else {
        await auth.signIn(email: email, password: password);
      }
      await _refreshAppData();
      if (!mounted) return;
      final err = DatabaseHelper().cloudSyncError;
      setState(() {
        _message = err ??
            (auth.isSignedIn
                ? 'Cloud sync is connected.'
                : 'Check your email, then sign in.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _refreshAppData();
      if (!mounted) return;
      final err = DatabaseHelper().cloudSyncError;
      setState(() {
        _message = err ?? 'Cloud sync is up to date.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<CloudAuthProvider>().signOut();
      await DatabaseHelper().reconnectCloudStore();
      if (!mounted) return;
      setState(() => _message = 'Signed out.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (text.contains('User already registered')) {
      return 'That account already exists. Sign in instead.';
    }
    if (text.contains('supabase_not_configured')) {
      return 'Cloud sync is not configured in this build.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (WebDashboardShell.useFor(context)) {
      return WebDashboardShell(
        selectedRoute: AppRoutes.settings,
        title: 'Cloud Sync',
        subtitle: 'Supabase account',
        child: SingleChildScrollView(child: body),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: body,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final auth = context.watch<CloudAuthProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!auth.isConfigured) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Cloud sync is not configured in this build.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final setupError = auth.setupError;
    if (setupError != null) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'Cloud sync could not start.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              setupError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.primary,
                    child: Icon(
                      auth.isSignedIn
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_queue_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      auth.isSignedIn
                          ? auth.email ?? 'Signed in'
                          : 'Sign in to Supabase',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (auth.isSignedIn) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _syncNow,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Sync now'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ] else ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.login_rounded),
                      label: Text('Sign in'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.person_add_alt_1_rounded),
                      label: Text('Create'),
                    ),
                  ],
                  selected: {_createAccount},
                  onSelectionChanged: _busy
                      ? null
                      : (values) {
                          setState(() => _createAccount = values.first);
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _createAccount
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                        ),
                  label: Text(_createAccount ? 'Create account' : 'Sign in'),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _message!.contains('connected') ||
                            _message!.contains('up to date') ||
                            _message == 'Signed out.'
                        ? scheme.primary
                        : scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}
