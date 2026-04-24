import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/categories.dart';
import '../constants/reporting_category_names.dart';
import '../db/database_helper.dart';
import '../models/expense_category.dart';

class CategoryProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<ExpenseCategory> _allCategories = [];
  List<ExpenseCategory> get categories =>
      List.unmodifiable(_allCategories.where((c) => !c.archived));
  List<ExpenseCategory> get archivedCategories =>
      List.unmodifiable(_allCategories.where((c) => c.archived));

  static const String kReceivedCategoryName = ReportingCategoryNames.received;
  static const String kTransferOutCategoryName =
      ReportingCategoryNames.transferOut;
  static const String kTransferInCategoryName =
      ReportingCategoryNames.transferIn;

  static bool isTransferCategory(String c) =>
      ReportingCategoryNames.isTransferCategory(c);

  static bool countsAsReportSpending(String c) =>
      ReportingCategoryNames.countsAsSpendingInReports(c);

  Future<void> loadCategories({bool notify = true}) async {
    _allCategories = await _db.getExpenseCategories(includeArchived: true);
    if (notify) notifyListeners();
  }

  void forceNotify() => notifyListeners();

  CategoryInfo resolveVisual(String name) {
    for (final c in _allCategories) {
      if (c.name == name) return c.toCategoryInfo();
    }
    return unknownCategoryInfo(name);
  }

  Future<void> addCategory(ExpenseCategory draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) return;
    final order = _allCategories.isEmpty
        ? 0
        : _allCategories.map((e) => e.sortOrder).reduce(max) + 1;
    final row = draft.copyWith(name: name, sortOrder: order);
    try {
      await _db.insertExpenseCategory(row);
    } on DatabaseException {
      throw StateError('duplicate_name');
    } on StateError {
      rethrow;
    }
    await loadCategories();
  }

  Future<void> updateCategory(
    ExpenseCategory updated, {
    required String previousName,
  }) async {
    final name = updated.name.trim();
    if (name.isEmpty) return;
    if (updated.systemLocked && name != previousName) {
      throw StateError('locked_rename');
    }
    try {
      await _db.updateExpenseCategory(
        updated.copyWith(name: name),
        previousName: previousName,
      );
    } on DatabaseException {
      throw StateError('duplicate_name');
    } on StateError {
      rethrow;
    }
    await loadCategories();
  }

  Future<void> deleteCategory(ExpenseCategory c, {String? reassignTo}) async {
    if (c.systemLocked) throw StateError('locked_delete');
    if (c.id == null) return;
    final count = await _db.countExpensesWithCategory(c.name);
    if (count > 0) {
      final target = reassignTo?.trim();
      if (target == null || target.isEmpty || target == c.name) {
        throw StateError('reassign_required');
      }
      await _db.reassignExpensesCategory(fromName: c.name, toName: target);
    }
    await _db.deleteExpenseCategoryById(c.id!);
    await loadCategories();
  }

  Future<void> archiveCategory(ExpenseCategory c) async {
    if (c.systemLocked) throw StateError('locked_archive');
    if (c.id == null) return;
    await _db.setExpenseCategoryArchived(c.id!, true);
    await loadCategories();
  }

  Future<void> restoreCategory(ExpenseCategory c) async {
    if (c.id == null) return;
    await _db.setExpenseCategoryArchived(c.id!, false);
    await loadCategories();
  }

  Future<int> expenseCountFor(String categoryName) =>
      _db.countExpensesWithCategory(categoryName);
}
