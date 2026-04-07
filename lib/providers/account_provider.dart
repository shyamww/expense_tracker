import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/money.dart';
import '../db/database_helper.dart';
import '../models/app_account.dart';

class AccountProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<AppAccount> _accounts = [];
  double _cumulativeBalance = 0;
  Map<String, int> _balancesByAccount = {};

  List<AppAccount> get accounts => List.unmodifiable(_accounts);
  double get cumulativeBalance => _cumulativeBalance;

  /// Net balance for [accountName] in rupees (income + Received − other expenses).
  double balanceFor(String accountName) => rupeesFromPaisa(
        _balancesByAccount[accountName] ?? 0,
      );

  Future<void> refresh({bool notify = true}) async {
    _accounts = await _db.getAccounts();
    _cumulativeBalance = await _db.getCumulativeAccountBalance();
    _balancesByAccount = await _db.getPerAccountBalances();
    if (notify) notifyListeners();
  }

  void forceNotify() => notifyListeners();

  Future<void> addAccount(AppAccount draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) return;
    final order = _accounts.isEmpty
        ? 0
        : _accounts.map((e) => e.sortOrder).reduce(max) + 1;
    final row = draft.copyWith(name: name, sortOrder: order);
    try {
      await _db.insertAccount(row);
    } on DatabaseException {
      throw StateError('duplicate_name');
    } on StateError {
      rethrow;
    }
    await refresh();
  }

  Future<void> updateAccount(
    AppAccount updated, {
    required String previousName,
  }) async {
    final name = updated.name.trim();
    if (name.isEmpty) return;
    try {
      await _db.updateAccount(
        updated.copyWith(name: name),
        previousName: previousName,
      );
    } on DatabaseException {
      throw StateError('duplicate_name');
    } on StateError {
      rethrow;
    }
    await refresh();
  }

  Future<void> deleteAccount(AppAccount a, {String? reassignTo}) async {
    if (a.id == null) return;
    final expCount = await _db.countExpensesWithAccount(a.name);
    final incCount = await _db.countIncomeHistoryWithAccount(a.name);
    final totalRefs = expCount + incCount;
    if (totalRefs > 0) {
      final target = reassignTo?.trim();
      if (target == null || target.isEmpty || target == a.name) {
        throw StateError('reassign_required');
      }
      await _db.reassignExpensesAccount(fromName: a.name, toName: target);
      await _db.reassignIncomeHistoryAccount(fromName: a.name, toName: target);
    }
    await _db.deleteAccountById(a.id!);
    await refresh();
  }

  Future<int> expenseCountFor(String accountName) =>
      _db.countExpensesWithAccount(accountName);

  Future<int> incomeHistoryCountFor(String accountName) =>
      _db.countIncomeHistoryWithAccount(accountName);
}
