import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/income.dart';

class IncomeProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Income? _currentIncome;
  Income? get currentIncome => _currentIncome;

  double _carryForward = 0.0;
  double get carryForward => _carryForward;

  double get monthlyIncome => _currentIncome?.amount ?? 0.0;

  Future<void> loadIncomeForCurrentMonth() async {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    notifyListeners();
  }

  Future<void> loadIncomeForMonth(String month) async {
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    notifyListeners();
  }

  Future<void> setIncome(double amount, String month, {String note = '', DateTime? date}) async {
    final income = Income(amount: amount, month: month);
    await _dbHelper.upsertIncome(income, note: note, date: date);
    _currentIncome = await _dbHelper.getIncomeForMonth(month);
    _carryForward = await _dbHelper.getCarryForwardForMonth(month);
    notifyListeners();
  }
}
