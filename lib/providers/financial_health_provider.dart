import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financial_analytics_service.dart';
import 'bank_provider.dart';
import 'expense_provider.dart';
import 'income_provider.dart';
import 'investment_provider.dart';

class HealthFilter {
  final int year;
  final int month;

  const HealthFilter(this.year, this.month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthFilter &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

/// Provider that calculates FinancialHealthReport for a specific year and month.
/// Auto-invalidates when expenses, incomes, bank balances, or investments change.
final financialHealthProvider =
    FutureProvider.family<FinancialHealthReport, HealthFilter>((ref, filter) async {
  // Listen to dependency providers so this re-computes automatically upon changes
  ref.watch(expenseProvider);
  ref.watch(incomeProvider);
  ref.watch(bankProvider);
  ref.watch(investmentProvider);

  return await FinancialAnalyticsService.computeHealthReport(
    year: filter.year,
    month: filter.month,
  );
});

/// Current selected month/year filter for financial health insights
final currentHealthFilterProvider = StateProvider<HealthFilter>((ref) {
  final now = DateTime.now();
  return HealthFilter(now.year, now.month);
});

/// Convenience provider watching the current month's health report
final currentHealthReportProvider = FutureProvider<FinancialHealthReport>((ref) async {
  final filter = ref.watch(currentHealthFilterProvider);
  return await ref.watch(financialHealthProvider(filter).future);
});
