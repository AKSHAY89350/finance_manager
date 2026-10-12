import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/expense.dart';
import 'package:finance_manager/models/extra_credit.dart';
import 'package:finance_manager/models/transfer.dart';
import 'package:finance_manager/models/transaction_filter.dart';
import 'package:finance_manager/utils/formatters.dart';

void main() {
  group('TransactionFilter Unit Tests', () {
    final now = DateTime.now();
    final todayStr = AppFormatters.dbDate(now);
    final lastMonthDate = DateTime(now.year, now.month - 1, 15);
    final lastMonthStr = AppFormatters.dbDate(lastMonthDate);

    final expense1 = Expense(
      id: 1,
      date: todayStr,
      category: 'Food',
      subCategory: 'Zomato',
      description: 'Dinner delivery',
      amount: 450.0,
      bank: 'HDFC',
    );

    final expense2 = Expense(
      id: 2,
      date: lastMonthStr,
      category: 'Shopping',
      subCategory: 'Amazon',
      description: 'Headphones',
      amount: 2500.0,
      bank: 'SBI',
    );

    final income1 = ExtraCredit(
      id: 1,
      date: todayStr,
      userName: 'Client XYZ',
      amount: 50000.0,
      mode: 'Salary',
      bank: 'HDFC',
    );

    final transfer1 = Transfer(
      id: 1,
      date: todayStr,
      fromBank: 'HDFC',
      toBank: 'SBI',
      amount: 10000.0,
      description: 'Savings allocation',
    );

    test('Default filter matches all transactions', () {
      const filter = TransactionFilter();
      expect(filter.isFiltered, isFalse);
      expect(filter.activeFilterCount, equals(0));

      expect(filter.matchesExpense(expense1), isTrue);
      expect(filter.matchesExpense(expense2), isTrue);
      expect(filter.matchesIncome(income1), isTrue);
      expect(filter.matchesTransfer(transfer1), isTrue);
    });

    test('Bank filter correctly filters expenses, income, and transfers', () {
      final hdfcFilter = const TransactionFilter().copyWith(bank: 'HDFC');
      expect(hdfcFilter.isFiltered, isTrue);
      expect(hdfcFilter.activeFilterCount, equals(1));

      expect(hdfcFilter.matchesExpense(expense1), isTrue);
      expect(hdfcFilter.matchesExpense(expense2), isFalse); // SBI
      expect(hdfcFilter.matchesIncome(income1), isTrue);
      expect(hdfcFilter.matchesTransfer(transfer1), isTrue); // from HDFC to SBI matches

      final sbiFilter = const TransactionFilter().copyWith(bank: 'SBI');
      expect(sbiFilter.matchesExpense(expense1), isFalse);
      expect(sbiFilter.matchesExpense(expense2), isTrue);
      expect(sbiFilter.matchesIncome(income1), isFalse);
      expect(sbiFilter.matchesTransfer(transfer1), isTrue); // to SBI matches
    });

    test('Date Preset: This Month vs Last Month', () {
      final thisMonthFilter = const TransactionFilter().copyWith(datePreset: DateFilterPreset.thisMonth);
      expect(thisMonthFilter.matchesExpense(expense1), isTrue);
      expect(thisMonthFilter.matchesExpense(expense2), isFalse);

      final lastMonthFilter = const TransactionFilter().copyWith(datePreset: DateFilterPreset.lastMonth);
      expect(lastMonthFilter.matchesExpense(expense1), isFalse);
      expect(lastMonthFilter.matchesExpense(expense2), isTrue);
    });

    test('Specific Month & Year Filter', () {
      final specificFilter = const TransactionFilter().copyWith(
        datePreset: DateFilterPreset.specificMonth,
        selectedMonth: lastMonthDate.month,
        selectedYear: lastMonthDate.year,
      );

      expect(specificFilter.matchesExpense(expense1), isFalse);
      expect(specificFilter.matchesExpense(expense2), isTrue);
    });

    test('Category Filter', () {
      final foodFilter = const TransactionFilter().copyWith(category: 'Food');
      expect(foodFilter.matchesExpense(expense1), isTrue);
      expect(foodFilter.matchesExpense(expense2), isFalse);
    });

    test('Search Query: By description, merchant name, and amount', () {
      final zomatoSearch = const TransactionFilter().copyWith(searchQuery: 'zomato');
      expect(zomatoSearch.matchesExpense(expense1), isTrue);
      expect(zomatoSearch.matchesExpense(expense2), isFalse);

      final amtSearch = const TransactionFilter().copyWith(searchQuery: '2500');
      expect(amtSearch.matchesExpense(expense1), isFalse);
      expect(amtSearch.matchesExpense(expense2), isTrue);

      final salarySearch = const TransactionFilter().copyWith(searchQuery: 'salary');
      expect(salarySearch.matchesIncome(income1), isTrue);
    });

    test('Amount Range Filter (Min & Max)', () {
      final rangeFilter = const TransactionFilter().copyWith(
        minAmount: 1000.0,
        maxAmount: 5000.0,
      );

      expect(rangeFilter.matchesExpense(expense1), isFalse); // 450
      expect(rangeFilter.matchesExpense(expense2), isTrue);  // 2500
      expect(rangeFilter.matchesIncome(income1), isFalse);   // 50000
    });

    test('Unified Transaction mapping and matching', () {
      final u1 = UnifiedTransaction.fromExpense(expense1);
      final u2 = UnifiedTransaction.fromIncome(income1);
      final u3 = UnifiedTransaction.fromTransfer(transfer1);

      expect(u1.kind, equals(TransactionKind.expense));
      expect(u2.kind, equals(TransactionKind.income));
      expect(u3.kind, equals(TransactionKind.transfer));

      final hdfcFilter = const TransactionFilter().copyWith(bank: 'HDFC');
      expect(hdfcFilter.matchesUnified(u1), isTrue);
      expect(hdfcFilter.matchesUnified(u2), isTrue);
      expect(hdfcFilter.matchesUnified(u3), isTrue);
    });
  });
}
