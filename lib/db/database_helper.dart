import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

/// Singleton SQLite database helper.
/// Handles all table creation, seed data, and raw SQL queries.
/// All logic is derived from the Excel workbook formulas.
class DatabaseHelper {
  // ── Singleton pattern ─────────────────────────────────────────
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;
  DatabaseHelper._internal();

  Database? _db;

  /// Returns the open database, initializing it if needed.
  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ═══════════════════════════════════════════════════════════════
  // INIT — Create all tables + seed default data
  // ═══════════════════════════════════════════════════════════════

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migration logic goes here
  }

  // ── Create all 6 tables ───────────────────────────────────────
  Future<void> _createTables(Database db) async {
    // Table 1: expenses (main transaction ledger)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableExpenses} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        date         TEXT    NOT NULL,
        category     TEXT    NOT NULL,
        sub_category TEXT,
        description  TEXT,
        amount       REAL    NOT NULL CHECK(amount > 0),
        bank         TEXT    NOT NULL
      )
    ''');

    // Index for fast date + category filtering (replaces Excel SUMIFS)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_date
        ON ${AppConstants.tableExpenses}(date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_category
        ON ${AppConstants.tableExpenses}(category)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_bank
        ON ${AppConstants.tableExpenses}(bank)
    ''');

    // Table 2: banks
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableBanks} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT    UNIQUE NOT NULL,
        starting_balance REAL    NOT NULL DEFAULT 0
      )
    ''');

    // Table 3: extra_credit (income / salary)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableExtraCredit} (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        date      TEXT    NOT NULL,
        user_name TEXT,
        amount    REAL    NOT NULL CHECK(amount > 0),
        mode      TEXT    NOT NULL DEFAULT 'Other',
        bank      TEXT    NOT NULL
      )
    ''');

    // Table 4: transfers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableTransfers} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL,
        from_bank   TEXT    NOT NULL,
        to_bank     TEXT    NOT NULL,
        amount      REAL    NOT NULL CHECK(amount > 0),
        description TEXT,
        CHECK(from_bank != to_bank)
      )
    ''');

    // Table 5: categories (master lookup)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCategories} (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    UNIQUE NOT NULL,
        icon  TEXT,
        color TEXT
      )
    ''');

    // Table 6: sub_categories (SubCatHelper logic)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableSubCategories} (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name     TEXT    NOT NULL,
        sub_category_name TEXT    NOT NULL,
        FOREIGN KEY(category_name) REFERENCES ${AppConstants.tableCategories}(name)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subcat_category
        ON ${AppConstants.tableSubCategories}(category_name)
    ''');
  }

  // ── Seed default data (runs only on first install) ────────────
  Future<void> _seedData(Database db) async {
    await _seedBanks(db);
    await _seedCategories(db);
  }

  Future<void> _seedBanks(Database db) async {
    for (final bank in AppConstants.defaultBanks) {
      await db.insert(AppConstants.tableBanks, {
        'name': bank,
        'starting_balance': 0.0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedCategories(Database db) async {
    for (final entry in AppConstants.categorySubMap.entries) {
      final catName = entry.key;
      final subs    = entry.value;

      // Insert category
      await db.insert(AppConstants.tableCategories, {
        'name':  catName,
        'icon':  AppConstants.categoryIcons[catName] ?? '🔹',
        'color': AppConstants.categoryColors[catName] ?? '94A3B8',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // Insert sub-categories
      for (final sub in subs) {
        await db.insert(AppConstants.tableSubCategories, {
          'category_name':     catName,
          'sub_category_name': sub,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EXPENSES CRUD
  // ═══════════════════════════════════════════════════════════════

  /// Insert a new expense. Returns the new row id.
  Future<int> insertExpense(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      AppConstants.tableExpenses,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing expense by id.
  Future<int> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      AppConstants.tableExpenses,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an expense by id.
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.tableExpenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all expenses ordered by date descending.
  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    return await db.query(
      AppConstants.tableExpenses,
      orderBy: 'date DESC, id DESC',
    );
  }

  /// Get expenses filtered by date range, category, bank.
  /// All parameters are optional filters.
  Future<List<Map<String, dynamic>>> getExpensesFiltered({
    String? dateFrom,     // 'YYYY-MM-DD' inclusive
    String? dateTo,       // 'YYYY-MM-DD' exclusive
    String? category,
    String? bank,
  }) async {
    final db    = await database;
    final where = <String>[];
    final args  = <dynamic>[];

    if (dateFrom != null) { where.add('date >= ?'); args.add(dateFrom); }
    if (dateTo   != null) { where.add('date < ?');  args.add(dateTo);   }
    if (category != null) { where.add('category = ?'); args.add(category); }
    if (bank     != null) { where.add('bank = ?');  args.add(bank); }

    return await db.query(
      AppConstants.tableExpenses,
      where:     where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty  ? null : args,
      orderBy: 'date DESC, id DESC',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EXTRA CREDIT (INCOME) CRUD
  // ═══════════════════════════════════════════════════════════════

  Future<int> insertIncome(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(AppConstants.tableExtraCredit, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateIncome(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(AppConstants.tableExtraCredit, data,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return await db.delete(AppConstants.tableExtraCredit,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllIncome() async {
    final db = await database;
    return await db.query(AppConstants.tableExtraCredit,
        orderBy: 'date DESC, id DESC');
  }

  // ═══════════════════════════════════════════════════════════════
  // TRANSFERS CRUD
  // ═══════════════════════════════════════════════════════════════

  Future<int> insertTransfer(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(AppConstants.tableTransfers, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteTransfer(int id) async {
    final db = await database;
    return await db.delete(AppConstants.tableTransfers,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllTransfers() async {
    final db = await database;
    return await db.query(AppConstants.tableTransfers,
        orderBy: 'date DESC, id DESC');
  }

  // ═══════════════════════════════════════════════════════════════
  // BANKS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllBanks() async {
    final db = await database;
    return await db.query(AppConstants.tableBanks, orderBy: 'id ASC');
  }

  Future<int> updateBankBalance(int id, double balance) async {
    final db = await database;
    return await db.update(
      AppConstants.tableBanks,
      {'starting_balance': balance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertBank(String name, double startingBalance) async {
    final db = await database;
    return await db.insert(
      AppConstants.tableBanks,
      {'name': name, 'starting_balance': startingBalance},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> deleteBank(int id) async {
    final db = await database;
    return await db.delete(AppConstants.tableBanks,
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  // CATEGORIES & SUB-CATEGORIES (Lookups sheet logic)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query(AppConstants.tableCategories, orderBy: 'id ASC');
  }

  /// Replicates Excel SubCatHelper — returns sub-categories for a given category.
  Future<List<String>> getSubCategories(String categoryName) async {
    final db  = await database;
    final res = await db.query(
      AppConstants.tableSubCategories,
      columns:   ['sub_category_name'],
      where:     'category_name = ?',
      whereArgs: [categoryName],
      orderBy:   'id ASC',
    );
    return res.map((r) => r['sub_category_name'] as String).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // BALANCE CALCULATION QUERIES
  // (Replicates Excel Banks sheet formula)
  // Balance = StartBal + TotalIncome + TransferIn - TransferOut - TotalExpenses
  // ═══════════════════════════════════════════════════════════════

  /// Total expenses for a bank within a date range.
  Future<double> getTotalExpenses({
    required String bank,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db  = await database;
    final where  = ['bank = ?'];
    final args   = <dynamic>[bank];
    if (dateFrom != null) { where.add('date >= ?'); args.add(dateFrom); }
    if (dateTo   != null) { where.add('date < ?');  args.add(dateTo);   }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total '
      'FROM ${AppConstants.tableExpenses} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total income (extra credit) for a bank within a date range.
  Future<double> getTotalIncome({
    required String bank,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db    = await database;
    final where = ['bank = ?'];
    final args  = <dynamic>[bank];
    if (dateFrom != null) { where.add('date >= ?'); args.add(dateFrom); }
    if (dateTo   != null) { where.add('date < ?');  args.add(dateTo);   }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total '
      'FROM ${AppConstants.tableExtraCredit} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total transfer IN to a bank within a date range.
  Future<double> getTotalTransferIn({
    required String bank,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db    = await database;
    final where = ['to_bank = ?'];
    final args  = <dynamic>[bank];
    if (dateFrom != null) { where.add('date >= ?'); args.add(dateFrom); }
    if (dateTo   != null) { where.add('date < ?');  args.add(dateTo);   }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total '
      'FROM ${AppConstants.tableTransfers} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total transfer OUT from a bank within a date range.
  Future<double> getTotalTransferOut({
    required String bank,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db    = await database;
    final where = ['from_bank = ?'];
    final args  = <dynamic>[bank];
    if (dateFrom != null) { where.add('date >= ?'); args.add(dateFrom); }
    if (dateTo   != null) { where.add('date < ?');  args.add(dateTo);   }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total '
      'FROM ${AppConstants.tableTransfers} '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Live balance for a single bank.
  /// Formula: StartBal + Income + TransferIn - TransferOut - Expenses
  Future<double> getLiveBalance(String bank) async {
    final banks = await getAllBanks();
    final bankRow = banks.firstWhere(
      (b) => b['name'] == bank,
      orElse: () => {'starting_balance': 0.0},
    );
    final startBal  = (bankRow['starting_balance'] as num?)?.toDouble() ?? 0.0;
    final income    = await getTotalIncome(bank: bank);
    final transIn   = await getTotalTransferIn(bank: bank);
    final transOut  = await getTotalTransferOut(bank: bank);
    final expenses  = await getTotalExpenses(bank: bank);

    return startBal + income + transIn - transOut - expenses;
  }

  // ═══════════════════════════════════════════════════════════════
  // CATEGORY CHART QUERIES
  // (Replicates Excel Category Chart sheet SUMIFS)
  // ═══════════════════════════════════════════════════════════════

  /// Category-wise expense breakdown for a month.
  /// Mirrors: SUMIFS(Expenses!$E, category, date_range) + COUNT
  Future<List<Map<String, dynamic>>> getCategoryBreakdown({
    required String dateFrom,
    required String dateTo,
    String? bank,
  }) async {
    final db   = await database;
    final where = ['date >= ? AND date < ?'];
    final args  = <dynamic>[dateFrom, dateTo];
    if (bank != null) { where.add('bank = ?'); args.add(bank); }

    return await db.rawQuery(
      'SELECT category, '
      '  COALESCE(SUM(amount), 0) as total, '
      '  COUNT(*) as txn_count '
      'FROM ${AppConstants.tableExpenses} '
      'WHERE ${where.join(' AND ')} '
      'GROUP BY category '
      'ORDER BY total DESC',
      args,
    );
  }

  /// Sub-category breakdown under a category.
  Future<List<Map<String, dynamic>>> getSubCategoryBreakdown({
    required String category,
    required String dateFrom,
    required String dateTo,
  }) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT sub_category, '
      '  COALESCE(SUM(amount), 0) as total, '
      '  COUNT(*) as txn_count '
      'FROM ${AppConstants.tableExpenses} '
      'WHERE category = ? AND date >= ? AND date < ? '
      'GROUP BY sub_category '
      'ORDER BY total DESC',
      [category, dateFrom, dateTo],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MONTHLY SUMMARY QUERIES
  // (Replicates Excel Monthly Summary sheet)
  // ═══════════════════════════════════════════════════════════════

  /// Per-bank monthly totals for a year.
  Future<List<Map<String, dynamic>>> getMonthlyBankSummary({
    required int year,
  }) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT "
      "  CAST(strftime('%m', date) AS INTEGER) as month, "
      "  bank, "
      "  COALESCE(SUM(amount), 0) as total "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE date >= ? AND date < ? "
      "GROUP BY month, bank "
      "ORDER BY month ASC, bank ASC",
      ['$year-01-01', '${year + 1}-01-01'],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INVESTMENT PORTFOLIO QUERIES
  // (Replicates Excel Investments sheet)
  // ═══════════════════════════════════════════════════════════════

  /// Total invested (YTD or all time).
  Future<double> getTotalInvested({int? year}) async {
    final db   = await database;
    final args = <dynamic>[];
    String extra = '';
    if (year != null) {
      extra = ' AND date >= ? AND date < ?';
      args.addAll(['$year-01-01', '${year + 1}-01-01']);
    }
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE category = 'SIP & Investments'$extra",
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Asset allocation: per investment type totals.
  Future<List<Map<String, dynamic>>> getInvestmentAllocation({int? year}) async {
    final db   = await database;
    final args = <dynamic>[];
    String extra = '';
    if (year != null) {
      extra = ' AND date >= ? AND date < ?';
      args.addAll(['$year-01-01', '${year + 1}-01-01']);
    }
    return await db.rawQuery(
      "SELECT sub_category, "
      "  COALESCE(SUM(amount), 0) as total, "
      "  COUNT(*) as txn_count "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE category = 'SIP & Investments'$extra "
      "GROUP BY sub_category "
      "ORDER BY total DESC",
      args,
    );
  }

  /// Monthly investment breakdown (month × sub_category matrix).
  /// Replicates Excel Investments monthly tracker table.
  Future<List<Map<String, dynamic>>> getMonthlyInvestmentBreakdown(int year) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT "
      "  CAST(strftime('%m', date) AS INTEGER) as month, "
      "  sub_category, "
      "  COALESCE(SUM(amount), 0) as total "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE category = 'SIP & Investments' "
      "  AND date >= ? AND date < ? "
      "GROUP BY month, sub_category "
      "ORDER BY month ASC, sub_category ASC",
      ['$year-01-01', '${year + 1}-01-01'],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════

  /// Close the database (call only when app is disposed).
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }

  /// Delete all data (for testing / reset).
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.tableExpenses);
    await db.delete(AppConstants.tableExtraCredit);
    await db.delete(AppConstants.tableTransfers);
  }
}
