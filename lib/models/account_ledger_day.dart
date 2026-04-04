import 'expense.dart';
import 'income_entry.dart';

/// One calendar day of activity for a single account (expenses + income rows).
class AccountLedgerDay {
  final String date;
  final List<Expense> expenses;
  final List<IncomeEntry> incomeEntries;

  const AccountLedgerDay({
    required this.date,
    required this.expenses,
    required this.incomeEntries,
  });

  int get itemCount => expenses.length + incomeEntries.length;
}

/// Summary + grouped days for the account detail screen.
class AccountMonthLedger {
  final double carryForward;
  final double monthIncome;
  final double monthSpent;
  final List<AccountLedgerDay> days;

  const AccountMonthLedger({
    required this.carryForward,
    required this.monthIncome,
    required this.monthSpent,
    required this.days,
  });

  double get balance => carryForward + monthIncome - monthSpent;
}
