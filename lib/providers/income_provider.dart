import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/income.dart';
import '../models/income_entry.dart';

class IncomeProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Income? _currentIncome;
  Income? get currentIncome => _currentIncome;

  double _carryForward = 0.0;
  double get carryForward => _carryForward;

  double get monthlyIncome => _currentIncome?.amount ?? 0.0;

  List<IncomeEntry> _allIncomeHistory = [];
  List<IncomeEntry> get allIncomeHistory => List.unmodifiable(_allIncomeHistory);

  Future<void> loadAllIncomeHistory() async {
    _allIncomeHistory = await _dbHelper.getAllIncomeHistory();
  }

  Future<void> loadIncomeForCurrentMonth() async {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    await loadAllIncomeHistory();
    notifyListeners();
  }

  Future<void> loadIncomeForMonth(String month) async {
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    await loadAllIncomeHistory();
    notifyListeners();
  }

  Future<void> setIncome(
    double amount,
    String month, {
    String note = '',
    DateTime? date,
    String account = '',
  }) async {
    final income = Income(amount: amount, month: month);
    await _dbHelper.upsertIncome(income, note: note, date: date, account: account);
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    await loadAllIncomeHistory();
    notifyListeners();
  }
}
