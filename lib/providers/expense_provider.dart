import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  ExpenseNotifier() : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses({String? dateFrom, String? dateTo, String? category, String? bank}) async {
    state = const AsyncValue.loading();
    try {
      final rows = await DatabaseHelper.instance.getExpensesFiltered(
        dateFrom: dateFrom,
        dateTo: dateTo,
        category: category,
        bank: bank,
      );
      final expenses = rows.map((e) => Expense.fromMap(e)).toList();
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExpense(Expense expense) async {
    await DatabaseHelper.instance.insertExpense(expense.toMap());
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id != null) {
      await DatabaseHelper.instance.updateExpense(expense.id!, expense.toMap());
      await loadExpenses();
    }
  }
}

final expenseProvider = StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>((ref) {
  return ExpenseNotifier();
});
