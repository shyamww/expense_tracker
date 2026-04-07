/// P&L vs account-ledger: [Received] is external inflow; transfer legs affect accounts only.
class ReportingCategoryNames {
  ReportingCategoryNames._();

  static const String received = 'Received';
  static const String transferOut = 'To Self';
  static const String transferIn = 'To Self (in)';

  static bool isTransferCategory(String c) =>
      c == transferOut || c == transferIn;

  /// Included in report / monthly "spent" totals (red flow, excl. transfers & Received).
  static bool countsAsSpendingInReports(String c) =>
      c != received && !isTransferCategory(c);

  /// External money received (not internal transfer credit).
  static bool countsAsExternalReceived(String c) => c == received;

  /// Credits the account balance (Received + transfer in).
  static bool creditsExpenseAccountBalance(String c) =>
      c == received || c == transferIn;

  static String get sqlExpenseBalanceCase =>
      "CASE WHEN category IN ('$received', '$transferIn') THEN amount ELSE -amount END";

  /// Rows that must not count toward P&L "spent" / carry-forward spent.
  static String get sqlExcludedFromSpentTotals =>
      "category NOT IN ('$received', '$transferOut', '$transferIn')";
}
