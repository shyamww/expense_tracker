import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../core/money.dart';
import '../providers/account_provider.dart';
import '../services/browser_route.dart';
import '../widgets/web_dashboard_shell.dart';
import 'account_detail_screen.dart';

/// Entry from the bottom bar: all accounts; tap one for its ledger.
class AccountsListScreen extends StatefulWidget {
  const AccountsListScreen({super.key});

  @override
  State<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends State<AccountsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountProvider>().refresh();
    });
  }

  Future<void> _openAccount(String accountName) async {
    final accountProvider = context.read<AccountProvider>();
    if (WebDashboardShell.useFor(context)) {
      final route = AppRoutes.accountDetail(accountName);
      pushBrowserRoute(route);
      await Navigator.pushNamed<void>(context, route);
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AccountDetailScreen(accountName: accountName),
        ),
      );
    }
    if (!mounted) return;
    accountProvider.refresh();
  }

  Widget _buildWebAccountsBody(AccountProvider ap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = ap.accounts;
    final totalBalance = list.fold<double>(
        0, (sum, account) => sum + ap.balanceFor(account.name));
    final positiveAccounts =
        list.where((account) => ap.balanceFor(account.name) >= 0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: WebMetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total balance',
                    value:
                        '₹ ${formatRupeesTwoDecimalsFromDouble(totalBalance)}',
                    accent: totalBalance >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WebMetricTile(
                    icon: Icons.account_balance_outlined,
                    label: 'Active accounts',
                    value: '${list.length}',
                    subtitle: '$positiveAccounts with positive balance',
                    accent: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          WebPanel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: list.isEmpty
                ? SizedBox(
                    height: 360,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No accounts yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add accounts in Settings > Accounts.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account ledger',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Open an account to review its transactions.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...list.map((account) {
                        final balance = ap.balanceFor(account.name);
                        return _buildWebAccountRow(
                          accountName: account.name,
                          balance: balance,
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAccountRow({
    required String accountName,
    required double balance,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balanceColor =
        balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _openAccount(accountName),
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap to view account activity',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '₹ ${formatRupeesTwoDecimalsFromDouble(balance)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: balanceColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Consumer<AccountProvider>(
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
                    'Add accounts in Settings → Accounts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final a = list[i];
            final bal = ap.balanceFor(a.name);
            final balColor =
                bal >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
            return Material(
              color: scheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.account_balance_rounded,
                      color: scheme.primary),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '₹${formatRupeesTwoDecimalsFromDouble(bal)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: balColor,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AccountDetailScreen(accountName: a.name),
                    ),
                  );
                  if (context.mounted) {
                    context.read<AccountProvider>().refresh();
                  }
                },
              ),
            );
          },
        );
      },
    );

    if (WebDashboardShell.useFor(context)) {
      return WebDashboardShell(
        selectedRoute: AppRoutes.accounts,
        title: 'Accounts',
        subtitle: 'Review bank, cash, and wallet balances',
        child: Consumer<AccountProvider>(
          builder: (context, ap, _) => _buildWebAccountsBody(ap),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        centerTitle: true,
      ),
      body: body,
    );
  }
}
