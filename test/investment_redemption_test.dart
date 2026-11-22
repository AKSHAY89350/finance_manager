import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/extra_credit.dart';
import 'package:finance_manager/models/transaction_filter.dart';

void main() {
  group('Investment Redemption & Stock Sale Unit Tests', () {
    test('ExtraCredit model correctly stores investment redemption fields', () {
      final redemption = ExtraCredit(
        id: 1,
        date: '2026-11-22',
        userName: 'Sold Stocks / Shares',
        amount: 700.0,
        mode: 'Stock / Investment Sale',
        bank: 'SBI',
        subCategory: 'Stocks / Shares',
        buyAmount: 500.0,
        profitAmount: 200.0,
        isInvestmentRedemption: true,
      );

      expect(redemption.amount, equals(700.0));
      expect(redemption.buyAmount, equals(500.0));
      expect(redemption.profitAmount, equals(200.0));
      expect(redemption.subCategory, equals('Stocks / Shares'));
      expect(redemption.isInvestmentRedemption, isTrue);

      final map = redemption.toMap();
      expect(map['amount'], equals(700.0));
      expect(map['buy_amount'], equals(500.0));
      expect(map['profit_amount'], equals(200.0));
      expect(map['sub_category'], equals('Stocks / Shares'));
      expect(map['is_investment_redemption'], equals(1));

      final fromDb = ExtraCredit.fromMap(map);
      expect(fromDb.amount, equals(700.0));
      expect(fromDb.buyAmount, equals(500.0));
      expect(fromDb.profitAmount, equals(200.0));
      expect(fromDb.subCategory, equals('Stocks / Shares'));
      expect(fromDb.isInvestmentRedemption, isTrue);
    });

    test('Calculation logic: Principal return erases buy amount, profit increases wealth', () {
      const buyPrice = 500.0;
      const sellPrice = 700.0;

      final profit = sellPrice - buyPrice;
      final returnPct = (profit / buyPrice) * 100;

      expect(profit, equals(200.0));
      expect(returnPct, equals(40.0));

      // Active investment deduction:
      // Initial investment: 500.0
      // Redeemed principal: 500.0
      const activeInitial = 500.0;
      final remainingActive = activeInitial - buyPrice;
      expect(remainingActive, equals(0.0)); // Investment erased!
    });

    test('Partial sale calculation logic', () {
      const totalInvestedInSIP = 5000.0;
      const partialBuyAmount = 2000.0;
      const partialSaleAmount = 2600.0;

      final profit = partialSaleAmount - partialBuyAmount;
      final returnPct = (profit / partialBuyAmount) * 100;

      expect(profit, equals(600.0));
      expect(returnPct, equals(30.0));

      final remainingActive = totalInvestedInSIP - partialBuyAmount;
      expect(remainingActive, equals(3000.0));
    });

    test('UnifiedTransaction maps investment redemption with clear title, subtitle, and badges', () {
      final redemption = ExtraCredit(
        id: 42,
        date: '2026-11-22',
        userName: null,
        amount: 700.0,
        mode: 'Stock / Investment Sale',
        bank: 'SBI',
        subCategory: 'Stocks / Shares',
        buyAmount: 500.0,
        profitAmount: 200.0,
        isInvestmentRedemption: true,
      );

      final unified = UnifiedTransaction.fromIncome(redemption);

      expect(unified.kind, equals(TransactionKind.income));
      expect(unified.amount, equals(700.0));
      expect(unified.bank, equals('SBI'));
      expect(unified.title, equals('Stocks / Shares Sale'));
      expect(unified.subtitle, contains('Buy: ₹500'));
      expect(unified.subtitle, contains('Profit: +₹200'));
      expect(unified.category, equals('Stocks / Shares'));
    });

    test('TransactionFilter correctly matches investment redemption by subCategory', () {
      final redemption = ExtraCredit(
        id: 42,
        date: '2026-11-22',
        userName: null,
        amount: 700.0,
        mode: 'Stock / Investment Sale',
        bank: 'SBI',
        subCategory: 'Stocks / Shares',
        buyAmount: 500.0,
        profitAmount: 200.0,
        isInvestmentRedemption: true,
      );

      final filterCategory = TransactionFilter(
        category: 'Stocks / Shares',
      );
      expect(filterCategory.matchesIncome(redemption), isTrue);

      final filterSearch = TransactionFilter(
        searchQuery: 'Stocks',
      );
      expect(filterSearch.matchesIncome(redemption), isTrue);

      final filterDiffBank = TransactionFilter(
        bank: 'HDFC',
      );
      expect(filterDiffBank.matchesIncome(redemption), isFalse);

      final filterSameBank = TransactionFilter(
        bank: 'SBI',
      );
      expect(filterSameBank.matchesIncome(redemption), isTrue);
    });
  });
}
