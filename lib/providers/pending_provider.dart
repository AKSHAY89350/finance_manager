import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pending_transaction.dart';
import '../models/expense.dart';
import '../models/extra_credit.dart';
import '../db/database_helper.dart';
import '../services/sms_parser_service.dart';
import 'expense_provider.dart';
import 'income_provider.dart';
import 'bank_provider.dart';

final pendingNotifierProvider =
    StateNotifierProvider<PendingNotifier, AsyncValue<List<PendingTransaction>>>(
  (ref) => PendingNotifier(ref),
);

/// Count of pending unconfirmed transactions for badging
final pendingCountProvider = Provider<int>((ref) {
  final pendingAsync = ref.watch(pendingNotifierProvider);
  return pendingAsync.maybeWhen(
    data: (list) => list.length,
    orElse: () => 0,
  );
});

class PendingNotifier extends StateNotifier<AsyncValue<List<PendingTransaction>>> {
  final Ref _ref;

  PendingNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadPending();
  }

  /// Load pending unconfirmed transactions from SQLite
  Future<void> loadPending() async {
    try {
      final list = await DatabaseHelper.instance.getPendingTransactions(status: 'PENDING');
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Process incoming SMS/Notification message and add to staging queue if valid
  Future<bool> processIncomingMessage(
    String rawText, {
    String? sender,
    DateTime? timestamp,
  }) async {
    final parsed = await SmsParserService.parseMessage(
      rawText,
      sender: sender,
      timestamp: timestamp,
    );

    if (parsed == null) return false;

    // Check if fingerprint already exists
    final exists = await DatabaseHelper.instance.hasTransactionFingerprint(parsed.fingerprint);
    if (exists) return false;

    await DatabaseHelper.instance.insertPendingTransaction(parsed);
    await loadPending();
    return true;
  }

  /// Confirm transaction and move it into the official expenses or income ledger
  Future<void> confirmTransaction(
    PendingTransaction txn, {
    String? category,
    String? subCategory,
    String? bank,
    double? amount,
  }) async {
    final finalCategory = category ?? txn.suggestedCategory;
    final finalSubCategory = subCategory ?? txn.suggestedSubCategory;
    final finalBank = bank ?? txn.bank;
    final finalAmount = amount ?? txn.amount;

    if (txn.type == 'EXPENSE') {
      // 1. Insert into official expenses table
      final expense = Expense(
        date: txn.date,
        category: finalCategory,
        subCategory: finalSubCategory,
        description: txn.merchant,
        amount: finalAmount,
        bank: finalBank,
      );
      await _ref.read(expenseProvider.notifier).addExpense(expense);
    } else {
      // 2. Insert into official extra_credit table
      final income = ExtraCredit(
        date: txn.date,
        userName: txn.merchant,
        amount: finalAmount,
        mode: 'Salary',
        bank: finalBank,
      );
      await _ref.read(incomeProvider.notifier).addIncome(income);
    }

    // 3. Learn user's preferred category for this merchant in SQLite
    if (txn.type == 'EXPENSE') {
      await DatabaseHelper.instance.saveMerchantRule(
        keyword: txn.merchant,
        category: finalCategory,
        subCategory: finalSubCategory,
      );
    }

    // 4. Mark pending status as CONFIRMED in staging table
    if (txn.id != null) {
      await DatabaseHelper.instance.updatePendingTransactionStatus(txn.id!, 'CONFIRMED');
    }

    // 5. Refresh bank balances and pending list
    _ref.invalidate(bankListProvider);
    await loadPending();
  }

  /// Discard a detected transaction (spam, duplicate, or user rejected)
  Future<void> discardTransaction(PendingTransaction txn) async {
    if (txn.id != null) {
      await DatabaseHelper.instance.updatePendingTransactionStatus(txn.id!, 'DISCARDED');
    }
    await loadPending();
  }

  /// Edit and update a pending transaction before confirming
  Future<void> updatePending(PendingTransaction updated) async {
    await DatabaseHelper.instance.updatePendingTransaction(updated);
    await loadPending();
  }
}
