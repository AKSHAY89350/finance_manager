import 'expense.dart';
import 'extra_credit.dart';
import 'transfer.dart';
import '../utils/formatters.dart';

enum DateFilterPreset {
  allTime,
  thisMonth,
  lastMonth,
  last30Days,
  thisYear,
  specificMonth,
  customRange,
}

enum TransactionSortOption {
  dateDesc, // Newest first
  dateAsc, // Oldest first
  amountDesc, // Amount: High to Low
  amountAsc, // Amount: Low to High
}

enum TransactionKind {
  expense,
  income,
  transfer,
}

class UnifiedTransaction {
  final TransactionKind kind;
  final int? id;
  final String date;
  final DateTime dateTime;
  final double amount;
  final String bank;
  final String title;
  final String? subtitle;
  final String? category;
  final Expense? originalExpense;
  final ExtraCredit? originalIncome;
  final Transfer? originalTransfer;

  UnifiedTransaction({
    required this.kind,
    this.id,
    required this.date,
    required this.dateTime,
    required this.amount,
    required this.bank,
    required this.title,
    this.subtitle,
    this.category,
    this.originalExpense,
    this.originalIncome,
    this.originalTransfer,
  });

  factory UnifiedTransaction.fromExpense(Expense e) {
    return UnifiedTransaction(
      kind: TransactionKind.expense,
      id: e.id,
      date: e.date,
      dateTime: AppFormatters.parseDbDate(e.date),
      amount: e.amount,
      bank: e.bank,
      title: e.subCategory ?? e.category,
      subtitle: e.description,
      category: e.category,
      originalExpense: e,
    );
  }

  factory UnifiedTransaction.fromIncome(ExtraCredit i) {
    return UnifiedTransaction(
      kind: TransactionKind.income,
      id: i.id,
      date: i.date,
      dateTime: AppFormatters.parseDbDate(i.date),
      amount: i.amount,
      bank: i.bank,
      title: i.mode,
      subtitle: i.userName,
      category: i.mode,
      originalIncome: i,
    );
  }

  factory UnifiedTransaction.fromTransfer(Transfer t) {
    return UnifiedTransaction(
      kind: TransactionKind.transfer,
      id: t.id,
      date: t.date,
      dateTime: AppFormatters.parseDbDate(t.date),
      amount: t.amount,
      bank: '${t.fromBank} ➔ ${t.toBank}',
      title: '${t.fromBank} ➔ ${t.toBank}',
      subtitle: t.description,
      originalTransfer: t,
    );
  }
}

class TransactionFilter {
  final DateFilterPreset datePreset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final int? selectedMonth; // 1 - 12
  final int? selectedYear;
  final String? bank; // null = all banks
  final String? category; // null = all categories
  final String searchQuery;
  final double? minAmount;
  final double? maxAmount;
  final TransactionSortOption sortOption;

  const TransactionFilter({
    this.datePreset = DateFilterPreset.allTime,
    this.customStartDate,
    this.customEndDate,
    this.selectedMonth,
    this.selectedYear,
    this.bank,
    this.category,
    this.searchQuery = '',
    this.minAmount,
    this.maxAmount,
    this.sortOption = TransactionSortOption.dateDesc,
  });

  TransactionFilter copyWith({
    DateFilterPreset? datePreset,
    DateTime? customStartDate,
    DateTime? customEndDate,
    int? selectedMonth,
    int? selectedYear,
    String? bank,
    bool clearBank = false,
    String? category,
    bool clearCategory = false,
    String? searchQuery,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
    TransactionSortOption? sortOption,
  }) {
    return TransactionFilter(
      datePreset: datePreset ?? this.datePreset,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      bank: clearBank ? null : (bank ?? this.bank),
      category: clearCategory ? null : (category ?? this.category),
      searchQuery: searchQuery ?? this.searchQuery,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      sortOption: sortOption ?? this.sortOption,
    );
  }

  bool get isFiltered {
    return datePreset != DateFilterPreset.allTime ||
        bank != null ||
        category != null ||
        searchQuery.trim().isNotEmpty ||
        minAmount != null ||
        maxAmount != null ||
        sortOption != TransactionSortOption.dateDesc;
  }

  int get activeFilterCount {
    int count = 0;
    if (datePreset != DateFilterPreset.allTime) count++;
    if (bank != null) count++;
    if (category != null) count++;
    if (searchQuery.trim().isNotEmpty) count++;
    if (minAmount != null || maxAmount != null) count++;
    if (sortOption != TransactionSortOption.dateDesc) count++;
    return count;
  }

  String getDateLabel() {
    switch (datePreset) {
      case DateFilterPreset.allTime:
        return 'All Time';
      case DateFilterPreset.thisMonth:
        return 'This Month';
      case DateFilterPreset.lastMonth:
        return 'Last Month';
      case DateFilterPreset.last30Days:
        return 'Last 30 Days';
      case DateFilterPreset.thisYear:
        return 'This Year';
      case DateFilterPreset.specificMonth:
        if (selectedMonth != null && selectedYear != null) {
          final dt = DateTime(selectedYear!, selectedMonth!);
          return AppFormatters.shortMonthYear(dt);
        }
        return 'Month';
      case DateFilterPreset.customRange:
        if (customStartDate != null && customEndDate != null) {
          return '${AppFormatters.shortDate(customStartDate!)} - ${AppFormatters.shortDate(customEndDate!)}';
        } else if (customStartDate != null) {
          return 'From ${AppFormatters.shortDate(customStartDate!)}';
        }
        return 'Custom Range';
    }
  }

  bool matchesDate(DateTime dt) {
    final now = DateTime.now();
    switch (datePreset) {
      case DateFilterPreset.allTime:
        return true;
      case DateFilterPreset.thisMonth:
        return dt.year == now.year && dt.month == now.month;
      case DateFilterPreset.lastMonth:
        final lastMonthDt = DateTime(now.year, now.month - 1, 1);
        return dt.year == lastMonthDt.year && dt.month == lastMonthDt.month;
      case DateFilterPreset.last30Days:
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        return dt.isAfter(thirtyDaysAgo.subtract(const Duration(days: 1))) &&
            dt.isBefore(now.add(const Duration(days: 1)));
      case DateFilterPreset.thisYear:
        return dt.year == now.year;
      case DateFilterPreset.specificMonth:
        if (selectedMonth != null && selectedYear != null) {
          return dt.year == selectedYear && dt.month == selectedMonth;
        }
        return true;
      case DateFilterPreset.customRange:
        if (customStartDate != null && customEndDate != null) {
          final start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
          final end = DateTime(customEndDate!.year, customEndDate!.month, customEndDate!.day, 23, 59, 59);
          return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(end.add(const Duration(seconds: 1)));
        } else if (customStartDate != null) {
          final start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
          return dt.isAfter(start.subtract(const Duration(seconds: 1)));
        }
        return true;
    }
  }

  bool matchesAmount(double amount) {
    if (minAmount != null && amount < minAmount!) return false;
    if (maxAmount != null && amount > maxAmount!) return false;
    return true;
  }

  bool _matchesQuery(
    String query, {
    required List<String?> textFields,
    required double amount,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    for (final text in textFields) {
      if (text != null && text.toLowerCase().contains(q)) return true;
    }

    // Amount match: test raw number, formatted currency, and clean query without symbols/commas
    final rawAmt = amount.toString();
    final formattedAmt = AppFormatters.currency(amount).toLowerCase();
    final cleanQ = q.replaceAll('₹', '').replaceAll(',', '').trim();

    if (rawAmt.contains(q) || formattedAmt.contains(q)) return true;
    if (cleanQ.isNotEmpty && (rawAmt.contains(cleanQ) || formattedAmt.contains(cleanQ))) {
      return true;
    }

    return false;
  }

  bool matchesExpense(Expense e) {
    final dt = AppFormatters.parseDbDate(e.date);
    if (!matchesDate(dt)) return false;
    if (bank != null && e.bank.toLowerCase() != bank!.toLowerCase()) return false;
    if (category != null && e.category.toLowerCase() != category!.toLowerCase()) return false;
    if (!matchesAmount(e.amount)) return false;

    if (searchQuery.trim().isNotEmpty) {
      if (!_matchesQuery(
        searchQuery,
        textFields: [e.category, e.subCategory, e.description, e.bank],
        amount: e.amount,
      )) {
        return false;
      }
    }

    return true;
  }

  bool matchesIncome(ExtraCredit i) {
    final dt = AppFormatters.parseDbDate(i.date);
    if (!matchesDate(dt)) return false;
    if (bank != null && i.bank.toLowerCase() != bank!.toLowerCase()) return false;
    if (category != null && i.mode.toLowerCase() != category!.toLowerCase()) return false;
    if (!matchesAmount(i.amount)) return false;

    if (searchQuery.trim().isNotEmpty) {
      if (!_matchesQuery(
        searchQuery,
        textFields: [i.mode, i.userName, i.bank],
        amount: i.amount,
      )) {
        return false;
      }
    }

    return true;
  }

  bool matchesTransfer(Transfer t) {
    final dt = AppFormatters.parseDbDate(t.date);
    if (!matchesDate(dt)) return false;
    if (bank != null &&
        t.fromBank.toLowerCase() != bank!.toLowerCase() &&
        t.toBank.toLowerCase() != bank!.toLowerCase()) {
      return false;
    }
    if (category != null) return false;
    if (!matchesAmount(t.amount)) return false;

    if (searchQuery.trim().isNotEmpty) {
      if (!_matchesQuery(
        searchQuery,
        textFields: [t.fromBank, t.toBank, t.description],
        amount: t.amount,
      )) {
        return false;
      }
    }

    return true;
  }

  bool matchesUnified(UnifiedTransaction u) {
    if (!matchesDate(u.dateTime)) return false;
    if (bank != null) {
      if (u.kind == TransactionKind.transfer && u.originalTransfer != null) {
        final t = u.originalTransfer!;
        if (t.fromBank.toLowerCase() != bank!.toLowerCase() &&
            t.toBank.toLowerCase() != bank!.toLowerCase()) {
          return false;
        }
      } else if (u.bank.toLowerCase() != bank!.toLowerCase()) {
        return false;
      }
    }
    if (category != null) {
      if (u.category == null || u.category!.toLowerCase() != category!.toLowerCase()) {
        return false;
      }
    }
    if (!matchesAmount(u.amount)) return false;

    if (searchQuery.trim().isNotEmpty) {
      if (!_matchesQuery(
        searchQuery,
        textFields: [u.title, u.subtitle, u.bank, u.category],
        amount: u.amount,
      )) {
        return false;
      }
    }

    return true;
  }
}
