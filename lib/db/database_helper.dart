import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_entry.dart';
import '../models/expense_category.dart';
import '../models/app_account.dart';
import '../models/account_ledger_day.dart';
import '../data/category_seed_data.dart';
import '../data/account_seed_data.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // ── Web in-memory storage ──
  final List<Map<String, dynamic>> _webExpenses = [];
  final List<Map<String, dynamic>> _webIncome = [];
  final List<Map<String, dynamic>> _webIncomeHistory = [];
  final List<Map<String, dynamic>> _webExpenseCategories = [];
  final List<Map<String, dynamic>> _webAccounts = [];
  int _nextExpenseId = 1;
  int _nextIncomeId = 1;
  int _nextIncomeHistoryId = 1;
  int _nextCategoryId = 1;
  int _nextAccountId = 1;

  // ── Mobile SQLite ──
  Database? _database;

  Future<Database> _getDb() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'expense_tracker.db');
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        account TEXT NOT NULL DEFAULT '',
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        month TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE income_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        month TEXT NOT NULL,
        account TEXT NOT NULL DEFAULT '',
        note TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon_code_point INTEGER NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        system_locked INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _insertSeedExpenseCategories(db);
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _insertSeedAccounts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS income_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          month TEXT NOT NULL,
          note TEXT DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          icon_code_point INTEGER NOT NULL,
          color INTEGER NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          system_locked INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await _insertSeedExpenseCategories(db);
      await _ensureExpenseCategoryRowsForOrphans(db);
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await _insertSeedAccounts(db);
      try {
        await db.execute(
          "ALTER TABLE expenses ADD COLUMN account TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {
        // Column may already exist on repeated runs
      }
      try {
        await db.execute(
          "ALTER TABLE income_history ADD COLUMN account TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
    }
  }

  Future<void> _insertSeedAccounts(DatabaseExecutor db) async {
    for (final a in buildSeededAccounts()) {
      await db.rawInsert(
        '''
        INSERT OR IGNORE INTO accounts (name, sort_order)
        VALUES (?, ?)
        ''',
        [a.name, a.sortOrder],
      );
    }
  }

  Future<void> _insertSeedExpenseCategories(DatabaseExecutor db) async {
    for (final c in buildSeededExpenseCategories()) {
      await db.rawInsert(
        '''
        INSERT OR IGNORE INTO expense_categories (name, icon_code_point, color, sort_order, system_locked)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [
          c.name,
          c.iconCodePoint,
          c.colorValue,
          c.sortOrder,
          c.systemLocked ? 1 : 0,
        ],
      );
    }
  }

  Future<void> _ensureExpenseCategoryRowsForOrphans(DatabaseExecutor db) async {
    final dist = await db.rawQuery('SELECT DISTINCT category FROM expenses');
    final existing = await db.query('expense_categories');
    final names = existing.map((m) => m['name'] as String).toSet();
    var maxOrder = 0;
    for (final r in existing) {
      final o = (r['sort_order'] as num?)?.toInt() ?? 0;
      if (o > maxOrder) maxOrder = o;
    }
    for (final r in dist) {
      final cat = r['category'] as String;
      if (cat.isEmpty || names.contains(cat)) continue;
      maxOrder++;
      await db.insert('expense_categories', {
        'name': cat,
        'icon_code_point': kUnknownCategoryIconCodePoint,
        'color': 0xFF78909C,
        'sort_order': maxOrder,
        'system_locked': 0,
      });
      names.add(cat);
    }
  }

  // ── Expense categories ──

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    if (kIsWeb) {
      if (_webExpenseCategories.isEmpty) {
        for (final c in buildSeededExpenseCategories()) {
          _webExpenseCategories.add({
            'id': _nextCategoryId++,
            'name': c.name,
            'icon_code_point': c.iconCodePoint,
            'color': c.colorValue,
            'sort_order': c.sortOrder,
            'system_locked': c.systemLocked ? 1 : 0,
          });
        }
      }
      final sorted = List<Map<String, dynamic>>.from(_webExpenseCategories)
        ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
      return sorted.map((m) => ExpenseCategory.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query('expense_categories', orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => ExpenseCategory.fromMap(m)).toList();
  }

  Future<int> insertExpenseCategory(ExpenseCategory c) async {
    final row = {
      'name': c.name.trim(),
      'icon_code_point': c.iconCodePoint,
      'color': c.colorValue,
      'sort_order': c.sortOrder,
      'system_locked': c.systemLocked ? 1 : 0,
    };
    if (kIsWeb) {
      if (_webExpenseCategories.any((m) => (m['name'] as String) == row['name'])) {
        throw StateError('duplicate_name');
      }
      final map = Map<String, dynamic>.from(row);
      map['id'] = _nextCategoryId++;
      _webExpenseCategories.add(map);
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('expense_categories', row);
  }

  Future<void> updateExpenseCategory(ExpenseCategory c, {required String previousName}) async {
    if (c.id == null) return;
    final row = {
      'name': c.name.trim(),
      'icon_code_point': c.iconCodePoint,
      'color': c.colorValue,
      'sort_order': c.sortOrder,
      'system_locked': c.systemLocked ? 1 : 0,
    };
    if (kIsWeb) {
      final idx = _webExpenseCategories.indexWhere((m) => m['id'] == c.id);
      if (idx == -1) return;
      final trimmed = c.name.trim();
      final dup = _webExpenseCategories.any(
        (m) => m['id'] != c.id && (m['name'] as String) == trimmed,
      );
      if (dup) throw StateError('duplicate_name');
      _webExpenseCategories[idx] = {...row, 'id': c.id};
      if (previousName != trimmed) {
        for (final e in _webExpenses) {
          if (e['category'] == previousName) e['category'] = trimmed;
        }
      }
      return;
    }
    final db = await _getDb();
    await db.transaction((txn) async {
      if (previousName != c.name.trim()) {
        await txn.update(
          'expenses',
          {'category': c.name.trim()},
          where: 'category = ?',
          whereArgs: [previousName],
        );
      }
      await txn.update(
        'expense_categories',
        row,
        where: 'id = ?',
        whereArgs: [c.id],
      );
    });
  }

  Future<int> countExpensesWithCategory(String categoryName) async {
    if (kIsWeb) {
      return _webExpenses.where((m) => m['category'] == categoryName).length;
    }
    final db = await _getDb();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as n FROM expenses WHERE category = ?',
      [categoryName],
    );
    final raw = r.first['n'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<void> reassignExpensesCategory({
    required String fromName,
    required String toName,
  }) async {
    if (kIsWeb) {
      for (final e in _webExpenses) {
        if (e['category'] == fromName) e['category'] = toName;
      }
      return;
    }
    final db = await _getDb();
    await db.update(
      'expenses',
      {'category': toName},
      where: 'category = ?',
      whereArgs: [fromName],
    );
  }

  Future<void> deleteExpenseCategoryById(int id) async {
    if (kIsWeb) {
      _webExpenseCategories.removeWhere((m) => m['id'] == id);
      return;
    }
    final db = await _getDb();
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Accounts (banks / cash) ──

  Future<List<AppAccount>> getAccounts() async {
    if (kIsWeb) {
      if (_webAccounts.isEmpty) {
        for (final a in buildSeededAccounts()) {
          _webAccounts.add({
            'id': _nextAccountId++,
            'name': a.name,
            'sort_order': a.sortOrder,
          });
        }
      }
      final sorted = List<Map<String, dynamic>>.from(_webAccounts)
        ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
      return sorted.map((m) => AppAccount.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query('accounts', orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => AppAccount.fromMap(m)).toList();
  }

  Future<int> insertAccount(AppAccount a) async {
    final row = {
      'name': a.name.trim(),
      'sort_order': a.sortOrder,
    };
    if (kIsWeb) {
      if (_webAccounts.any((m) => (m['name'] as String) == row['name'])) {
        throw StateError('duplicate_name');
      }
      final map = Map<String, dynamic>.from(row);
      map['id'] = _nextAccountId++;
      _webAccounts.add(map);
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('accounts', row);
  }

  Future<void> updateAccount(AppAccount a, {required String previousName}) async {
    if (a.id == null) return;
    final row = {
      'name': a.name.trim(),
      'sort_order': a.sortOrder,
    };
    if (kIsWeb) {
      final idx = _webAccounts.indexWhere((m) => m['id'] == a.id);
      if (idx == -1) return;
      final trimmed = a.name.trim();
      final dup = _webAccounts.any(
        (m) => m['id'] != a.id && (m['name'] as String) == trimmed,
      );
      if (dup) throw StateError('duplicate_name');
      _webAccounts[idx] = {...row, 'id': a.id};
      if (previousName != trimmed) {
        for (final e in _webExpenses) {
          if (e['account'] == previousName) e['account'] = trimmed;
        }
        for (final h in _webIncomeHistory) {
          if (h['account'] == previousName) h['account'] = trimmed;
        }
      }
      return;
    }
    final db = await _getDb();
    await db.transaction((txn) async {
      if (previousName != a.name.trim()) {
        await txn.update(
          'expenses',
          {'account': a.name.trim()},
          where: 'account = ?',
          whereArgs: [previousName],
        );
        await txn.update(
          'income_history',
          {'account': a.name.trim()},
          where: 'account = ?',
          whereArgs: [previousName],
        );
      }
      await txn.update(
        'accounts',
        row,
        where: 'id = ?',
        whereArgs: [a.id],
      );
    });
  }

  Future<int> countExpensesWithAccount(String accountName) async {
    if (kIsWeb) {
      return _webExpenses.where((m) => m['account'] == accountName).length;
    }
    final db = await _getDb();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as n FROM expenses WHERE account = ?',
      [accountName],
    );
    final raw = r.first['n'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<int> countIncomeHistoryWithAccount(String accountName) async {
    if (kIsWeb) {
      return _webIncomeHistory.where((m) => m['account'] == accountName).length;
    }
    final db = await _getDb();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as n FROM income_history WHERE account = ?',
      [accountName],
    );
    final raw = r.first['n'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<void> reassignExpensesAccount({
    required String fromName,
    required String toName,
  }) async {
    if (kIsWeb) {
      for (final e in _webExpenses) {
        if (e['account'] == fromName) e['account'] = toName;
      }
      return;
    }
    final db = await _getDb();
    await db.update(
      'expenses',
      {'account': toName},
      where: 'account = ?',
      whereArgs: [fromName],
    );
  }

  Future<void> reassignIncomeHistoryAccount({
    required String fromName,
    required String toName,
  }) async {
    if (kIsWeb) {
      for (final h in _webIncomeHistory) {
        if (h['account'] == fromName) h['account'] = toName;
      }
      return;
    }
    final db = await _getDb();
    await db.update(
      'income_history',
      {'account': toName},
      where: 'account = ?',
      whereArgs: [fromName],
    );
  }

  Future<void> deleteAccountById(int id) async {
    if (kIsWeb) {
      _webAccounts.removeWhere((m) => m['id'] == id);
      return;
    }
    final db = await _getDb();
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// Sum of all account balances: income credits and "Received" expenses credit;
  /// other expenses debit. Only rows with a non-empty [Expense.account] / [IncomeEntry.account] count.
  Future<double> getCumulativeAccountBalance() async {
    if (kIsWeb) {
      var total = 0.0;
      for (final e in _webExpenses) {
        final acct = e['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        final amt = (e['amount'] as num).toDouble();
        final cat = e['category'] as String? ?? '';
        if (cat == 'Received') {
          total += amt;
        } else {
          total -= amt;
        }
      }
      for (final h in _webIncomeHistory) {
        final acct = h['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        total += (h['amount'] as num).toDouble();
      }
      return total;
    }
    final db = await _getDb();
    final exp = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN category = 'Received' THEN amount ELSE -amount END), 0) AS t
      FROM expenses
      WHERE IFNULL(account, '') != ''
    ''');
    final inc = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS t
      FROM income_history
      WHERE IFNULL(account, '') != ''
    ''');
    final expTotal = (exp.first['t'] as num).toDouble();
    final incTotal = (inc.first['t'] as num).toDouble();
    return expTotal + incTotal;
  }

  // ── Expense CRUD ──

  Future<int> insertExpense(Expense expense) async {
    if (kIsWeb) {
      final map = Map<String, dynamic>.from(expense.toMap());
      map['id'] = _nextExpenseId++;
      _webExpenses.add(map);
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('expenses', expense.toMap());
  }

  int _compareExpenseRowDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dateCmp = (b['date'] as String).compareTo(a['date'] as String);
    if (dateCmp != 0) return dateCmp;
    return (b['created_at'] as String).compareTo(a['created_at'] as String);
  }

  Future<List<Expense>> getAllExpenses() async {
    if (kIsWeb) {
      final sorted = List<Map<String, dynamic>>.from(_webExpenses)
        ..sort(_compareExpenseRowDesc);
      return sorted.map((m) => Expense.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query('expenses', orderBy: 'date DESC, created_at DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesByMonth(String month) async {
    if (kIsWeb) {
      final filtered = _webExpenses
          .where((m) => (m['date'] as String).startsWith(month))
          .toList()
        ..sort(_compareExpenseRowDesc);
      return filtered.map((m) => Expense.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'expenses',
      where: "date LIKE ?",
      whereArgs: ['$month%'],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(String from, String to) async {
    if (kIsWeb) {
      final filtered = _webExpenses.where((m) {
        final date = m['date'] as String;
        return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
      }).toList()
        ..sort(_compareExpenseRowDesc);
      return filtered.map((m) => Expense.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    if (kIsWeb) {
      final index = _webExpenses.indexWhere((m) => m['id'] == expense.id);
      if (index != -1) {
        _webExpenses[index] = Map<String, dynamic>.from(expense.toMap());
        _webExpenses[index]['id'] = expense.id;
      }
      return index != -1 ? 1 : 0;
    }
    final db = await _getDb();
    return await db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    if (kIsWeb) {
      final len = _webExpenses.length;
      _webExpenses.removeWhere((m) => m['id'] == id);
      return len - _webExpenses.length;
    }
    final db = await _getDb();
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ── Income CRUD ──

  Future<int> upsertIncome(
    Income income, {
    String note = '',
    DateTime? date,
    String account = '',
  }) async {
    final entry = IncomeEntry(
      amount: income.amount,
      month: income.month,
      account: account,
      note: note,
      createdAt: date?.toIso8601String(),
    );
    await _insertIncomeHistory(entry);

    if (kIsWeb) {
      final index = _webIncome.indexWhere((m) => m['month'] == income.month);
      if (index != -1) {
        final oldAmount = (_webIncome[index]['amount'] as num).toDouble();
        _webIncome[index]['amount'] = oldAmount + income.amount;
        return 1;
      } else {
        final map = Map<String, dynamic>.from(income.toMap());
        map['id'] = _nextIncomeId++;
        _webIncome.add(map);
        return map['id'] as int;
      }
    }
    final db = await _getDb();
    final existing = await db.query('income',
        where: 'month = ?', whereArgs: [income.month]);
    if (existing.isNotEmpty) {
      final oldAmount = (existing.first['amount'] as num).toDouble();
      final newAmount = oldAmount + income.amount;
      return await db.update('income', {'amount': newAmount},
          where: 'month = ?', whereArgs: [income.month]);
    } else {
      return await db.insert('income', income.toMap());
    }
  }

  // ── Income History ──

  Future<int> _insertIncomeHistory(IncomeEntry entry) async {
    if (kIsWeb) {
      final map = Map<String, dynamic>.from(entry.toMap());
      map['id'] = _nextIncomeHistoryId++;
      _webIncomeHistory.add(map);
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('income_history', entry.toMap());
  }

  Future<List<IncomeEntry>> getIncomeHistoryForMonth(String month) async {
    if (kIsWeb) {
      final filtered = _webIncomeHistory
          .where((m) => m['month'] == month)
          .toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return filtered.map((m) => IncomeEntry.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'income_history',
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => IncomeEntry.fromMap(m)).toList();
  }

  Future<List<IncomeEntry>> getAllIncomeHistory() async {
    if (kIsWeb) {
      final sorted = List<Map<String, dynamic>>.from(_webIncomeHistory)
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return sorted.map((m) => IncomeEntry.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query('income_history', orderBy: 'created_at DESC');
    return maps.map((m) => IncomeEntry.fromMap(m)).toList();
  }

  Future<IncomeEntry?> getIncomeHistoryById(int id) async {
    if (kIsWeb) {
      try {
        final m = _webIncomeHistory.firstWhere((e) => e['id'] == id);
        return IncomeEntry.fromMap(m);
      } catch (_) {
        return null;
      }
    }
    final db = await _getDb();
    final maps = await db.query('income_history', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return IncomeEntry.fromMap(maps.first);
  }

  /// Rebuilds [income] row for [month] from the sum of [income_history] rows.
  Future<void> _recomputeIncomeAggregateForMonth(String month) async {
    if (kIsWeb) {
      final sum = _webIncomeHistory
          .where((m) => m['month'] == month)
          .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());
      final idx = _webIncome.indexWhere((m) => m['month'] == month);
      if (sum == 0) {
        if (idx != -1) _webIncome.removeAt(idx);
      } else if (idx != -1) {
        _webIncome[idx]['amount'] = sum;
      } else {
        _webIncome.add({'id': _nextIncomeId++, 'month': month, 'amount': sum});
      }
      return;
    }
    final db = await _getDb();
    final maps = await db.query('income_history', where: 'month = ?', whereArgs: [month]);
    var total = 0.0;
    for (final m in maps) {
      total += (m['amount'] as num).toDouble();
    }
    final existing = await db.query('income', where: 'month = ?', whereArgs: [month]);
    if (total == 0) {
      if (existing.isNotEmpty) {
        await db.delete('income', where: 'month = ?', whereArgs: [month]);
      }
    } else if (existing.isNotEmpty) {
      await db.update('income', {'amount': total}, where: 'month = ?', whereArgs: [month]);
    } else {
      await db.insert('income', {'amount': total, 'month': month});
    }
  }

  Future<void> updateIncomeHistoryEntry(IncomeEntry entry) async {
    if (entry.id == null) return;
    final old = await getIncomeHistoryById(entry.id!);
    if (old == null) return;
    final oldMonth = old.month;

    if (kIsWeb) {
      final idx = _webIncomeHistory.indexWhere((m) => m['id'] == entry.id);
      if (idx == -1) return;
      _webIncomeHistory[idx] = {
        'id': entry.id,
        'amount': entry.amount,
        'month': entry.month,
        'account': entry.account,
        'note': entry.note,
        'created_at': entry.createdAt,
      };
      await _recomputeIncomeAggregateForMonth(oldMonth);
      if (oldMonth != entry.month) {
        await _recomputeIncomeAggregateForMonth(entry.month);
      }
      return;
    }
    final db = await _getDb();
    await db.update(
      'income_history',
      {
        'amount': entry.amount,
        'month': entry.month,
        'account': entry.account,
        'note': entry.note,
        'created_at': entry.createdAt,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await _recomputeIncomeAggregateForMonth(oldMonth);
    if (oldMonth != entry.month) {
      await _recomputeIncomeAggregateForMonth(entry.month);
    }
  }

  Future<void> deleteIncomeHistoryEntry(int id) async {
    final old = await getIncomeHistoryById(id);
    if (old == null) return;
    final month = old.month;

    if (kIsWeb) {
      _webIncomeHistory.removeWhere((m) => m['id'] == id);
      await _recomputeIncomeAggregateForMonth(month);
      return;
    }
    final db = await _getDb();
    await db.delete('income_history', where: 'id = ?', whereArgs: [id]);
    await _recomputeIncomeAggregateForMonth(month);
  }

  Future<Income?> getIncomeForMonth(String month) async {
    if (kIsWeb) {
      final match = _webIncome.where((m) => m['month'] == month).toList();
      if (match.isNotEmpty) return Income.fromMap(match.first);
      return null;
    }
    final db = await _getDb();
    final maps =
        await db.query('income', where: 'month = ?', whereArgs: [month]);
    if (maps.isNotEmpty) return Income.fromMap(maps.first);
    return null;
  }

  // ── Carry-forward ──

  Future<double> getCarryForwardForMonth(String month) async {
    // Sum all (income + received - spent) for every month before `month`
    final firstDay = '$month-01';
    double totalIncome = 0;
    double totalSpent = 0;
    double totalReceived = 0;

    if (kIsWeb) {
      for (final m in _webIncome) {
        if ((m['month'] as String).compareTo(month) < 0) {
          totalIncome += (m['amount'] as num).toDouble();
        }
      }
      for (final e in _webExpenses) {
        if ((e['date'] as String).compareTo(firstDay) < 0) {
          if (e['category'] == 'Received') {
            totalReceived += (e['amount'] as num).toDouble();
          } else {
            totalSpent += (e['amount'] as num).toDouble();
          }
        }
      }
    } else {
      final db = await _getDb();
      final incomeResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM income WHERE month < ?',
        [month],
      );
      totalIncome = (incomeResult.first['total'] as num).toDouble();

      final spentResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date < ? AND category != 'Received'",
        [firstDay],
      );
      totalSpent = (spentResult.first['total'] as num).toDouble();

      final receivedResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date < ? AND category = 'Received'",
        [firstDay],
      );
      totalReceived = (receivedResult.first['total'] as num).toDouble();
    }

    return totalIncome + totalReceived - totalSpent;
  }

  /// Net balance brought into [month] for [account] (income_history with month \< M
  /// plus expenses on this account with date \< first day of [month]).
  Future<double> getAccountCarryForwardForMonth(String account, String month) async {
    if (account.isEmpty) return 0;
    final firstDay = '$month-01';
    double fromIncomeHistory = 0;
    double fromExpenses = 0;

    if (kIsWeb) {
      for (final h in _webIncomeHistory) {
        if ((h['account'] as String? ?? '') != account) continue;
        if ((h['month'] as String).compareTo(month) < 0) {
          fromIncomeHistory += (h['amount'] as num).toDouble();
        }
      }
      for (final e in _webExpenses) {
        if ((e['account'] as String? ?? '') != account) continue;
        if ((e['date'] as String).compareTo(firstDay) >= 0) continue;
        final amt = (e['amount'] as num).toDouble();
        if (e['category'] == 'Received') {
          fromExpenses += amt;
        } else {
          fromExpenses -= amt;
        }
      }
    } else {
      final db = await _getDb();
      final inc = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM income_history WHERE account = ? AND month < ?',
        [account, month],
      );
      fromIncomeHistory = (inc.first['t'] as num).toDouble();
      final exp = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(CASE WHEN category = 'Received' THEN amount ELSE -amount END), 0) AS t
        FROM expenses WHERE account = ? AND date < ?
        ''',
        [account, firstDay],
      );
      fromExpenses = (exp.first['t'] as num).toDouble();
    }

    return fromIncomeHistory + fromExpenses;
  }

  String _incomeEntryDateKey(IncomeEntry e) {
    final dt = DateTime.tryParse(e.createdAt);
    if (dt != null) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return '${e.month}-01';
  }

  /// Calendar day for grouping income in the month ledger (stays inside [e.month]).
  String _incomeLedgerBucketDate(IncomeEntry e) {
    final dk = _incomeEntryDateKey(e);
    if (dk.startsWith(e.month)) return dk;
    return '${e.month}-01';
  }

  /// Expenses and income on [account] in [month] (yyyy-MM), grouped by day (newest first).
  Future<AccountMonthLedger> getAccountMonthLedger(String account, String month) async {
    if (account.isEmpty) {
      return const AccountMonthLedger(
        carryForward: 0,
        monthIncome: 0,
        monthSpent: 0,
        days: [],
      );
    }

    final carryForward = await getAccountCarryForwardForMonth(account, month);
    final monthExpenses = (await getExpensesByMonth(month))
        .where((e) => e.account == account)
        .toList();
    final monthIncomeRows = (await getIncomeHistoryForMonth(month))
        .where((e) => e.account == account)
        .toList();

    var monthSpent = 0.0;
    var monthIncome = 0.0;
    for (final e in monthExpenses) {
      if (e.category == 'Received') {
        monthIncome += e.amount;
      } else {
        monthSpent += e.amount;
      }
    }
    for (final h in monthIncomeRows) {
      monthIncome += h.amount;
    }

    final byDay = <String, ({List<Expense> ex, List<IncomeEntry> inc})>{};
    void ensure(String d) {
      byDay.putIfAbsent(d, () => (ex: <Expense>[], inc: <IncomeEntry>[]));
    }

    for (final e in monthExpenses) {
      ensure(e.date);
      byDay[e.date]!.ex.add(e);
    }
    for (final h in monthIncomeRows) {
      final d = _incomeLedgerBucketDate(h);
      ensure(d);
      byDay[d]!.inc.add(h);
    }

    final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final days = keys.map((k) {
      final bucket = byDay[k]!;
      bucket.ex.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      bucket.inc.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return AccountLedgerDay(date: k, expenses: bucket.ex, incomeEntries: bucket.inc);
    }).toList();

    return AccountMonthLedger(
      carryForward: carryForward,
      monthIncome: monthIncome,
      monthSpent: monthSpent,
      days: days,
    );
  }

  // ── Year queries ──

  Future<List<Income>> getIncomeForYear(int year) async {
    final yearPrefix = '$year-';
    if (kIsWeb) {
      final filtered = _webIncome
          .where((m) => (m['month'] as String).startsWith(yearPrefix))
          .toList();
      return filtered.map((m) => Income.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'income',
      where: "month LIKE ?",
      whereArgs: ['$yearPrefix%'],
    );
    return maps.map((m) => Income.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesForYear(int year) async {
    final from = '$year-01-01';
    final to = '$year-12-31';
    return await getExpensesByDateRange(from, to);
  }

  // ── Backup & Restore ──

  Future<List<Map<String, dynamic>>> _getAllIncome() async {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webIncome);
    }
    final db = await _getDb();
    return await db.query('income');
  }

  Future<List<Map<String, dynamic>>> _getAllIncomeHistory() async {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webIncomeHistory);
    }
    final db = await _getDb();
    return await db.query('income_history');
  }

  Future<List<Map<String, dynamic>>> _getAllAccounts() async {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webAccounts);
    }
    final db = await _getDb();
    return await db.query('accounts', orderBy: 'sort_order ASC, name ASC');
  }

  Future<String> exportToJson() async {
    final expenses = await getAllExpenses();
    final incomeList = await _getAllIncome();
    final historyList = await _getAllIncomeHistory();
    final categoryRows = await getExpenseCategories();
    final accountRows = await _getAllAccounts();

    final data = {
      'version': 4,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accountRows
          .map((m) => {
                'name': m['name'],
                'sort_order': m['sort_order'] ?? 0,
              })
          .toList(),
      'expense_categories': categoryRows
          .map((c) => {
                'name': c.name,
                'icon_code_point': c.iconCodePoint,
                'color': c.colorValue,
                'sort_order': c.sortOrder,
                'system_locked': c.systemLocked ? 1 : 0,
              })
          .toList(),
      'expenses': expenses.map((e) => {
        'amount': e.amount,
        'category': e.category,
        'account': e.account,
        'note': e.note,
        'date': e.date,
        'created_at': e.createdAt,
      }).toList(),
      'income': incomeList.map((m) => {
        'amount': m['amount'],
        'month': m['month'],
      }).toList(),
      'income_history': historyList.map((m) => {
        'amount': m['amount'],
        'month': m['month'],
        'account': m['account'] ?? '',
        'note': m['note'] ?? '',
        'created_at': m['created_at'],
      }).toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final expensesList = data['expenses'] as List<dynamic>? ?? [];
    final incomeList = data['income'] as List<dynamic>? ?? [];
    final historyList = data['income_history'] as List<dynamic>? ?? [];
    final catList = data['expense_categories'] as List<dynamic>?;
    final accList = data['accounts'] as List<dynamic>?;

    if (kIsWeb) {
      _webExpenses.clear();
      _webIncome.clear();
      _webIncomeHistory.clear();
      _webExpenseCategories.clear();
      _webAccounts.clear();
      _nextExpenseId = 1;
      _nextIncomeId = 1;
      _nextIncomeHistoryId = 1;
      _nextCategoryId = 1;
      _nextAccountId = 1;

      if (accList != null && accList.isNotEmpty) {
        for (final raw in accList) {
          final m = Map<String, dynamic>.from(raw as Map);
          _webAccounts.add({
            'id': _nextAccountId++,
            'name': m['name'] as String,
            'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedAccountsWeb();
      }

      for (final e in expensesList) {
        final map = Map<String, dynamic>.from(e as Map);
        map['id'] = _nextExpenseId++;
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        _webExpenses.add(map);
      }
      for (final i in incomeList) {
        final map = Map<String, dynamic>.from(i as Map);
        map['id'] = _nextIncomeId++;
        _webIncome.add(map);
      }
      for (final h in historyList) {
        final map = Map<String, dynamic>.from(h as Map);
        map['id'] = _nextIncomeHistoryId++;
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        _webIncomeHistory.add(map);
      }
      if (catList != null && catList.isNotEmpty) {
        for (final raw in catList) {
          final m = Map<String, dynamic>.from(raw as Map);
          _webExpenseCategories.add({
            'id': _nextCategoryId++,
            'name': m['name'] as String,
            'icon_code_point': (m['icon_code_point'] as num).toInt(),
            'color': (m['color'] as num).toInt(),
            'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
            'system_locked': (m['system_locked'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedExpenseCategoriesWeb();
        await _ensureExpenseCategoryRowsForOrphansWeb();
      }
      return;
    }

    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('income');
      await txn.delete('income_history');
      await txn.delete('expense_categories');
      await txn.delete('accounts');

      if (accList != null && accList.isNotEmpty) {
        for (final raw in accList) {
          final m = Map<String, dynamic>.from(raw as Map);
          await txn.insert('accounts', {
            'name': m['name'] as String,
            'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedAccounts(txn);
      }

      for (final e in expensesList) {
        final map = Map<String, dynamic>.from(e as Map);
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        map.remove('id');
        await txn.insert('expenses', map);
      }

      if (catList != null && catList.isNotEmpty) {
        for (final raw in catList) {
          final m = Map<String, dynamic>.from(raw as Map);
          await txn.insert('expense_categories', {
            'name': m['name'] as String,
            'icon_code_point': (m['icon_code_point'] as num).toInt(),
            'color': (m['color'] as num).toInt(),
            'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
            'system_locked': (m['system_locked'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedExpenseCategories(txn);
        await _ensureExpenseCategoryRowsForOrphans(txn);
      }

      for (final i in incomeList) {
        final map = Map<String, dynamic>.from(i as Map);
        map.remove('id');
        await txn.insert('income', map);
      }
      for (final h in historyList) {
        final map = Map<String, dynamic>.from(h as Map);
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        map.remove('id');
        await txn.insert('income_history', map);
      }
    });
  }

  Future<void> _insertSeedAccountsWeb() async {
    for (final a in buildSeededAccounts()) {
      _webAccounts.add({
        'id': _nextAccountId++,
        'name': a.name,
        'sort_order': a.sortOrder,
      });
    }
  }

  Future<void> _insertSeedExpenseCategoriesWeb() async {
    for (final c in buildSeededExpenseCategories()) {
      _webExpenseCategories.add({
        'id': _nextCategoryId++,
        'name': c.name,
        'icon_code_point': c.iconCodePoint,
        'color': c.colorValue,
        'sort_order': c.sortOrder,
        'system_locked': c.systemLocked ? 1 : 0,
      });
    }
  }

  Future<void> _ensureExpenseCategoryRowsForOrphansWeb() async {
    final names = _webExpenseCategories.map((m) => m['name'] as String).toSet();
    var maxOrder = _webExpenseCategories.fold<int>(
      0,
      (m, r) {
        final o = (r['sort_order'] as num?)?.toInt() ?? 0;
        return o > m ? o : m;
      },
    );
    for (final e in _webExpenses) {
      final cat = e['category'] as String;
      if (cat.isEmpty || names.contains(cat)) continue;
      maxOrder++;
      _webExpenseCategories.add({
        'id': _nextCategoryId++,
        'name': cat,
        'icon_code_point': kUnknownCategoryIconCodePoint,
        'color': 0xFF78909C,
        'sort_order': maxOrder,
        'system_locked': 0,
      });
      names.add(cat);
    }
  }
}
