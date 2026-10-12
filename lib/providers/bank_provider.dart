import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/bank.dart';

class BankBalanceInfo {
  final Bank bank;
  final double liveBalance;

  BankBalanceInfo({required this.bank, required this.liveBalance});
}

class BankNotifier extends StateNotifier<AsyncValue<List<BankBalanceInfo>>> {
  BankNotifier() : super(const AsyncValue.loading()) {
    loadBanks();
  }

  Future<void> loadBanks() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final rows = await DatabaseHelper.instance.getAllBanks();
      final banks = rows.map((b) => Bank.fromMap(b)).toList();
      
      final List<BankBalanceInfo> bankBalances = [];
      for (final bank in banks) {
        final bal = await DatabaseHelper.instance.getLiveBalance(bank.name);
        bankBalances.add(BankBalanceInfo(bank: bank, liveBalance: bal));
      }
      state = AsyncValue.data(bankBalances);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBank(String name, double startingBalance) async {
    await DatabaseHelper.instance.insertBank(name, startingBalance);
    await loadBanks();
  }

  Future<void> updateStartingBalance(int id, double balance) async {
    await DatabaseHelper.instance.updateBankBalance(id, balance);
    await loadBanks();
  }

  Future<void> updateBankLast4(int id, String? last4) async {
    await DatabaseHelper.instance.updateBankLast4(id, last4);
    await loadBanks();
  }
}

final bankProvider = StateNotifierProvider<BankNotifier, AsyncValue<List<BankBalanceInfo>>>((ref) {
  return BankNotifier();
});

final bankListProvider = bankProvider;
