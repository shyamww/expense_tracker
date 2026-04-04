import '../models/app_account.dart';

/// Default bank-style accounts for new installs and migrations.
List<AppAccount> buildSeededAccounts() {
  return const [
    AppAccount(name: 'HDFC Bank', sortOrder: 0),
    AppAccount(name: 'ICICI Bank', sortOrder: 1),
    AppAccount(name: 'State Bank of India', sortOrder: 2),
    AppAccount(name: 'Cash', sortOrder: 3),
  ];
}
