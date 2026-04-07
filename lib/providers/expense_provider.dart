import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../constants/reporting_category_names.dart';
import '../core/money.dart';
import '../core/transfer_note.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  double get totalSpentThisMonth {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final paisa = _expenses
        .where((e) =>
            e.date.startsWith(monthPrefix) &&
            ReportingCategoryNames.countsAsSpendingInReports(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    return rupeesFromPaisa(paisa);
  }

  double get totalReceivedThisMonth {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final paisa = _expenses
        .where((e) =>
            e.date.startsWith(monthPrefix) &&
            ReportingCategoryNames.countsAsExternalReceived(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    return rupeesFromPaisa(paisa);
  }

  Future<void> loadExpenses() async {
    _expenses = await _dbHelper.getAllExpenses();
    notifyListeners();
  }

  Future<void> loadExpensesForMonth(String month) async {
    _expenses = await _dbHelper.getExpensesByMonth(month);
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _dbHelper.insertExpense(expense);
    await loadExpenses();
  }

  /// Internal account-to-account move: excluded from income/expense reports; both legs share a note prefix for paired delete.
  Future<void> addInternalTransfer({
    required int amountPaisa,
    required String fromAccount,
    required String toAccount,
    required String dateYmd,
    required String createdAtIso,
    String userNote = '',
  }) async {
    if (fromAccount == toAccount) return;
    final prefix = makeTransferNotePrefix();
    final extra = userNote.trim().isEmpty ? '' : ' · ${userNote.trim()}';
    final outNote = '$prefix → $toAccount$extra';
    final inNote = '$prefix ← $fromAccount$extra';
    await _dbHelper.insertExpense(Expense(
      amount: amountPaisa,
      category: ReportingCategoryNames.transferOut,
      account: fromAccount,
      note: outNote,
      date: dateYmd,
      createdAt: createdAtIso,
    ));
    await _dbHelper.insertExpense(Expense(
      amount: amountPaisa,
      category: ReportingCategoryNames.transferIn,
      account: toAccount,
      note: inNote,
      date: dateYmd,
      createdAt: createdAtIso,
    ));
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await _dbHelper.deleteExpense(id);
    await loadExpenses();
  }

  Future<List<Expense>> getExpensesByDateRange(String from, String to) async {
    return await _dbHelper.getExpensesByDateRange(from, to);
  }

  Map<String, double> getCategoryTotals(List<Expense> expenseList) {
    final Map<String, int> paisaByCat = {};
    for (final expense in expenseList) {
      paisaByCat[expense.category] =
          (paisaByCat[expense.category] ?? 0) + expense.amount;
    }
    return {
      for (final e in paisaByCat.entries) e.key: rupeesFromPaisa(e.value),
    };
  }

  double totalSpentForMonth(String monthPrefix) {
    final paisa = _expenses
        .where((e) =>
            e.date.startsWith(monthPrefix) &&
            ReportingCategoryNames.countsAsSpendingInReports(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    return rupeesFromPaisa(paisa);
  }

  double totalReceivedForMonth(String monthPrefix) {
    final paisa = _expenses
        .where((e) =>
            e.date.startsWith(monthPrefix) &&
            ReportingCategoryNames.countsAsExternalReceived(e.category))
        .fold<int>(0, (sum, e) => sum + e.amount);
    return rupeesFromPaisa(paisa);
  }

  List<Expense> expensesForMonth(String monthPrefix) {
    return _expenses
        .where((e) => e.date.startsWith(monthPrefix))
        .toList();
  }

  Map<String, List<Expense>> getExpensesGroupedByDay(String monthPrefix) {
    final Map<String, List<Expense>> grouped = {};
    for (final e in _expenses) {
      if (e.date.startsWith(monthPrefix)) {
        grouped.putIfAbsent(e.date, () => []).add(e);
      }
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return grouped;
  }

  Map<String, ({double spent, double received})> getDailyTotals(String monthPrefix) {
    final Map<String, ({int spent, int received})> raw = {};
    for (final e in _expenses) {
      if (!e.date.startsWith(monthPrefix)) continue;
      final current = raw[e.date] ?? (spent: 0, received: 0);
      if (ReportingCategoryNames.countsAsExternalReceived(e.category)) {
        raw[e.date] = (spent: current.spent, received: current.received + e.amount);
      } else if (ReportingCategoryNames.countsAsSpendingInReports(e.category)) {
        raw[e.date] = (spent: current.spent + e.amount, received: current.received);
      }
    }
    return {
      for (final e in raw.entries)
        e.key: (
          spent: rupeesFromPaisa(e.value.spent),
          received: rupeesFromPaisa(e.value.received),
        ),
    };
  }

  Future<Map<String, ({double spent, double received})>> getMonthlyTotalsForYear(int year) async {
    final yearExpenses = await _dbHelper.getExpensesForYear(year);
    final Map<String, ({double spent, double received})> totals = {};

    for (int m = 1; m <= 12; m++) {
      final monthKey = '$year-${m.toString().padLeft(2, '0')}';
      var spentPaisa = 0;
      var receivedPaisa = 0;
      for (final e in yearExpenses) {
        if (e.date.startsWith(monthKey)) {
          if (ReportingCategoryNames.countsAsExternalReceived(e.category)) {
            receivedPaisa += e.amount;
          } else if (ReportingCategoryNames.countsAsSpendingInReports(e.category)) {
            spentPaisa += e.amount;
          }
        }
      }
      totals[monthKey] = (
        spent: rupeesFromPaisa(spentPaisa),
        received: rupeesFromPaisa(receivedPaisa),
      );
    }
    return totals;
  }
}
