import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/initial_investment.dart';

class InvestmentHoldingInfo {
  final InitialInvestment asset;
  final double liveTotal; // startingBalance + expenses
  final int txnCount;

  InvestmentHoldingInfo({
    required this.asset,
    required this.liveTotal,
    this.txnCount = 0,
  });
}

class InvestmentNotifier extends StateNotifier<AsyncValue<List<InvestmentHoldingInfo>>> {
  InvestmentNotifier() : super(const AsyncValue.loading()) {
    loadInvestments();
  }

  Future<void> loadInvestments() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final rows = await DatabaseHelper.instance.getAllInitialInvestments();
      final assets = rows.map((r) => InitialInvestment.fromMap(r)).toList();

      final List<InvestmentHoldingInfo> holdings = [];
      for (final asset in assets) {
        final liveTotal = await DatabaseHelper.instance.getLiveInvestmentHolding(asset.assetName);
        holdings.add(InvestmentHoldingInfo(
          asset: asset,
          liveTotal: liveTotal,
        ));
      }
      state = AsyncValue.data(holdings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addInvestment(String name, double startingBalance, {String? notes}) async {
    await DatabaseHelper.instance.insertInitialInvestment({
      'asset_name': name.trim(),
      'starting_balance': startingBalance,
      'category': 'SIP & Investments',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await loadInvestments();
  }

  Future<void> updateStartingBalance(int id, double balance) async {
    await DatabaseHelper.instance.updateInitialInvestmentBalance(id, balance);
    await loadInvestments();
  }

  Future<void> deleteInvestment(int id) async {
    await DatabaseHelper.instance.deleteInitialInvestment(id);
    await loadInvestments();
  }
}

final investmentProvider =
    StateNotifierProvider<InvestmentNotifier, AsyncValue<List<InvestmentHoldingInfo>>>((ref) {
  return InvestmentNotifier();
});

final totalInvestmentPortfolioValueProvider = FutureProvider<double>((ref) async {
  ref.watch(investmentProvider);
  return await DatabaseHelper.instance.getTotalInvested();
});
