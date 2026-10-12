import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/transfer.dart';

class TransferNotifier extends StateNotifier<AsyncValue<List<Transfer>>> {
  TransferNotifier() : super(const AsyncValue.loading()) {
    loadTransfers();
  }

  Future<void> loadTransfers() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final rows = await DatabaseHelper.instance.getAllTransfers();
      final items = rows.map((r) => Transfer.fromMap(r)).toList();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransfer(Transfer transfer) async {
    await DatabaseHelper.instance.insertTransfer(transfer.toMap());
    await loadTransfers();
  }

  Future<void> deleteTransfer(int id) async {
    await DatabaseHelper.instance.deleteTransfer(id);
    await loadTransfers();
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, AsyncValue<List<Transfer>>>((ref) {
  return TransferNotifier();
});
