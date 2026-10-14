import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';
import '../models/pending_transaction.dart';
import '../models/merchant_rule.dart';

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
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tablePendingTransactions} (
          id                     INTEGER PRIMARY KEY AUTOINCREMENT,
          fingerprint            TEXT    UNIQUE NOT NULL,
          date                   TEXT    NOT NULL,
          type                   TEXT    NOT NULL,
          amount                 REAL    NOT NULL,
          bank                   TEXT    NOT NULL,
          account_digits         TEXT,
          merchant               TEXT    NOT NULL,
          suggested_category     TEXT    NOT NULL,
          suggested_sub_category TEXT,
          raw_message            TEXT    NOT NULL,
          ref_id                 TEXT,
          status                 TEXT    DEFAULT 'PENDING',
          created_at             TEXT    NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_pending_status
          ON ${AppConstants.tablePendingTransactions}(status)
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableMerchantRules} (
          merchant_keyword TEXT PRIMARY KEY COLLATE NOCASE,
          category         TEXT NOT NULL,
          sub_category     TEXT,
          usage_count      INTEGER DEFAULT 1,
          last_used        TEXT NOT NULL
        )
      ''');
      try {
        await db.execute('ALTER TABLE ${AppConstants.tableBanks} ADD COLUMN account_last_4 TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableRecurringRules} (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          title               TEXT    NOT NULL,
          type                TEXT    NOT NULL,
          category            TEXT    NOT NULL,
          sub_category        TEXT,
          amount              REAL    NOT NULL CHECK(amount > 0),
          bank                TEXT    NOT NULL,
          day_of_month        INTEGER NOT NULL CHECK(day_of_month >= 1 AND day_of_month <= 31),
          start_date          TEXT    NOT NULL,
          next_due_date       TEXT    NOT NULL,
          last_processed_date TEXT,
          is_active           INTEGER NOT NULL DEFAULT 1,
          notes               TEXT,
          last_status         TEXT    DEFAULT 'PENDING',
          last_status_message TEXT
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_recurring_due
          ON ${AppConstants.tableRecurringRules}(next_due_date, is_active)
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableInitialInvestments} (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_name       TEXT    UNIQUE NOT NULL,
          starting_balance REAL    NOT NULL DEFAULT 0,
          category         TEXT    NOT NULL DEFAULT 'SIP & Investments',
          notes            TEXT
        )
      ''');
      await _seedInitialInvestments(db);
    }
  }

  // ── Create all tables ─────────────────────────────────────────
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
        starting_balance REAL    NOT NULL DEFAULT 0,
        account_last_4   TEXT
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

    // Table 7: pending_transactions (Review Inbox staging queue)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablePendingTransactions} (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        fingerprint            TEXT    UNIQUE NOT NULL,
        date                   TEXT    NOT NULL,
        type                   TEXT    NOT NULL,
        amount                 REAL    NOT NULL,
        bank                   TEXT    NOT NULL,
        account_digits         TEXT,
        merchant               TEXT    NOT NULL,
        suggested_category     TEXT    NOT NULL,
        suggested_sub_category TEXT,
        raw_message            TEXT    NOT NULL,
        ref_id                 TEXT,
        status                 TEXT    DEFAULT 'PENDING',
        created_at             TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_status
        ON ${AppConstants.tablePendingTransactions}(status)
    ''');

    // Table 8: merchant_category_rules (Self-learning memory table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableMerchantRules} (
        merchant_keyword TEXT PRIMARY KEY COLLATE NOCASE,
        category         TEXT NOT NULL,
        sub_category     TEXT,
        usage_count      INTEGER DEFAULT 1,
        last_used        TEXT NOT NULL
      )
    ''');

    // Table 9: recurring_rules (Auto-debit for SIP, Loan, EMI, Rent, and Bills)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableRecurringRules} (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        title               TEXT    NOT NULL,
        type                TEXT    NOT NULL,
        category            TEXT    NOT NULL,
        sub_category        TEXT,
        amount              REAL    NOT NULL CHECK(amount > 0),
        bank                TEXT    NOT NULL,
        day_of_month        INTEGER NOT NULL CHECK(day_of_month >= 1 AND day_of_month <= 31),
        start_date          TEXT    NOT NULL,
        next_due_date       TEXT    NOT NULL,
        last_processed_date TEXT,
        is_active           INTEGER NOT NULL DEFAULT 1,
        notes               TEXT,
        last_status         TEXT    DEFAULT 'PENDING',
        last_status_message TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_due
        ON ${AppConstants.tableRecurringRules}(next_due_date, is_active)
    ''');

    // Table 10: initial_investments (Starting balances for investment instruments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableInitialInvestments} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_name       TEXT    UNIQUE NOT NULL,
        starting_balance REAL    NOT NULL DEFAULT 0,
        category         TEXT    NOT NULL DEFAULT 'SIP & Investments',
        notes            TEXT
      )
    ''');
  }

  // ── Seed default data (runs only on first install) ────────────
  Future<void> _seedData(Database db) async {
    await _seedBanks(db);
    await _seedCategories(db);
    await _seedInitialInvestments(db);
  }

  Future<void> _seedInitialInvestments(Database db) async {
    final defaultAssets = [
      'Mutual Funds (SIP)',
      'Stocks / Shares',
      'Fixed Deposit (FD)',
      'Recurring Deposit (RD)',
      'PPF',
      'NPS',
      'Gold / SGB',
      'Other Investment',
    ];
    for (final asset in defaultAssets) {
      await db.insert(
        AppConstants.tableInitialInvestments,
        {
          'asset_name': asset,
          'starting_balance': 0.0,
          'category': 'SIP & Investments',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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

  Future<int> updateBankLast4(int id, String? last4) async {
    final db = await database;
    return await db.update(
      AppConstants.tableBanks,
      {'account_last_4': last4?.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getBankByLast4(String last4) async {
    final db = await database;
    final res = await db.query(
      AppConstants.tableBanks,
      where: 'account_last_4 = ?',
      whereArgs: [last4.trim()],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
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

  /// Total invested (including initial investment holdings).
  Future<double> getTotalInvested({int? year, bool includeStartingBalance = true}) async {
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
    final expenseTotal = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    if (includeStartingBalance) {
      final initialTotal = await getTotalInitialInvestments();
      return initialTotal + expenseTotal;
    }
    return expenseTotal;
  }

  /// Asset allocation: per investment type totals (Starting Balance + Logged Expenses).
  Future<List<Map<String, dynamic>>> getInvestmentAllocation({
    int? year,
    bool includeStartingBalance = true,
  }) async {
    final db   = await database;
    final args = <dynamic>[];
    String extra = '';
    if (year != null) {
      extra = ' AND date >= ? AND date < ?';
      args.addAll(['$year-01-01', '${year + 1}-01-01']);
    }
    final expenseRows = await db.rawQuery(
      "SELECT sub_category, "
      "  COALESCE(SUM(amount), 0) as total, "
      "  COUNT(*) as txn_count "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE category = 'SIP & Investments'$extra "
      "GROUP BY sub_category",
      args,
    );

    if (!includeStartingBalance) {
      final list = List<Map<String, dynamic>>.from(expenseRows);
      list.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
      return list;
    }

    final initialList = await getAllInitialInvestments();
    final Map<String, Map<String, dynamic>> combined = {};

    for (final init in initialList) {
      final name = init['asset_name'] as String;
      final start = (init['starting_balance'] as num?)?.toDouble() ?? 0.0;
      combined[name.toLowerCase()] = {
        'sub_category': name,
        'total': start,
        'txn_count': 0,
        'starting_balance': start,
      };
    }

    for (final exp in expenseRows) {
      final name = (exp['sub_category'] as String?) ?? 'Other Investment';
      final total = (exp['total'] as num).toDouble();
      final count = (exp['txn_count'] as int?) ?? 0;
      final key = name.toLowerCase();

      if (combined.containsKey(key)) {
        combined[key]!['total'] = (combined[key]!['total'] as double) + total;
        combined[key]!['txn_count'] = (combined[key]!['txn_count'] as int) + count;
      } else {
        combined[key] = {
          'sub_category': name,
          'total': total,
          'txn_count': count,
          'starting_balance': 0.0,
        };
      }
    }

    final result = combined.values.where((item) => (item['total'] as double) > 0).toList();
    result.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    return result;
  }

  // ── Initial Investment CRUD ─────────────────────────────────────

  /// Get all initial investment instruments and starting balances.
  Future<List<Map<String, dynamic>>> getAllInitialInvestments() async {
    final db = await database;
    return await db.query(AppConstants.tableInitialInvestments, orderBy: 'id ASC');
  }

  /// Total sum of all initial investment starting balances.
  Future<double> getTotalInitialInvestments() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(starting_balance), 0) as total FROM ${AppConstants.tableInitialInvestments}',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Live total value for a single investment instrument (Starting Balance + Expenses).
  Future<double> getLiveInvestmentHolding(String assetName) async {
    final db = await database;
    final assetRows = await db.query(
      AppConstants.tableInitialInvestments,
      where: 'LOWER(asset_name) = ?',
      whereArgs: [assetName.toLowerCase()],
      limit: 1,
    );
    final startBal = assetRows.isNotEmpty
        ? (assetRows.first['starting_balance'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final expenseRes = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total "
      "FROM ${AppConstants.tableExpenses} "
      "WHERE category = 'SIP & Investments' AND LOWER(sub_category) = ?",
      [assetName.toLowerCase()],
    );
    final expenseTotal = (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;
    return startBal + expenseTotal;
  }

  /// Insert a new initial investment asset.
  Future<int> insertInitialInvestment(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      AppConstants.tableInitialInvestments,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update starting balance for an initial investment.
  Future<int> updateInitialInvestmentBalance(int id, double balance) async {
    final db = await database;
    return await db.update(
      AppConstants.tableInitialInvestments,
      {'starting_balance': balance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an initial investment asset.
  Future<int> deleteInitialInvestment(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.tableInitialInvestments,
      where: 'id = ?',
      whereArgs: [id],
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
  // PHASE 9: PENDING TRANSACTIONS (REVIEW INBOX STAGING QUEUE)
  // ═══════════════════════════════════════════════════════════════

  /// Insert a newly detected transaction from SMS or Notification.
  /// If fingerprint already exists, it is ignored (deduplication).
  Future<int> insertPendingTransaction(PendingTransaction txn) async {
    final db = await database;
    return await db.insert(
      AppConstants.tablePendingTransactions,
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Check whether a transaction fingerprint already exists in the database.
  Future<bool> hasTransactionFingerprint(String fingerprint) async {
    final db = await database;
    final res = await db.query(
      AppConstants.tablePendingTransactions,
      columns: ['id'],
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Get pending transactions staged for user review.
  Future<List<PendingTransaction>> getPendingTransactions({
    String status = 'PENDING',
  }) async {
    final db = await database;
    final res = await db.query(
      AppConstants.tablePendingTransactions,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'id DESC',
    );
    return res.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  /// Get total count of unreviewed pending transactions.
  Future<int> getPendingTransactionsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${AppConstants.tablePendingTransactions} WHERE status = 'PENDING'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Update the status of a pending transaction ('CONFIRMED' or 'DISCARDED').
  Future<int> updatePendingTransactionStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      AppConstants.tablePendingTransactions,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update pending transaction details (e.g. edited category, bank, or amount).
  Future<int> updatePendingTransaction(PendingTransaction txn) async {
    if (txn.id == null) return 0;
    final db = await database;
    return await db.update(
      AppConstants.tablePendingTransactions,
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  /// Permanently delete a pending transaction.
  Future<int> deletePendingTransaction(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.tablePendingTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PHASE 9: MERCHANT CATEGORY LEARNING RULES
  // ═══════════════════════════════════════════════════════════════

  /// Save or update a learned merchant-to-category rule.
  Future<void> saveMerchantRule({
    required String keyword,
    required String category,
    String? subCategory,
  }) async {
    final cleanKeyword = keyword.trim().toUpperCase();
    if (cleanKeyword.isEmpty) return;
    final db = await database;
    await db.rawInsert('''
      INSERT INTO ${AppConstants.tableMerchantRules} (merchant_keyword, category, sub_category, usage_count, last_used)
      VALUES (?, ?, ?, 1, datetime('now'))
      ON CONFLICT(merchant_keyword) DO UPDATE SET
        category = excluded.category,
        sub_category = excluded.sub_category,
        usage_count = usage_count + 1,
        last_used = datetime('now')
    ''', [cleanKeyword, category, subCategory]);
  }

  /// Lookup learned merchant rule by exact keyword match.
  Future<MerchantRule?> getMerchantRule(String keyword) async {
    final cleanKeyword = keyword.trim().toUpperCase();
    if (cleanKeyword.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      AppConstants.tableMerchantRules,
      where: 'merchant_keyword = ?',
      whereArgs: [cleanKeyword],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return MerchantRule.fromMap(res.first);
    }
    return null;
  }

  /// Get all learned merchant rules ordered by usage count.
  Future<List<MerchantRule>> getAllMerchantRules() async {
    final db = await database;
    final res = await db.query(
      AppConstants.tableMerchantRules,
      orderBy: 'usage_count DESC, last_used DESC',
    );
    return res.map((m) => MerchantRule.fromMap(m)).toList();
  }

  /// Delete a merchant rule.
  Future<int> deleteMerchantRule(String keyword) async {
    final db = await database;
    return await db.delete(
      AppConstants.tableMerchantRules,
      where: 'merchant_keyword = ?',
      whereArgs: [keyword.trim().toUpperCase()],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RECURRING RULES (AUTO-DEBIT) CRUD
  // ═══════════════════════════════════════════════════════════════

  /// Insert a new recurring auto-debit rule. Returns the new row id.
  Future<int> insertRecurringRule(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      AppConstants.tableRecurringRules,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing recurring rule by id.
  Future<int> updateRecurringRule(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      AppConstants.tableRecurringRules,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a recurring rule by id.
  Future<int> deleteRecurringRule(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.tableRecurringRules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all recurring rules ordered by active status and next due date.
  Future<List<Map<String, dynamic>>> getAllRecurringRules() async {
    final db = await database;
    return await db.query(
      AppConstants.tableRecurringRules,
      orderBy: 'is_active DESC, next_due_date ASC, id ASC',
    );
  }

  /// Get all active recurring rules due on or before asOfDate (YYYY-MM-DD).
  Future<List<Map<String, dynamic>>> getDueRecurringRules(String asOfDate) async {
    final db = await database;
    return await db.query(
      AppConstants.tableRecurringRules,
      where: 'is_active = 1 AND next_due_date <= ?',
      whereArgs: [asOfDate],
      orderBy: 'next_due_date ASC',
    );
  }

  /// Get a single recurring rule by id.
  Future<Map<String, dynamic>?> getRecurringRuleById(int id) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableRecurringRules,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
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
    await db.delete(AppConstants.tableRecurringRules);
  }
}
