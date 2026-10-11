import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/extra_credit.dart';

class IncomeNotifier extends StateNotifier<AsyncValue<List<ExtraCredit>>> {
  IncomeNotifier() : super(const AsyncValue.loading()) {
    loadIncome();
  }

  Future<void> loadIncome() async {
    state = const AsyncValue.loading();
    try {
      final rows = await DatabaseHelper.instance.getAllIncome();
      final items = rows.map((r) => ExtraCredit.fromMap(r)).toList();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addIncome(ExtraCredit income) async {
    await DatabaseHelper.instance.insertIncome(income.toMap());
    await loadIncome();
  }

  Future<void> deleteIncome(int id) async {
    await DatabaseHelper.instance.deleteIncome(id);
    await loadIncome();
  }
}

final incomeProvider = StateNotifierProvider<IncomeNotifier, AsyncValue<List<ExtraCredit>>>((ref) {
  return IncomeNotifier();
});
