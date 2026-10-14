import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/services/financial_analytics_service.dart';
import 'package:finance_manager/utils/formatters.dart';

void main() {
  group('FinancialAnalyticsService - Category Classification', () {
    test('isInvestmentCategory correctly identifies investment category', () {
      expect(FinancialAnalyticsService.isInvestmentCategory('SIP & Investments'), isTrue);
      expect(FinancialAnalyticsService.isInvestmentCategory('sip & investments'), isTrue);
      expect(FinancialAnalyticsService.isInvestmentCategory('Food'), isFalse);
      expect(FinancialAnalyticsService.isInvestmentCategory('Loan'), isFalse);
    });

    test('isNeedExpense correctly identifies essential needs vs lifestyle wants', () {
      // Definite Needs
      expect(FinancialAnalyticsService.isNeedExpense('Home Send', 'House Rent'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Home Send', 'Papa'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Bills & Utilities', 'Electricity Bill'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Bills & Utilities', 'Mobile & Wifi'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Loan', 'Personal Loan'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Credit Card Payment', 'HDFC Card'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Health & Medical', 'Medicines / Pharmacy'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Quick Ecommerce', 'Blinkit'), isTrue);

      // Food: Groceries are Needs, Dining Out/Swiggy are Wants
      expect(FinancialAnalyticsService.isNeedExpense('Food', 'Groceries'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Food', 'Zomato / Swiggy'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Food', 'Dining Out'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Food', 'Cafe & Snacks'), isFalse);

      // Traveling: Fuel and Metro are Needs, Cabs and Flights are Wants
      expect(FinancialAnalyticsService.isNeedExpense('Traveling', 'Fuel / Petrol'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Traveling', 'Metro / Bus'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Traveling', 'Vehicle Service / Fastag'), isTrue);
      expect(FinancialAnalyticsService.isNeedExpense('Traveling', 'Cab / Auto / Taxi'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Traveling', 'Flight / Train'), isFalse);

      // Shopping and Entertainment are Wants
      expect(FinancialAnalyticsService.isNeedExpense('Shopping', 'Clothing & Footwear'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Shopping', 'Electronics & Gadgets'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Entertainment', 'Movies & Outing'), isFalse);
      expect(FinancialAnalyticsService.isNeedExpense('Entertainment', 'Vacation & Trips'), isFalse);

      // Investments are not Needs (they are Savings)
      expect(FinancialAnalyticsService.isNeedExpense('SIP & Investments', 'Mutual Funds'), isFalse);
    });
  });

  group('FinancialAnalyticsService - 50-30-20 Rule Gauge Meter', () {
    test('computes balanced 50-30-20 ratio and generates positive advice', () {
      const income = 100000.0;
      final expenses = [
        {'category': 'Bills & Utilities', 'sub_category': 'Electricity', 'amount': 20000.0},
        {'category': 'Food', 'sub_category': 'Groceries', 'amount': 25000.0}, // Needs = 45k (45%)
        {'category': 'Shopping', 'sub_category': 'Clothes', 'amount': 15000.0},
        {'category': 'Food', 'sub_category': 'Dining Out', 'amount': 10000.0}, // Wants = 25k (25%)
        {'category': 'SIP & Investments', 'sub_category': 'Mutual Funds', 'amount': 20000.0}, // Inv = 20k, Surplus = 10k -> Savings = 30k (30%)
      ];

      final report = FinancialAnalyticsService.computeFiftyThirtyTwenty(
        totalIncome: income,
        categorizedExpenses: expenses,
      );

      expect(report.totalIncome, equals(100000.0));
      expect(report.needsAmount, equals(45000.0));
      expect(report.wantsAmount, equals(25000.0));
      expect(report.savingsAmount, equals(30000.0)); // 20k inv + 10k cash surplus

      expect(report.needsPercentage, equals(45.0));
      expect(report.wantsPercentage, equals(25.0));
      expect(report.savingsPercentage, equals(30.0));

      expect(report.isNeedsSafe, isTrue); // <= 50%
      expect(report.isWantsSafe, isTrue); // <= 30%
      expect(report.isSavingsSafe, isTrue); // >= 20%
      expect(report.advice, contains('Golden Ratio'));
    });

    test('flags high needs when essential expenses exceed 50%', () {
      const income = 50000.0;
      final expenses = [
        {'category': 'Home Send', 'sub_category': 'House Rent', 'amount': 30000.0}, // Needs = 30k (60%)
        {'category': 'Shopping', 'sub_category': 'Clothes', 'amount': 5000.0},       // Wants = 5k (10%)
        {'category': 'SIP & Investments', 'sub_category': 'SIP', 'amount': 5000.0},  // Inv = 5k, Surplus = 10k -> 15k (30%)
      ];

      final report = FinancialAnalyticsService.computeFiftyThirtyTwenty(
        totalIncome: income,
        categorizedExpenses: expenses,
      );

      expect(report.needsPercentage, equals(60.0));
      expect(report.isNeedsSafe, isFalse);
      expect(report.advice, contains('Essential Needs are high'));
    });

    test('handles zero income fallback to expense budget base gracefully', () {
      final expenses = [
        {'category': 'Bills & Utilities', 'sub_category': 'Wifi', 'amount': 5000.0}, // Need: 50%
        {'category': 'Shopping', 'sub_category': 'Shoes', 'amount': 3000.0},          // Want: 30%
        {'category': 'SIP & Investments', 'sub_category': 'PPF', 'amount': 2000.0},  // Savings: 20%
      ];

      final report = FinancialAnalyticsService.computeFiftyThirtyTwenty(
        totalIncome: 0.0,
        categorizedExpenses: expenses,
      );

      expect(report.needsPercentage, equals(50.0));
      expect(report.wantsPercentage, equals(30.0));
      expect(report.savingsPercentage, equals(20.0));
      expect(report.isNeedsSafe, isTrue);
      expect(report.isWantsSafe, isTrue);
      expect(report.isSavingsSafe, isTrue);
    });
  });

  group('FinancialAnalyticsService - Emergency Fund Runway Indicator', () {
    test('computes exact 5.4 months runway for ₹2,70,000 cash and ₹50,000 monthly burn', () {
      final report = FinancialAnalyticsService.computeEmergencyRunway(
        totalLiquidCash: 270000.0,
        monthlyBurnRate: 50000.0,
      );

      expect(report.totalLiquidCash, equals(270000.0));
      expect(report.monthlyBurnRate, equals(50000.0));
      expect(report.runwayMonths, closeTo(5.4, 0.01));
      expect(report.tier, equals(EmergencyRunwayTier.moderate));
      expect(report.statusLabel, equals('5.4 Months Buffer'));
      expect(report.recommendation, contains('Moderate Cushion'));
    });

    test('flags superSafe when runway exceeds 6.0 months', () {
      final report = FinancialAnalyticsService.computeEmergencyRunway(
        totalLiquidCash: 600000.0,
        monthlyBurnRate: 60000.0,
      );

      expect(report.runwayMonths, equals(10.0));
      expect(report.tier, equals(EmergencyRunwayTier.superSafe));
      expect(report.statusLabel, equals('10.0 Months Safe'));
      expect(report.recommendation, contains('Super Safe'));
    });

    test('flags low cushion and urgent action when runway is under 3 months', () {
      final report = FinancialAnalyticsService.computeEmergencyRunway(
        totalLiquidCash: 80000.0,
        monthlyBurnRate: 50000.0,
      );

      expect(report.runwayMonths, closeTo(1.6, 0.01));
      expect(report.tier, equals(EmergencyRunwayTier.low));
      expect(report.statusLabel, contains('Action Needed'));
      expect(report.recommendation, contains('Low Cushion'));
    });

    test('handles zero burn rate gracefully without division by zero', () {
      final report = FinancialAnalyticsService.computeEmergencyRunway(
        totalLiquidCash: 100000.0,
        monthlyBurnRate: 0.0,
      );

      expect(report.tier, equals(EmergencyRunwayTier.noExpense));
      expect(report.statusLabel, equals('Zero Monthly Burn'));
    });
  });

  group('FinancialAnalyticsService - Monthly Savings Rate % Indicator', () {
    test('assigns Elite / FIRE Saver tier for >= 50% savings rate', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 100000.0,
        nonInvestmentExpense: 40000.0,
        monthlyInvestments: 30000.0,
      );

      expect(report.savingsRatePercent, equals(60.0));
      expect(report.tier, equals(SavingsRateTier.elite));
      expect(report.tierTitle, equals('Elite / FIRE Saver'));
      expect(report.tierBadge, equals('🏆 Elite'));
    });

    test('assigns Super Saver tier for 30% to 49% savings rate', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 100000.0,
        nonInvestmentExpense: 65000.0,
        monthlyInvestments: 20000.0,
      );

      expect(report.savingsRatePercent, equals(35.0));
      expect(report.tier, equals(SavingsRateTier.superSaver));
      expect(report.tierTitle, equals('Super Saver'));
      expect(report.tierBadge, equals('🌟 Super Saver'));
    });

    test('assigns Healthy Saver tier for 20% to 29% savings rate', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 80000.0,
        nonInvestmentExpense: 60000.0,
        monthlyInvestments: 15000.0,
      );

      expect(report.savingsRatePercent, equals(25.0));
      expect(report.tier, equals(SavingsRateTier.healthy));
      expect(report.tierTitle, equals('Healthy Saver'));
      expect(report.tierBadge, equals('🟢 Healthy'));
    });

    test('assigns Developing Saver tier for 5% to 19% savings rate', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 50000.0,
        nonInvestmentExpense: 45000.0,
        monthlyInvestments: 2500.0,
      );

      expect(report.savingsRatePercent, equals(10.0));
      expect(report.tier, equals(SavingsRateTier.developing));
      expect(report.tierBadge, equals('🟡 Developing'));
    });

    test('assigns Deficit tier when non-investment expenses exceed income', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 50000.0,
        nonInvestmentExpense: 60000.0,
        monthlyInvestments: 0.0,
      );

      expect(report.savingsRatePercent, equals(-20.0));
      expect(report.tier, equals(SavingsRateTier.deficit));
      expect(report.tierTitle, equals('Deficit / Overspent'));
      expect(report.tierBadge, equals('🔴 Deficit'));
    });

    test('handles zero income by assigning noIncome tier', () {
      final report = FinancialAnalyticsService.computeSavingsRate(
        monthlyIncome: 0.0,
        nonInvestmentExpense: 20000.0,
        monthlyInvestments: 5000.0,
      );

      expect(report.tier, equals(SavingsRateTier.noIncome));
      expect(report.tierBadge, equals('⚪ No Income'));
    });
  });

  group('FinancialAnalyticsService - Equity vs Debt vs Gold vs Cash Allocation', () {
    test('accurately classifies holdings into Equity, Debt, Gold, and Cash', () {
      final allocations = [
        {'sub_category': 'Mutual Funds (SIP)', 'total': 400000.0},
        {'sub_category': 'Stocks / Shares', 'total': 200000.0}, // Equity = 600k
        {'sub_category': 'FD', 'total': 150000.0},
        {'sub_category': 'PPF', 'total': 100000.0},            // Debt = 250k
        {'sub_category': 'Gold / SGB', 'total': 50000.0},      // Gold = 50k
      ];
      const liquidCash = 100000.0;                             // Cash = 100k
      // Total Net Wealth = 1,000,000

      final report = FinancialAnalyticsService.computeAssetAllocation(
        investmentAllocations: allocations,
        totalLiquidCash: liquidCash,
      );

      expect(report.equityAmount, equals(600000.0));
      expect(report.debtAmount, equals(250000.0));
      expect(report.goldAmount, equals(50000.0));
      expect(report.cashAmount, equals(100000.0));
      expect(report.totalNetWealth, equals(1000000.0));

      expect(report.equityPercent, equals(60.0));
      expect(report.debtPercent, equals(25.0));
      expect(report.goldPercent, equals(5.0));
      expect(report.cashPercent, equals(10.0));

      expect(report.diversificationSummary, contains('Balanced Portfolio'));
    });

    test('warns when liquid cash is disproportionately high', () {
      final allocations = [
        {'sub_category': 'SIP', 'total': 50000.0},
      ];
      const liquidCash = 200000.0; // Total 250k, Cash is 80%

      final report = FinancialAnalyticsService.computeAssetAllocation(
        investmentAllocations: allocations,
        totalLiquidCash: liquidCash,
      );

      expect(report.cashPercent, equals(80.0));
      expect(report.diversificationSummary, contains('Cash Heavy'));
    });
  });

  group('AppFormatters - Robust Currency Parsing & Sanitization', () {
    test('parses Indian number format with commas and currency symbols accurately', () {
      expect(AppFormatters.parseCurrency('₹1,50,000'), equals(150000.0));
      expect(AppFormatters.parseCurrency('₹ 25,000.50'), equals(25000.50));
      expect(AppFormatters.parseCurrency('1,500'), equals(1500.0));
      expect(AppFormatters.parseCurrency('  ₹ 99,999  '), equals(99999.0));
      expect(AppFormatters.parseCurrency('\$500'), equals(500.0));
      expect(AppFormatters.parseCurrency('0'), equals(0.0));
    });

    test('rejects malformed text safely by returning null', () {
      expect(AppFormatters.parseCurrency(''), isNull);
      expect(AppFormatters.parseCurrency('   '), isNull);
      expect(AppFormatters.parseCurrency('abc'), isNull);
      expect(AppFormatters.parseCurrency('₹abc'), isNull);
      expect(AppFormatters.parseCurrency(null), isNull);
    });
  });
}
