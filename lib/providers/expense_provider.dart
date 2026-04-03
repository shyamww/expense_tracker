import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  double get totalSpentThisMonth {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    return _expenses
        .where((e) => e.date.startsWith(monthPrefix) && e.category != 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalReceivedThisMonth {
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    return _expenses
        .where((e) => e.date.startsWith(monthPrefix) && e.category == 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);
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
    final Map<String, double> totals = {};
    for (final expense in expenseList) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  double totalSpentForMonth(String monthPrefix) {
    return _expenses
        .where((e) => e.date.startsWith(monthPrefix) && e.category != 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalReceivedForMonth(String monthPrefix) {
    return _expenses
        .where((e) => e.date.startsWith(monthPrefix) && e.category == 'Received')
        .fold(0.0, (sum, e) => sum + e.amount);
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
    final Map<String, ({double spent, double received})> totals = {};
    for (final e in _expenses) {
      if (!e.date.startsWith(monthPrefix)) continue;
      final current = totals[e.date] ?? (spent: 0.0, received: 0.0);
      if (e.category == 'Received') {
        totals[e.date] = (spent: current.spent, received: current.received + e.amount);
      } else {
        totals[e.date] = (spent: current.spent + e.amount, received: current.received);
      }
    }
    return totals;
  }

  Future<Map<String, ({double spent, double received})>> getMonthlyTotalsForYear(int year) async {
    final yearExpenses = await _dbHelper.getExpensesForYear(year);
    final Map<String, ({double spent, double received})> totals = {};

    for (int m = 1; m <= 12; m++) {
      final monthKey = '$year-${m.toString().padLeft(2, '0')}';
      double spent = 0;
      double received = 0;
      for (final e in yearExpenses) {
        if (e.date.startsWith(monthKey)) {
          if (e.category == 'Received') {
            received += e.amount;
          } else {
            spent += e.amount;
          }
        }
      }
      totals[monthKey] = (spent: spent, received: received);
    }
    return totals;
  }
}
