import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/extra_credit.dart';
import '../models/transfer.dart';
import '../models/transaction_filter.dart';
import '../utils/formatters.dart';
import 'expense_provider.dart';
import 'income_provider.dart';
import 'transfer_provider.dart';

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setBank(String? bank) {
    if (bank == null || bank == 'All Banks') {
      state = state.copyWith(clearBank: true);
    } else {
      state = state.copyWith(bank: bank);
    }
  }

  void setDatePreset(DateFilterPreset preset) {
    state = state.copyWith(datePreset: preset);
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      datePreset: DateFilterPreset.customRange,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setSpecificMonth(int month, int year) {
    state = state.copyWith(
      datePreset: DateFilterPreset.specificMonth,
      selectedMonth: month,
      selectedYear: year,
    );
  }

  void setCategory(String? category) {
    if (category == null || category == 'All Categories') {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(category: category);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setAmountRange(double? min, double? max) {
    state = state.copyWith(
      minAmount: min,
      clearMinAmount: min == null,
      maxAmount: max,
      clearMaxAmount: max == null,
    );
  }

  void setSortOption(TransactionSortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
  }

  void resetFilters() {
    state = const TransactionFilter();
  }

  void resetDate() {
    state = state.copyWith(datePreset: DateFilterPreset.allTime);
  }

  void resetBank() {
    state = state.copyWith(clearBank: true);
  }

  void resetCategory() {
    state = state.copyWith(clearCategory: true);
  }
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>((ref) {
  return TransactionFilterNotifier();
});

/// Filtered & sorted Expenses
final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final expenseAsync = ref.watch(expenseProvider);
  final filter = ref.watch(transactionFilterProvider);

  return expenseAsync.maybeWhen(
    data: (expenses) {
      final filtered = expenses.where((e) => filter.matchesExpense(e)).toList();

      switch (filter.sortOption) {
        case TransactionSortOption.dateDesc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(b.date).compareTo(AppFormatters.parseDbDate(a.date)));
          break;
        case TransactionSortOption.dateAsc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(a.date).compareTo(AppFormatters.parseDbDate(b.date)));
          break;
        case TransactionSortOption.amountDesc:
          filtered.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case TransactionSortOption.amountAsc:
          filtered.sort((a, b) => a.amount.compareTo(b.amount));
          break;
      }
      return filtered;
    },
    orElse: () => [],
  );
});

/// Filtered & sorted Income
final filteredIncomeProvider = Provider<List<ExtraCredit>>((ref) {
  final incomeAsync = ref.watch(incomeProvider);
  final filter = ref.watch(transactionFilterProvider);

  return incomeAsync.maybeWhen(
    data: (incomes) {
      final filtered = incomes.where((i) => filter.matchesIncome(i)).toList();

      switch (filter.sortOption) {
        case TransactionSortOption.dateDesc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(b.date).compareTo(AppFormatters.parseDbDate(a.date)));
          break;
        case TransactionSortOption.dateAsc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(a.date).compareTo(AppFormatters.parseDbDate(b.date)));
          break;
        case TransactionSortOption.amountDesc:
          filtered.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case TransactionSortOption.amountAsc:
          filtered.sort((a, b) => a.amount.compareTo(b.amount));
          break;
      }
      return filtered;
    },
    orElse: () => [],
  );
});

/// Filtered & sorted Transfers
final filteredTransfersProvider = Provider<List<Transfer>>((ref) {
  final transferAsync = ref.watch(transferProvider);
  final filter = ref.watch(transactionFilterProvider);

  return transferAsync.maybeWhen(
    data: (transfers) {
      final filtered = transfers.where((t) => filter.matchesTransfer(t)).toList();

      switch (filter.sortOption) {
        case TransactionSortOption.dateDesc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(b.date).compareTo(AppFormatters.parseDbDate(a.date)));
          break;
        case TransactionSortOption.dateAsc:
          filtered.sort((a, b) => AppFormatters.parseDbDate(a.date).compareTo(AppFormatters.parseDbDate(b.date)));
          break;
        case TransactionSortOption.amountDesc:
          filtered.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case TransactionSortOption.amountAsc:
          filtered.sort((a, b) => a.amount.compareTo(b.amount));
          break;
      }
      return filtered;
    },
    orElse: () => [],
  );
});

/// Combined, filtered & sorted Unified transactions (Expenses + Income + Transfers)
final filteredUnifiedTransactionsProvider = Provider<List<UnifiedTransaction>>((ref) {
  final expenseAsync = ref.watch(expenseProvider);
  final incomeAsync = ref.watch(incomeProvider);
  final transferAsync = ref.watch(transferProvider);
  final filter = ref.watch(transactionFilterProvider);

  final List<UnifiedTransaction> allItems = [];

  expenseAsync.whenData((list) {
    allItems.addAll(list.map((e) => UnifiedTransaction.fromExpense(e)));
  });

  incomeAsync.whenData((list) {
    allItems.addAll(list.map((i) => UnifiedTransaction.fromIncome(i)));
  });

  transferAsync.whenData((list) {
    allItems.addAll(list.map((t) => UnifiedTransaction.fromTransfer(t)));
  });

  final filtered = allItems.where((u) => filter.matchesUnified(u)).toList();

  switch (filter.sortOption) {
    case TransactionSortOption.dateDesc:
      filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      break;
    case TransactionSortOption.dateAsc:
      filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      break;
    case TransactionSortOption.amountDesc:
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
      break;
    case TransactionSortOption.amountAsc:
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
      break;
  }

  return filtered;
});

class TransactionSummary {
  final int totalCount;
  final double totalExpense;
  final double totalIncome;
  final double totalTransfer;
  final double netFlow;

  const TransactionSummary({
    required this.totalCount,
    required this.totalExpense,
    required this.totalIncome,
    required this.totalTransfer,
    required this.netFlow,
  });
}

final transactionSummaryProvider = Provider<TransactionSummary>((ref) {
  final expenses = ref.watch(filteredExpensesProvider);
  final income = ref.watch(filteredIncomeProvider);
  final transfers = ref.watch(filteredTransfersProvider);

  final totalExp = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  final totalInc = income.fold<double>(0.0, (sum, i) => sum + i.amount);
  final totalXfer = transfers.fold<double>(0.0, (sum, t) => sum + t.amount);

  return TransactionSummary(
    totalCount: expenses.length + income.length + transfers.length,
    totalExpense: totalExp,
    totalIncome: totalInc,
    totalTransfer: totalXfer,
    netFlow: totalInc - totalExp,
  );
});
