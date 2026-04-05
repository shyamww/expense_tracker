import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/account_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
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
                    Icon(Icons.account_balance_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No accounts yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add accounts in Settings → Accounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
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
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Icon(Icons.account_balance_rounded, color: Colors.indigo.shade700),
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
                        '₹${bal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: balColor,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
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
      ),
    );
  }
}
