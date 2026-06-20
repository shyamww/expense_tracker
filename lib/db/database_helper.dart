import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_entry.dart';
import '../models/expense_category.dart';
import '../models/app_account.dart';
import '../models/account_ledger_day.dart';
import '../data/category_seed_data.dart';
import '../data/account_seed_data.dart';
import '../core/money.dart';
import '../core/transfer_note.dart';
import '../constants/reporting_category_names.dart';
import '../services/supabase_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // ── Web browser storage ──
  static const String _webStoreKey = 'expense_tracker.web_store.v1';
  static const int _webStoreVersion = 1;
  static const String _cloudStoreTable = 'expense_tracker_stores';

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
  bool _webStoreLoaded = false;
  String? _cloudStoreLoadedForUser;
  String? _cloudSyncError;

  String? get cloudSyncError => _cloudSyncError;

  // ── Mobile SQLite ──
  Database? _database;

  Future<Database> _getDb() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'expense_tracker.db');
    _database = await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _ensureWebStoreLoaded() async {
    if (!kIsWeb) return;
    final cloudUserId = SupabaseService.currentUserId;
    if (_webStoreLoaded && _cloudStoreLoadedForUser == cloudUserId) return;

    if (!_webStoreLoaded) {
      _webStoreLoaded = true;
      await _loadWebStoreFromLocalPrefs();
    }

    await _loadCloudStoreForUser(cloudUserId);
  }

  Future<void> reconnectCloudStore() async {
    if (!kIsWeb) return;
    _cloudStoreLoadedForUser = null;
    await _ensureWebStoreLoaded();
  }

  Future<void> _loadWebStoreFromLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webStoreKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _applyWebStoreSnapshot(Map<String, dynamic>.from(decoded));
    } catch (_) {
      _resetWebStore();
    }
  }

  Future<void> _persistWebStore() async {
    if (!kIsWeb) return;
    await _persistWebStoreLocally();
    await _persistCloudStore();
  }

  Future<void> _persistWebStoreLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webStoreKey, jsonEncode(_webStoreSnapshot()));
  }

  Future<void> _loadCloudStoreForUser(String? userId) async {
    if (userId == null || !SupabaseService.isReady) {
      _cloudStoreLoadedForUser = userId;
      return;
    }
    if (_cloudStoreLoadedForUser == userId) return;

    final client = SupabaseService.client;
    if (client == null) return;

    try {
      final row = await client
          .from(_cloudStoreTable)
          .select('data')
          .eq('user_id', userId)
          .maybeSingle();
      final cloudData = row?['data'];
      if (cloudData is Map) {
        _applyWebStoreSnapshot(Map<String, dynamic>.from(cloudData));
        await _persistWebStoreLocally();
      } else {
        await _persistCloudStore();
      }
      _cloudStoreLoadedForUser = userId;
      _cloudSyncError = null;
    } catch (e) {
      _cloudStoreLoadedForUser = userId;
      _cloudSyncError = e.toString();
    }
  }

  Future<void> _persistCloudStore() async {
    final userId = SupabaseService.currentUserId;
    final client = SupabaseService.client;
    if (userId == null || client == null) return;

    try {
      await client.from(_cloudStoreTable).upsert({
        'user_id': userId,
        'data': _webStoreSnapshot(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _cloudStoreLoadedForUser = userId;
      _cloudSyncError = null;
    } catch (e) {
      _cloudSyncError = e.toString();
    }
  }

  void _applyWebStoreSnapshot(Map<String, dynamic> data) {
    _webExpenses
      ..clear()
      ..addAll(_webRowsFrom(data['expenses']));
    _webIncome
      ..clear()
      ..addAll(_webRowsFrom(data['income']));
    _webIncomeHistory
      ..clear()
      ..addAll(_webRowsFrom(data['income_history']));
    _webExpenseCategories
      ..clear()
      ..addAll(_webRowsFrom(data['expense_categories']));
    _webAccounts
      ..clear()
      ..addAll(_webRowsFrom(data['accounts']));

    _nextExpenseId = _nextWebId(data['next_expense_id'], _webExpenses);
    _nextIncomeId = _nextWebId(data['next_income_id'], _webIncome);
    _nextIncomeHistoryId =
        _nextWebId(data['next_income_history_id'], _webIncomeHistory);
    _nextCategoryId =
        _nextWebId(data['next_category_id'], _webExpenseCategories);
    _nextAccountId = _nextWebId(data['next_account_id'], _webAccounts);

    _normalizeWebRows();
  }

  void _resetWebStore() {
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
  }

  List<Map<String, dynamic>> _webRowsFrom(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  int _nextWebId(Object? storedValue, List<Map<String, dynamic>> rows) {
    final stored = storedValue is num ? storedValue.toInt() : null;
    final maxExisting = rows.fold<int>(0, (maxId, row) {
      final id = row['id'];
      if (id is! num) return maxId;
      return id.toInt() > maxId ? id.toInt() : maxId;
    });
    final minimum = maxExisting + 1;
    if (stored == null || stored < minimum) return minimum;
    return stored;
  }

  void _normalizeWebRows() {
    for (final expense in _webExpenses) {
      expense['id'] = _webRowId(expense['id'], () => _nextExpenseId++);
      expense['amount'] = amountPaisaFromMap(expense['amount']);
      expense['category'] = expense['category'] as String? ?? '';
      expense['account'] = expense['account'] as String? ?? '';
      expense['note'] = expense['note'] as String? ?? '';
      expense['date'] = expense['date'] as String? ?? '';
      expense['created_at'] =
          expense['created_at'] as String? ?? DateTime.now().toIso8601String();
    }
    for (final income in _webIncome) {
      income['id'] = _webRowId(income['id'], () => _nextIncomeId++);
      income['amount'] = amountPaisaFromMap(income['amount']);
      income['month'] = income['month'] as String? ?? '';
    }
    for (final history in _webIncomeHistory) {
      history['id'] = _webRowId(history['id'], () => _nextIncomeHistoryId++);
      history['amount'] = amountPaisaFromMap(history['amount']);
      history['month'] = history['month'] as String? ?? '';
      history['account'] = history['account'] as String? ?? '';
      history['note'] = history['note'] as String? ?? '';
      history['created_at'] =
          history['created_at'] as String? ?? DateTime.now().toIso8601String();
    }
    for (final category in _webExpenseCategories) {
      category['id'] = _webRowId(category['id'], () => _nextCategoryId++);
      category['name'] = category['name'] as String? ?? '';
      category['icon_code_point'] = _asInt(
        category['icon_code_point'],
        kUnknownCategoryIconCodePoint,
      );
      category['color'] = _asInt(category['color'], 0xFF78909C);
      category['sort_order'] = _asInt(category['sort_order'], 0);
      category['system_locked'] = _asInt(category['system_locked'], 0);
      category['archived'] = _asInt(category['archived'], 0);
    }
    for (final account in _webAccounts) {
      account['id'] = _webRowId(account['id'], () => _nextAccountId++);
      account['name'] = account['name'] as String? ?? '';
      account['sort_order'] = _asInt(account['sort_order'], 0);
      account['archived'] = _asInt(account['archived'], 0);
    }
  }

  int _webRowId(Object? value, int Function() fallback) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return fallback();
  }

  int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  Map<String, dynamic> _webStoreSnapshot() {
    List<Map<String, dynamic>> copyRows(List<Map<String, dynamic>> rows) =>
        rows.map((row) => Map<String, dynamic>.from(row)).toList();

    return {
      'version': _webStoreVersion,
      'saved_at': DateTime.now().toIso8601String(),
      'next_expense_id': _nextExpenseId,
      'next_income_id': _nextIncomeId,
      'next_income_history_id': _nextIncomeHistoryId,
      'next_category_id': _nextCategoryId,
      'next_account_id': _nextAccountId,
      'expenses': copyRows(_webExpenses),
      'income': copyRows(_webIncome),
      'income_history': copyRows(_webIncomeHistory),
      'expense_categories': copyRows(_webExpenseCategories),
      'accounts': copyRows(_webAccounts),
    };
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
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
        amount INTEGER NOT NULL,
        month TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE income_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
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
        system_locked INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _insertSeedExpenseCategories(db);
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0
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
          system_locked INTEGER NOT NULL DEFAULT 0,
          archived INTEGER NOT NULL DEFAULT 0
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
          sort_order INTEGER NOT NULL DEFAULT 0,
          archived INTEGER NOT NULL DEFAULT 0
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
    if (oldVersion < 5) {
      await _migrateAmountColumnsToPaisa(db);
    }
    if (oldVersion < 6) {
      await _insertSeedExpenseCategories(db);
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          "ALTER TABLE expense_categories ADD COLUMN archived INTEGER NOT NULL DEFAULT 0",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE accounts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0",
        );
      } catch (_) {}
    }
  }

  /// REAL rupees → INTEGER paisa for expenses, income, income_history.
  Future<void> _migrateAmountColumnsToPaisa(Database db) async {
    await db.execute('''
      CREATE TABLE expenses_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        account TEXT NOT NULL DEFAULT '',
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO expenses_new (id, amount, category, account, note, date, created_at)
      SELECT id, CAST(ROUND(amount * 100) AS INTEGER), category, account, note, date, created_at
      FROM expenses
    ''');
    await db.execute('DROP TABLE expenses');
    await db.execute('ALTER TABLE expenses_new RENAME TO expenses');

    await db.execute('''
      CREATE TABLE income_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        month TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      INSERT INTO income_new (id, amount, month)
      SELECT id, CAST(ROUND(amount * 100) AS INTEGER), month FROM income
    ''');
    await db.execute('DROP TABLE income');
    await db.execute('ALTER TABLE income_new RENAME TO income');

    await db.execute('''
      CREATE TABLE income_history_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        month TEXT NOT NULL,
        account TEXT NOT NULL DEFAULT '',
        note TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO income_history_new (id, amount, month, account, note, created_at)
      SELECT id, CAST(ROUND(amount * 100) AS INTEGER), month, account, note, created_at
      FROM income_history
    ''');
    await db.execute('DROP TABLE income_history');
    await db.execute('ALTER TABLE income_history_new RENAME TO income_history');
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

  Future<List<ExpenseCategory>> getExpenseCategories({
    bool includeArchived = false,
  }) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      var changed = false;
      if (_webExpenseCategories.isEmpty) {
        for (final c in buildSeededExpenseCategories()) {
          _webExpenseCategories.add({
            'id': _nextCategoryId++,
            'name': c.name,
            'icon_code_point': c.iconCodePoint,
            'color': c.colorValue,
            'sort_order': c.sortOrder,
            'system_locked': c.systemLocked ? 1 : 0,
            'archived': c.archived ? 1 : 0,
          });
        }
        changed = true;
      } else {
        final names =
            _webExpenseCategories.map((m) => m['name'] as String).toSet();
        for (final c in buildSeededExpenseCategories()) {
          if (names.contains(c.name)) continue;
          _webExpenseCategories.add({
            'id': _nextCategoryId++,
            'name': c.name,
            'icon_code_point': c.iconCodePoint,
            'color': c.colorValue,
            'sort_order': c.sortOrder,
            'system_locked': c.systemLocked ? 1 : 0,
            'archived': c.archived ? 1 : 0,
          });
          names.add(c.name);
          changed = true;
        }
      }
      if (changed) await _persistWebStore();
      final sorted = List<Map<String, dynamic>>.from(_webExpenseCategories)
        ..removeWhere((m) =>
            !includeArchived && ((m['archived'] as num?)?.toInt() ?? 0) == 1)
        ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
      return sorted.map((m) => ExpenseCategory.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'expense_categories',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((m) => ExpenseCategory.fromMap(m)).toList();
  }

  Future<int> insertExpenseCategory(ExpenseCategory c) async {
    final row = {
      'name': c.name.trim(),
      'icon_code_point': c.iconCodePoint,
      'color': c.colorValue,
      'sort_order': c.sortOrder,
      'system_locked': c.systemLocked ? 1 : 0,
      'archived': c.archived ? 1 : 0,
    };
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      if (_webExpenseCategories
          .any((m) => (m['name'] as String) == row['name'])) {
        throw StateError('duplicate_name');
      }
      final map = Map<String, dynamic>.from(row);
      map['id'] = _nextCategoryId++;
      _webExpenseCategories.add(map);
      await _persistWebStore();
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('expense_categories', row);
  }

  Future<void> updateExpenseCategory(ExpenseCategory c,
      {required String previousName}) async {
    if (c.id == null) return;
    final row = {
      'name': c.name.trim(),
      'icon_code_point': c.iconCodePoint,
      'color': c.colorValue,
      'sort_order': c.sortOrder,
      'system_locked': c.systemLocked ? 1 : 0,
      'archived': c.archived ? 1 : 0,
    };
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
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
      await _ensureWebStoreLoaded();
      for (final e in _webExpenses) {
        if (e['category'] == fromName) e['category'] = toName;
      }
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
      _webExpenseCategories.removeWhere((m) => m['id'] == id);
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setExpenseCategoryArchived(int id, bool archived) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final idx = _webExpenseCategories.indexWhere((m) => m['id'] == id);
      if (idx == -1) return;
      _webExpenseCategories[idx]['archived'] = archived ? 1 : 0;
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    await db.update(
      'expense_categories',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Accounts (banks / cash) ──

  Future<List<AppAccount>> getAccounts({bool includeArchived = false}) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      var changed = false;
      if (_webAccounts.isEmpty) {
        for (final a in buildSeededAccounts()) {
          _webAccounts.add({
            'id': _nextAccountId++,
            'name': a.name,
            'sort_order': a.sortOrder,
            'archived': a.archived ? 1 : 0,
          });
        }
        changed = true;
      }
      if (changed) await _persistWebStore();
      final sorted = List<Map<String, dynamic>>.from(_webAccounts)
        ..removeWhere((m) =>
            !includeArchived && ((m['archived'] as num?)?.toInt() ?? 0) == 1)
        ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
      return sorted.map((m) => AppAccount.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query(
      'accounts',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((m) => AppAccount.fromMap(m)).toList();
  }

  Future<int> insertAccount(AppAccount a) async {
    final row = {
      'name': a.name.trim(),
      'sort_order': a.sortOrder,
      'archived': a.archived ? 1 : 0,
    };
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      if (_webAccounts.any((m) => (m['name'] as String) == row['name'])) {
        throw StateError('duplicate_name');
      }
      final map = Map<String, dynamic>.from(row);
      map['id'] = _nextAccountId++;
      _webAccounts.add(map);
      await _persistWebStore();
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('accounts', row);
  }

  Future<void> updateAccount(AppAccount a,
      {required String previousName}) async {
    if (a.id == null) return;
    final row = {
      'name': a.name.trim(),
      'sort_order': a.sortOrder,
      'archived': a.archived ? 1 : 0,
    };
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
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
      await _ensureWebStoreLoaded();
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
      await _ensureWebStoreLoaded();
      for (final e in _webExpenses) {
        if (e['account'] == fromName) e['account'] = toName;
      }
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
      for (final h in _webIncomeHistory) {
        if (h['account'] == fromName) h['account'] = toName;
      }
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
      _webAccounts.removeWhere((m) => m['id'] == id);
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setAccountArchived(int id, bool archived) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final idx = _webAccounts.indexWhere((m) => m['id'] == id);
      if (idx == -1) return;
      _webAccounts[idx]['archived'] = archived ? 1 : 0;
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    await db.update(
      'accounts',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Sum of all account balances: income credits; Received + transfer-in credit; other expenses debit.
  Future<double> getCumulativeAccountBalance() async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      var totalPaisa = 0;
      for (final e in _webExpenses) {
        final acct = e['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        final amt = amountPaisaFromMap(e['amount']);
        final cat = e['category'] as String? ?? '';
        if (ReportingCategoryNames.creditsExpenseAccountBalance(cat)) {
          totalPaisa += amt;
        } else {
          totalPaisa -= amt;
        }
      }
      for (final h in _webIncomeHistory) {
        final acct = h['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        totalPaisa += amountPaisaFromMap(h['amount']);
      }
      return rupeesFromPaisa(totalPaisa);
    }
    final db = await _getDb();
    final exp = await db.rawQuery('''
      SELECT COALESCE(SUM(${ReportingCategoryNames.sqlExpenseBalanceCase}), 0) AS t
      FROM expenses
      WHERE IFNULL(account, '') != ''
    ''');
    final inc = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS t
      FROM income_history
      WHERE IFNULL(account, '') != ''
    ''');
    final expTotal = (exp.first['t'] as num).toInt();
    final incTotal = (inc.first['t'] as num).toInt();
    return rupeesFromPaisa(expTotal + incTotal);
  }

  /// Same rules as [getCumulativeAccountBalance], split by `account` name (values in paisa).
  Future<Map<String, int>> getPerAccountBalances() async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final balances = <String, int>{};
      for (final e in _webExpenses) {
        final acct = e['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        final amt = amountPaisaFromMap(e['amount']);
        final cat = e['category'] as String? ?? '';
        final delta = ReportingCategoryNames.creditsExpenseAccountBalance(cat)
            ? amt
            : -amt;
        balances[acct] = (balances[acct] ?? 0) + delta;
      }
      for (final h in _webIncomeHistory) {
        final acct = h['account'] as String? ?? '';
        if (acct.isEmpty) continue;
        balances[acct] =
            (balances[acct] ?? 0) + amountPaisaFromMap(h['amount']);
      }
      return balances;
    }
    final db = await _getDb();
    final exp = await db.rawQuery('''
      SELECT account,
        COALESCE(SUM(${ReportingCategoryNames.sqlExpenseBalanceCase}), 0) AS t
      FROM expenses
      WHERE IFNULL(account, '') != ''
      GROUP BY account
    ''');
    final inc = await db.rawQuery('''
      SELECT account, COALESCE(SUM(amount), 0) AS t
      FROM income_history
      WHERE IFNULL(account, '') != ''
      GROUP BY account
    ''');
    final balances = <String, int>{};
    for (final row in exp) {
      final name = row['account'] as String;
      balances[name] = (balances[name] ?? 0) + (row['t'] as num).toInt();
    }
    for (final row in inc) {
      final name = row['account'] as String;
      balances[name] = (balances[name] ?? 0) + (row['t'] as num).toInt();
    }
    return balances;
  }

  // ── Expense CRUD ──

  Future<int> insertExpense(Expense expense) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final map = Map<String, dynamic>.from(expense.toMap());
      map['id'] = _nextExpenseId++;
      _webExpenses.add(map);
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
      final sorted = List<Map<String, dynamic>>.from(_webExpenses)
        ..sort(_compareExpenseRowDesc);
      return sorted.map((m) => Expense.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps =
        await db.query('expenses', orderBy: 'date DESC, created_at DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesByMonth(String month) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
      await _ensureWebStoreLoaded();
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

  Future<Expense?> getExpenseById(int id) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      for (final row in _webExpenses) {
        if (row['id'] == id) return Expense.fromMap(row);
      }
      return null;
    }
    final db = await _getDb();
    final maps =
        await db.query('expenses', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Expense.fromMap(maps.first);
  }

  Future<int> updateExpense(Expense expense) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final index = _webExpenses.indexWhere((m) => m['id'] == expense.id);
      if (index != -1) {
        _webExpenses[index] = Map<String, dynamic>.from(expense.toMap());
        _webExpenses[index]['id'] = expense.id;
        await _persistWebStore();
      }
      return index != -1 ? 1 : 0;
    }
    final db = await _getDb();
    return await db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final existing = await getExpenseById(id);
    final prefix =
        existing != null ? parseTransferNotePrefix(existing.note) : null;

    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final before = _webExpenses.length;
      if (prefix != null) {
        _webExpenses.removeWhere(
          (m) => (m['note'] as String? ?? '').startsWith(prefix),
        );
      } else {
        _webExpenses.removeWhere((m) => m['id'] == id);
      }
      await _persistWebStore();
      return before - _webExpenses.length;
    }
    final db = await _getDb();
    if (prefix != null) {
      return await db.delete(
        'expenses',
        where: 'note LIKE ?',
        whereArgs: ['$prefix%'],
      );
    }
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> deleteExpenseAndGetDeleted(int id) async {
    final existing = await getExpenseById(id);
    if (existing == null) return const [];
    final prefix = parseTransferNotePrefix(existing.note);
    final deleted = prefix == null
        ? [existing]
        : (await getAllExpenses())
            .where((e) => e.note.startsWith(prefix))
            .toList();
    await deleteExpense(id);
    return deleted;
  }

  Future<void> restoreDeletedExpenses(List<Expense> expenses) async {
    for (final expense in expenses) {
      await insertExpense(Expense(
        amount: expense.amount,
        category: expense.category,
        account: expense.account,
        note: expense.note,
        date: expense.date,
        createdAt: expense.createdAt,
      ));
    }
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
      await _ensureWebStoreLoaded();
      final index = _webIncome.indexWhere((m) => m['month'] == income.month);
      if (index != -1) {
        final oldAmount = amountPaisaFromMap(_webIncome[index]['amount']);
        _webIncome[index]['amount'] = oldAmount + income.amount;
        await _persistWebStore();
        return 1;
      } else {
        final map = Map<String, dynamic>.from(income.toMap());
        map['id'] = _nextIncomeId++;
        _webIncome.add(map);
        await _persistWebStore();
        return map['id'] as int;
      }
    }
    final db = await _getDb();
    final existing =
        await db.query('income', where: 'month = ?', whereArgs: [income.month]);
    if (existing.isNotEmpty) {
      final oldAmount = amountPaisaFromMap(existing.first['amount']);
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
      await _ensureWebStoreLoaded();
      final map = Map<String, dynamic>.from(entry.toMap());
      map['id'] = _nextIncomeHistoryId++;
      _webIncomeHistory.add(map);
      await _persistWebStore();
      return map['id'] as int;
    }
    final db = await _getDb();
    return await db.insert('income_history', entry.toMap());
  }

  Future<List<IncomeEntry>> getIncomeHistoryForMonth(String month) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final filtered = _webIncomeHistory
          .where((m) => m['month'] == month)
          .toList()
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
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
      await _ensureWebStoreLoaded();
      final sorted = List<Map<String, dynamic>>.from(_webIncomeHistory)
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
      return sorted.map((m) => IncomeEntry.fromMap(m)).toList();
    }
    final db = await _getDb();
    final maps = await db.query('income_history', orderBy: 'created_at DESC');
    return maps.map((m) => IncomeEntry.fromMap(m)).toList();
  }

  Future<IncomeEntry?> getIncomeHistoryById(int id) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      try {
        final m = _webIncomeHistory.firstWhere((e) => e['id'] == id);
        return IncomeEntry.fromMap(m);
      } catch (_) {
        return null;
      }
    }
    final db = await _getDb();
    final maps =
        await db.query('income_history', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return IncomeEntry.fromMap(maps.first);
  }

  /// Rebuilds [income] row for [month] from the sum of [income_history] rows.
  Future<void> _recomputeIncomeAggregateForMonth(String month) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      final sum = _webIncomeHistory
          .where((m) => m['month'] == month)
          .fold<int>(0, (s, m) => s + amountPaisaFromMap(m['amount']));
      final idx = _webIncome.indexWhere((m) => m['month'] == month);
      if (sum == 0) {
        if (idx != -1) _webIncome.removeAt(idx);
      } else if (idx != -1) {
        _webIncome[idx]['amount'] = sum;
      } else {
        _webIncome.add({'id': _nextIncomeId++, 'month': month, 'amount': sum});
      }
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    final maps = await db
        .query('income_history', where: 'month = ?', whereArgs: [month]);
    var total = 0;
    for (final m in maps) {
      total += (m['amount'] as num).toInt();
    }
    final existing =
        await db.query('income', where: 'month = ?', whereArgs: [month]);
    if (total == 0) {
      if (existing.isNotEmpty) {
        await db.delete('income', where: 'month = ?', whereArgs: [month]);
      }
    } else if (existing.isNotEmpty) {
      await db.update('income', {'amount': total},
          where: 'month = ?', whereArgs: [month]);
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
      await _ensureWebStoreLoaded();
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
      await _persistWebStore();
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
      await _ensureWebStoreLoaded();
      _webIncomeHistory.removeWhere((m) => m['id'] == id);
      await _recomputeIncomeAggregateForMonth(month);
      await _persistWebStore();
      return;
    }
    final db = await _getDb();
    await db.delete('income_history', where: 'id = ?', whereArgs: [id]);
    await _recomputeIncomeAggregateForMonth(month);
  }

  Future<IncomeEntry?> deleteIncomeHistoryEntryAndGetDeleted(int id) async {
    final old = await getIncomeHistoryById(id);
    if (old == null) return null;
    await deleteIncomeHistoryEntry(id);
    return old;
  }

  Future<void> restoreIncomeHistoryEntry(IncomeEntry entry) async {
    await _insertIncomeHistory(IncomeEntry(
      amount: entry.amount,
      month: entry.month,
      account: entry.account,
      note: entry.note,
      createdAt: entry.createdAt,
    ));
    await _recomputeIncomeAggregateForMonth(entry.month);
  }

  Future<Income?> getIncomeForMonth(String month) async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
    var totalIncomePaisa = 0;
    var totalSpentPaisa = 0;
    var totalReceivedPaisa = 0;

    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      for (final m in _webIncome) {
        if ((m['month'] as String).compareTo(month) < 0) {
          totalIncomePaisa += amountPaisaFromMap(m['amount']);
        }
      }
      for (final e in _webExpenses) {
        if ((e['date'] as String).compareTo(firstDay) < 0) {
          final amt = amountPaisaFromMap(e['amount']);
          final cat = e['category'] as String? ?? '';
          if (ReportingCategoryNames.countsAsExternalReceived(cat)) {
            totalReceivedPaisa += amt;
          } else if (ReportingCategoryNames.countsAsSpendingInReports(cat)) {
            totalSpentPaisa += amt;
          }
        }
      }
    } else {
      final db = await _getDb();
      final incomeResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM income WHERE month < ?',
        [month],
      );
      totalIncomePaisa = (incomeResult.first['total'] as num).toInt();

      final spentResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date < ? AND ${ReportingCategoryNames.sqlExcludedFromSpentTotals}',
        [firstDay],
      );
      totalSpentPaisa = (spentResult.first['total'] as num).toInt();

      final receivedResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date < ? AND category = 'Received'",
        [firstDay],
      );
      totalReceivedPaisa = (receivedResult.first['total'] as num).toInt();
    }

    return rupeesFromPaisa(
        totalIncomePaisa + totalReceivedPaisa - totalSpentPaisa);
  }

  /// Net balance brought into [month] for [account] (income_history with month \< M
  /// plus expenses on this account with date \< first day of [month]).
  Future<double> getAccountCarryForwardForMonth(
      String account, String month) async {
    if (account.isEmpty) return 0;
    final firstDay = '$month-01';
    var fromIncomeHistoryPaisa = 0;
    var fromExpensesPaisa = 0;

    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      for (final h in _webIncomeHistory) {
        if ((h['account'] as String? ?? '') != account) continue;
        if ((h['month'] as String).compareTo(month) < 0) {
          fromIncomeHistoryPaisa += amountPaisaFromMap(h['amount']);
        }
      }
      for (final e in _webExpenses) {
        if ((e['account'] as String? ?? '') != account) continue;
        if ((e['date'] as String).compareTo(firstDay) >= 0) continue;
        final amt = amountPaisaFromMap(e['amount']);
        if (ReportingCategoryNames.creditsExpenseAccountBalance(
            e['category'] as String? ?? '')) {
          fromExpensesPaisa += amt;
        } else {
          fromExpensesPaisa -= amt;
        }
      }
    } else {
      final db = await _getDb();
      final inc = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM income_history WHERE account = ? AND month < ?',
        [account, month],
      );
      fromIncomeHistoryPaisa = (inc.first['t'] as num).toInt();
      final exp = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(${ReportingCategoryNames.sqlExpenseBalanceCase}), 0) AS t
        FROM expenses WHERE account = ? AND date < ?
        ''',
        [account, firstDay],
      );
      fromExpensesPaisa = (exp.first['t'] as num).toInt();
    }

    return rupeesFromPaisa(fromIncomeHistoryPaisa + fromExpensesPaisa);
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
  Future<AccountMonthLedger> getAccountMonthLedger(
      String account, String month) async {
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

    var monthSpentPaisa = 0;
    var monthIncomePaisa = 0;

    for (final e in monthExpenses) {
      if (ReportingCategoryNames.creditsExpenseAccountBalance(e.category)) {
        monthIncomePaisa += e.amount; // money coming IN
      } else {
        monthSpentPaisa += e.amount; // money going OUT
      }
    }
    for (final h in monthIncomeRows) {
      monthIncomePaisa += h.amount;
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
      return AccountLedgerDay(
          date: k, expenses: bucket.ex, incomeEntries: bucket.inc);
    }).toList();

    return AccountMonthLedger(
      carryForward: carryForward,
      monthIncome: rupeesFromPaisa(monthIncomePaisa),
      monthSpent: rupeesFromPaisa(monthSpentPaisa),
      days: days,
    );
  }

  // ── Year queries ──

  Future<List<Income>> getIncomeForYear(int year) async {
    final yearPrefix = '$year-';
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
      await _ensureWebStoreLoaded();
      return List<Map<String, dynamic>>.from(_webIncome);
    }
    final db = await _getDb();
    return await db.query('income');
  }

  Future<List<Map<String, dynamic>>> _getAllIncomeHistory() async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      return List<Map<String, dynamic>>.from(_webIncomeHistory);
    }
    final db = await _getDb();
    return await db.query('income_history');
  }

  Future<List<Map<String, dynamic>>> _getAllAccounts() async {
    if (kIsWeb) {
      await _ensureWebStoreLoaded();
      return List<Map<String, dynamic>>.from(_webAccounts);
    }
    final db = await _getDb();
    return await db.query('accounts', orderBy: 'sort_order ASC, name ASC');
  }

  Future<String> exportToJson() async {
    final expenses = await getAllExpenses();
    final incomeList = await _getAllIncome();
    final historyList = await _getAllIncomeHistory();
    final categoryRows = await getExpenseCategories(includeArchived: true);
    final accountRows = await _getAllAccounts();

    final data = {
      'version': 5,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accountRows
          .map((m) => {
                'name': m['name'],
                'sort_order': m['sort_order'] ?? 0,
                'archived': (m['archived'] as num?)?.toInt() ?? 0,
              })
          .toList(),
      'expense_categories': categoryRows
          .map((c) => {
                'name': c.name,
                'icon_code_point': c.iconCodePoint,
                'color': c.colorValue,
                'sort_order': c.sortOrder,
                'system_locked': c.systemLocked ? 1 : 0,
                'archived': c.archived ? 1 : 0,
              })
          .toList(),
      'expenses': expenses
          .map((e) => {
                'amount_paisa': e.amount,
                'amount': rupeesFromPaisa(e.amount),
                'category': e.category,
                'account': e.account,
                'note': e.note,
                'date': e.date,
                'created_at': e.createdAt,
              })
          .toList(),
      'income': incomeList.map((m) {
        final p = amountPaisaFromMap(m['amount']);
        return {
          'amount_paisa': p,
          'amount': rupeesFromPaisa(p),
          'month': m['month'],
        };
      }).toList(),
      'income_history': historyList.map((m) {
        final p = amountPaisaFromMap(m['amount']);
        return {
          'amount_paisa': p,
          'amount': rupeesFromPaisa(p),
          'month': m['month'],
          'account': m['account'] ?? '',
          'note': m['note'] ?? '',
          'created_at': m['created_at'],
        };
      }).toList(),
    };

    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  Future<void> importFromJson(String encoded) async {
    final jsonString = utf8.decode(base64Decode(encoded.trim()));
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final expensesList = data['expenses'] as List<dynamic>? ?? [];
    final incomeList = data['income'] as List<dynamic>? ?? [];
    final historyList = data['income_history'] as List<dynamic>? ?? [];
    final catList = data['expense_categories'] as List<dynamic>?;
    final accList = data['accounts'] as List<dynamic>?;

    if (kIsWeb) {
      await _ensureWebStoreLoaded();
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
            'archived': (m['archived'] as num?)?.toInt() ?? 0,
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
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
        _webExpenses.add(map);
      }
      for (final i in incomeList) {
        final map = Map<String, dynamic>.from(i as Map);
        map['id'] = _nextIncomeId++;
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
        _webIncome.add(map);
      }
      for (final h in historyList) {
        final map = Map<String, dynamic>.from(h as Map);
        map['id'] = _nextIncomeHistoryId++;
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
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
            'archived': (m['archived'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedExpenseCategoriesWeb();
        await _ensureExpenseCategoryRowsForOrphansWeb();
      }
      await _persistWebStore();
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
            'archived': (m['archived'] as num?)?.toInt() ?? 0,
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
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
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
            'archived': (m['archived'] as num?)?.toInt() ?? 0,
          });
        }
      } else {
        await _insertSeedExpenseCategories(txn);
        await _ensureExpenseCategoryRowsForOrphans(txn);
      }

      for (final i in incomeList) {
        final map = Map<String, dynamic>.from(i as Map);
        map.remove('id');
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
        await txn.insert('income', map);
      }
      for (final h in historyList) {
        final map = Map<String, dynamic>.from(h as Map);
        if (map['created_at'] == null) {
          map['created_at'] = DateTime.now().toIso8601String();
        }
        map['account'] = map['account'] as String? ?? '';
        map.remove('id');
        map['amount'] = backupAmountToPaisa(map);
        map.remove('amount_paisa');
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
        'archived': a.archived ? 1 : 0,
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
        'archived': c.archived ? 1 : 0,
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
        'archived': 0,
      });
      names.add(cat);
    }
  }
}
