import 'package:intl/intl.dart';
import '../models/statement_transaction.dart';
import '../models/expense.dart';
import '../models/extra_credit.dart';
import '../db/database_helper.dart';

/// Service responsible for scanning extracted statement transactions against
/// existing database records (from SMS sync and manual entries) to detect duplicates.
class StatementDeduplicationService {
  final DatabaseHelper _dbHelper;

  StatementDeduplicationService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Inspects a list of parsed statement transactions against SQLite ledger.
  /// Modifies each transaction's `isDuplicate`, `duplicateReason`, and `isApproved` fields in-place.
  Future<DeduplicationResult> process(List<StatementTransaction> transactions) async {
    if (transactions.isEmpty) {
      return const DeduplicationResult(
        transactions: [],
        totalFound: 0,
        newCount: 0,
        duplicateCount: 0,
        totalDebits: 0,
        totalCredits: 0,
      );
    }

    // 1. Fetch existing expenses and extra credit (income)
    final rawExpenses = await _dbHelper.getAllExpenses();
    final existingExpenses = rawExpenses.map((m) => Expense.fromMap(m)).toList();

    final rawCredits = await _dbHelper.getAllIncome();
    final existingCredits = rawCredits.map((m) => ExtraCredit.fromMap(m)).toList();

    int duplicateCount = 0;
    double totalDebits = 0;
    double totalCredits = 0;

    for (final txn in transactions) {
      if (txn.isCredit) {
        totalCredits += txn.amount;
        final match = _findMatchingCredit(txn, existingCredits);
        if (match != null) {
          txn.isDuplicate = true;
          txn.duplicateReason = 'Matches existing income: ₹${match.amount.toStringAsFixed(2)} on ${match.date} (${match.mode})';
          txn.isApproved = false; // Auto-skip by default
          duplicateCount++;
        }
      } else {
        totalDebits += txn.amount;
        final match = _findMatchingExpense(txn, existingExpenses);
        if (match != null) {
          txn.isDuplicate = true;
          txn.duplicateReason = 'Matches existing expense: ₹${match.amount.toStringAsFixed(2)} on ${match.date} (${match.category})';
          txn.isApproved = false; // Auto-skip by default
          duplicateCount++;
        }
      }
    }

    final newCount = transactions.length - duplicateCount;

    return DeduplicationResult(
      transactions: transactions,
      totalFound: transactions.length,
      newCount: newCount,
      duplicateCount: duplicateCount,
      totalDebits: totalDebits,
      totalCredits: totalCredits,
    );
  }

  /// Check for matching expense by Exact Amount and Date (within +/- 1 day buffer)
  Expense? _findMatchingExpense(StatementTransaction txn, List<Expense> expenses) {
    final txnCalendarDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
    for (final exp in expenses) {
      // 1. Amount match (allowing 0.01 float tolerance)
      if ((exp.amount - txn.amount).abs() < 0.01) {
        // 2. Date match
        final expDate = _parseDateSafe(exp.date);
        if (expDate != null) {
          final expCalendarDay = DateTime(expDate.year, expDate.month, expDate.day);
          final diffDays = txnCalendarDay.difference(expCalendarDay).inDays.abs();
          // Match same day or +/- 1 day clearing window (safely handles month/year boundaries)
          if (diffDays <= 1) {
            return exp;
          }
        }
      }
    }
    return null;
  }

  /// Check for matching income by Exact Amount and Date (within +/- 1 day buffer)
  ExtraCredit? _findMatchingCredit(StatementTransaction txn, List<ExtraCredit> credits) {
    final txnCalendarDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
    for (final cred in credits) {
      // 1. Amount match
      if ((cred.amount - txn.amount).abs() < 0.01) {
        // 2. Date match
        final credDate = _parseDateSafe(cred.date);
        if (credDate != null) {
          final credCalendarDay = DateTime(credDate.year, credDate.month, credDate.day);
          final diffDays = txnCalendarDay.difference(credCalendarDay).inDays.abs();
          // Match same day or +/- 1 day clearing window (safely handles month/year boundaries)
          if (diffDays <= 1) {
            return cred;
          }
        }
      }
    }
    return null;
  }

  DateTime? _parseDateSafe(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Supported formats in db: 'dd/MM/yyyy', 'yyyy-MM-dd', 'dd-MM-yyyy'
    final formats = [
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'd/M/yyyy',
      'yyyy/MM/dd',
    ];

    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(trimmed);
      } catch (_) {}
    }
    return DateTime.tryParse(trimmed);
  }
}

class DeduplicationResult {
  final List<StatementTransaction> transactions;
  final int totalFound;
  final int newCount;
  final int duplicateCount;
  final double totalDebits;
  final double totalCredits;

  const DeduplicationResult({
    required this.transactions,
    required this.totalFound,
    required this.newCount,
    required this.duplicateCount,
    required this.totalDebits,
    required this.totalCredits,
  });
}
