import '../db/database_helper.dart';
import '../utils/formatters.dart';

enum EmergencyRunwayTier {
  superSafe,   // >= 6.0 months
  moderate,    // 3.0 .. 5.9 months
  low,         // < 3.0 months
  noExpense,   // 0 monthly burn
}

enum SavingsRateTier {
  elite,       // >= 50%
  superSaver,  // 30% .. 49%
  healthy,     // 20% .. 29%
  developing,  // 5% .. 19%
  breakEven,   // 0% .. 4%
  deficit,     // < 0%
  noIncome,    // 0 income
}

class FiftyThirtyTwentyReport {
  final double totalIncome;
  final double totalExpense;
  final double needsAmount;
  final double wantsAmount;
  final double savingsAmount;
  
  final double needsPercentage;
  final double wantsPercentage;
  final double savingsPercentage;
  
  final bool isNeedsSafe; // <= 50%
  final bool isWantsSafe; // <= 30%
  final bool isSavingsSafe; // >= 20%
  final String advice;

  const FiftyThirtyTwentyReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.needsAmount,
    required this.wantsAmount,
    required this.savingsAmount,
    required this.needsPercentage,
    required this.wantsPercentage,
    required this.savingsPercentage,
    required this.isNeedsSafe,
    required this.isWantsSafe,
    required this.isSavingsSafe,
    required this.advice,
  });
}

class EmergencyRunwayReport {
  final double totalLiquidCash;
  final double monthlyBurnRate;
  final double runwayMonths;
  final EmergencyRunwayTier tier;
  final String statusLabel; // e.g. "5.4 Months Safe"
  final String recommendation;

  const EmergencyRunwayReport({
    required this.totalLiquidCash,
    required this.monthlyBurnRate,
    required this.runwayMonths,
    required this.tier,
    required this.statusLabel,
    required this.recommendation,
  });
}

class SavingsRateReport {
  final double monthlyIncome;
  final double monthlyNonInvestmentExpense;
  final double monthlyInvestments;
  final double netSavings;
  final double savingsRatePercent;
  final SavingsRateTier tier;
  final String tierTitle;
  final String tierBadge;
  final String description;

  const SavingsRateReport({
    required this.monthlyIncome,
    required this.monthlyNonInvestmentExpense,
    required this.monthlyInvestments,
    required this.netSavings,
    required this.savingsRatePercent,
    required this.tier,
    required this.tierTitle,
    required this.tierBadge,
    required this.description,
  });
}

class AssetAllocationReport {
  final double equityAmount;
  final double debtAmount;
  final double goldAmount;
  final double cashAmount;
  final double totalNetWealth;

  final double equityPercent;
  final double debtPercent;
  final double goldPercent;
  final double cashPercent;

  final String diversificationSummary;

  const AssetAllocationReport({
    required this.equityAmount,
    required this.debtAmount,
    required this.goldAmount,
    required this.cashAmount,
    required this.totalNetWealth,
    required this.equityPercent,
    required this.debtPercent,
    required this.goldPercent,
    required this.cashPercent,
    required this.diversificationSummary,
  });
}

class FinancialHealthReport {
  final FiftyThirtyTwentyReport fiftyThirtyTwenty;
  final EmergencyRunwayReport emergencyRunway;
  final SavingsRateReport savingsRate;
  final AssetAllocationReport assetAllocation;
  final int year;
  final int month;

  const FinancialHealthReport({
    required this.fiftyThirtyTwenty,
    required this.emergencyRunway,
    required this.savingsRate,
    required this.assetAllocation,
    required this.year,
    required this.month,
  });
}

/// Service calculating all core financial health ratios and portfolio metrics.
class FinancialAnalyticsService {
  FinancialAnalyticsService._();

  /// Check whether an expense category represents Investments/Savings.
  static bool isInvestmentCategory(String category) {
    return category.trim().toUpperCase() == 'SIP & INVESTMENTS';
  }

  /// Classifies whether an expense is an essential "Need" according to standard 50-30-20 rules.
  static bool isNeedExpense(String category, String? subCategory) {
    final cat = category.trim().toUpperCase();
    final sub = (subCategory ?? '').trim().toUpperCase();

    if (cat == 'SIP & INVESTMENTS') return false;

    // Fixed & essential categories
    if (cat == 'HOME SEND' ||
        cat == 'BILLS & UTILITIES' ||
        cat == 'LOAN' ||
        cat == 'CREDIT CARD PAYMENT' ||
        cat == 'HEALTH & MEDICAL' ||
        cat == 'QUICK ECOMMERCE') {
      return true;
    }

    // Food classification: Groceries vs Dining Out
    if (cat == 'FOOD') {
      if (sub.contains('GROCER') ||
          sub.contains('RATION') ||
          sub.contains('MILK') ||
          sub.contains('VEG')) {
        return true;
      }
      return false; // Dining out, Zomato, Swiggy, cafe snacks are Wants
    }

    // Traveling classification: Commute & Fuel vs Leisure
    if (cat == 'TRAVELING') {
      if (sub.contains('FUEL') ||
          sub.contains('PETROL') ||
          sub.contains('DIESEL') ||
          sub.contains('METRO') ||
          sub.contains('BUS') ||
          sub.contains('FASTAG') ||
          sub.contains('SERVICE')) {
        return true;
      }
      return false; // Cabs, Flights, Trips are Wants
    }

    // Shopping, Entertainment, Other default to Wants
    return false;
  }

  /// Computes 50-30-20 budget breakdown for given income and expenses.
  static FiftyThirtyTwentyReport computeFiftyThirtyTwenty({
    required double totalIncome,
    required List<Map<String, dynamic>> categorizedExpenses,
  }) {
    double needs = 0.0;
    double wants = 0.0;
    double loggedSavings = 0.0;

    for (final exp in categorizedExpenses) {
      final cat = (exp['category'] as String?) ?? '';
      final sub = exp['sub_category'] as String?;
      final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0) continue;

      if (isInvestmentCategory(cat)) {
        loggedSavings += amt;
      } else if (isNeedExpense(cat, sub)) {
        needs += amt;
      } else {
        wants += amt;
      }
    }

    final totalExpense = needs + wants + loggedSavings;
    final double cashSurplus = (totalIncome > totalExpense) ? (totalIncome - totalExpense) : 0.0;
    final double totalSavings = loggedSavings + cashSurplus;

    final double base = totalIncome > 0 ? totalIncome : totalExpense;
    final double needsPct = base > 0 ? (needs / base) * 100 : 0.0;
    final double wantsPct = base > 0 ? (wants / base) * 100 : 0.0;
    final double savingsPct = base > 0 ? (totalSavings / base) * 100 : 0.0;

    final bool isNeedsSafe = needsPct <= 50.0;
    final bool isWantsSafe = wantsPct <= 30.0;
    final bool isSavingsSafe = savingsPct >= 20.0;

    String advice;
    if (base == 0) {
      advice = "Log your monthly income and expenses to visualize your 50-30-20 breakdown.";
    } else if (isNeedsSafe && isWantsSafe && isSavingsSafe) {
      advice = "🌟 Golden Ratio! Needs are under 50%, Wants under 30%, and savings exceed 20%.";
    } else if (!isNeedsSafe && !isWantsSafe) {
      advice = "⚠️ Both Needs (${needsPct.toStringAsFixed(1)}%) and Wants (${wantsPct.toStringAsFixed(1)}%) exceed targets. Trim discretionary spending first.";
    } else if (!isNeedsSafe) {
      advice = "⚠️ Essential Needs are high at ${needsPct.toStringAsFixed(1)}% (target ≤ 50%). Review fixed recurring bills or rent commitments.";
    } else if (!isWantsSafe) {
      advice = "⚠️ Lifestyle Wants are high at ${wantsPct.toStringAsFixed(1)}% (target ≤ 30%). Reducing discretionary purchases will boost your savings.";
    } else {
      advice = "💡 Savings are at ${savingsPct.toStringAsFixed(1)}% (target ≥ 20%). Automate a monthly SIP on payday to reach the 20% mark.";
    }

    return FiftyThirtyTwentyReport(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      needsAmount: needs,
      wantsAmount: wants,
      savingsAmount: totalSavings,
      needsPercentage: needsPct,
      wantsPercentage: wantsPct,
      savingsPercentage: savingsPct,
      isNeedsSafe: isNeedsSafe,
      isWantsSafe: isWantsSafe,
      isSavingsSafe: isSavingsSafe,
      advice: advice,
    );
  }

  /// Computes Emergency Fund Runway (e.g. "5.4 Months Safe").
  static EmergencyRunwayReport computeEmergencyRunway({
    required double totalLiquidCash,
    required double monthlyBurnRate,
  }) {
    final cash = totalLiquidCash > 0 ? totalLiquidCash : 0.0;
    final burn = monthlyBurnRate > 0 ? monthlyBurnRate : 0.0;

    final double runway;
    final EmergencyRunwayTier tier;
    final String statusLabel;
    final String recommendation;

    if (burn == 0.0) {
      runway = cash > 0 ? 999.0 : 0.0;
      tier = EmergencyRunwayTier.noExpense;
      statusLabel = "Zero Monthly Burn";
      recommendation = "Add your living expenses to calculate your survival runway.";
    } else {
      runway = cash / burn;
      if (runway >= 6.0) {
        tier = EmergencyRunwayTier.superSafe;
        statusLabel = "${runway.toStringAsFixed(1)} Months Safe";
        recommendation = "🟢 Super Safe! You have more than 6 months of living expenses safely liquid. Surplus cash can be invested into wealth assets.";
      } else if (runway >= 3.0) {
        tier = EmergencyRunwayTier.moderate;
        statusLabel = "${runway.toStringAsFixed(1)} Months Buffer";
        recommendation = "🟡 Moderate Cushion. You have ${runway.toStringAsFixed(1)} months of emergency buffer. Aim to scale to 6 months (${AppFormatters.currencyRounded(burn * 6)}).";
      } else {
        tier = EmergencyRunwayTier.low;
        statusLabel = "${runway.toStringAsFixed(1)} Months (Action Needed)";
        recommendation = "🔴 Low Cushion! Your liquid reserves cover less than 3 months. Priority: accumulate 3 to 6 months (${AppFormatters.currencyRounded(burn * 3)} - ${AppFormatters.currencyRounded(burn * 6)}) in a bank or liquid FD.";
      }
    }

    return EmergencyRunwayReport(
      totalLiquidCash: cash,
      monthlyBurnRate: burn,
      runwayMonths: runway,
      tier: tier,
      statusLabel: statusLabel,
      recommendation: recommendation,
    );
  }

  /// Computes monthly savings rate percentage and assigns tier.
  static SavingsRateReport computeSavingsRate({
    required double monthlyIncome,
    required double nonInvestmentExpense,
    required double monthlyInvestments,
  }) {
    final totalSpent = nonInvestmentExpense + monthlyInvestments;
    final netSurplus = (monthlyIncome > totalSpent) ? (monthlyIncome - totalSpent) : 0.0;
    final totalSaved = monthlyInvestments + netSurplus;

    final double rate;
    final SavingsRateTier tier;
    final String tierTitle;
    final String tierBadge;
    final String description;

    if (monthlyIncome <= 0) {
      rate = 0.0;
      tier = SavingsRateTier.noIncome;
      tierTitle = "No Income";
      tierBadge = "⚪ No Income";
      description = "Record monthly income to calculate your savings rate.";
    } else {
      rate = ((monthlyIncome - nonInvestmentExpense) / monthlyIncome) * 100;

      if (rate >= 50.0) {
        tier = SavingsRateTier.elite;
        tierTitle = "Elite / FIRE Saver";
        tierBadge = "🏆 Elite";
        description = "Saving 50%+ puts you in the top tier of wealth builders. Phenomenal!";
      } else if (rate >= 30.0) {
        tier = SavingsRateTier.superSaver;
        tierTitle = "Super Saver";
        tierBadge = "🌟 Super Saver";
        description = "Outstanding 30-49% savings rate. You are on an accelerated wealth journey.";
      } else if (rate >= 20.0) {
        tier = SavingsRateTier.healthy;
        tierTitle = "Healthy Saver";
        tierBadge = "🟢 Healthy";
        description = "Meets the golden 20%+ benchmark. Consistent discipline will create financial independence.";
      } else if (rate >= 5.0) {
        tier = SavingsRateTier.developing;
        tierTitle = "Developing Saver";
        tierBadge = "🟡 Developing";
        description = "Positive savings rate. Trimming discretionary lifestyle wants can boost you to 20%.";
      } else if (rate >= 0.0) {
        tier = SavingsRateTier.breakEven;
        tierTitle = "Break-Even";
        tierBadge = "🟠 Break-Even";
        description = "Living paycheck to paycheck. Try building an initial buffer to protect against unexpected costs.";
      } else {
        tier = SavingsRateTier.deficit;
        tierTitle = "Deficit / Overspent";
        tierBadge = "🔴 Deficit";
        description = "Expenses exceeded earnings by ${AppFormatters.currency(nonInvestmentExpense - monthlyIncome)}. Review high-spending categories.";
      }
    }

    return SavingsRateReport(
      monthlyIncome: monthlyIncome,
      monthlyNonInvestmentExpense: nonInvestmentExpense,
      monthlyInvestments: monthlyInvestments,
      netSavings: totalSaved,
      savingsRatePercent: rate,
      tier: tier,
      tierTitle: tierTitle,
      tierBadge: tierBadge,
      description: description,
    );
  }

  /// Computes Equity vs Debt vs Gold vs Cash allocation breakdown.
  static AssetAllocationReport computeAssetAllocation({
    required List<Map<String, dynamic>> investmentAllocations,
    required double totalLiquidCash,
  }) {
    double equity = 0.0;
    double debt = 0.0;
    double gold = 0.0;

    for (final item in investmentAllocations) {
      final sub = (item['sub_category'] as String?)?.toUpperCase() ?? '';
      final amt = (item['total'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0) continue;

      if (sub.contains('GOLD') ||
          sub.contains('SGB') ||
          sub.contains('SILVER') ||
          sub.contains('PRECIOUS')) {
        gold += amt;
      } else if (sub.contains('SIP') ||
          sub.contains('MUTUAL') ||
          sub.contains('STOCK') ||
          sub.contains('SHARE') ||
          sub.contains('EQUITY') ||
          sub.contains('INDEX') ||
          sub.contains('GROWW') ||
          sub.contains('ZERODHA')) {
        equity += amt;
      } else {
        // FD, RD, PPF, NPS, EPF, Bonds, Other Investment default to Debt
        debt += amt;
      }
    }

    final cash = totalLiquidCash > 0 ? totalLiquidCash : 0.0;
    final totalNetWorth = equity + debt + gold + cash;

    final eqPct = totalNetWorth > 0 ? (equity / totalNetWorth) * 100 : 0.0;
    final debtPct = totalNetWorth > 0 ? (debt / totalNetWorth) * 100 : 0.0;
    final goldPct = totalNetWorth > 0 ? (gold / totalNetWorth) * 100 : 0.0;
    final cashPct = totalNetWorth > 0 ? (cash / totalNetWorth) * 100 : 0.0;

    String tip;
    if (totalNetWorth == 0) {
      tip = "Add bank balances and investments to view your net wealth distribution.";
    } else if (cashPct > 50.0) {
      tip = "Cash Heavy (${cashPct.toStringAsFixed(0)}%): Deploy excess idle cash into Equity SIPs or Debt for higher real returns.";
    } else if (eqPct > 70.0) {
      tip = "Growth Oriented (${eqPct.toStringAsFixed(0)}% Equity): High long-term compounding, maintain 6-month debt/cash safety net.";
    } else if (goldPct == 0.0 && totalNetWorth > 100000) {
      tip = "Consider allocating 5-10% to Gold (SGB or Gold ETF) as an inflation hedge and market crisis ballast.";
    } else {
      tip = "Balanced Portfolio: Well distributed across growth (equity), safety (debt), hedge (gold), and liquidity (cash).";
    }

    return AssetAllocationReport(
      equityAmount: equity,
      debtAmount: debt,
      goldAmount: gold,
      cashAmount: cash,
      totalNetWealth: totalNetWorth,
      equityPercent: eqPct,
      debtPercent: debtPct,
      goldPercent: goldPct,
      cashPercent: cashPct,
      diversificationSummary: tip,
    );
  }

  /// Full financial health evaluation querying the database for the given month/year.
  static Future<FinancialHealthReport> computeHealthReport({
    required int year,
    required int month,
  }) async {
    final start = AppFormatters.monthStart(year, month);
    final end = AppFormatters.monthEnd(year, month);

    // 1. Income
    final income = await DatabaseHelper.instance.getPeriodIncome(
      dateFrom: start,
      dateTo: end,
    );

    // 2. Expenses categorized
    final expenses = await DatabaseHelper.instance.getPeriodExpensesCategorized(
      dateFrom: start,
      dateTo: end,
    );

    // 3. Liquid Cash
    final liquidCash = await DatabaseHelper.instance.getTotalLiquidCash();

    // 4. Trailing Monthly Burn Rates (non-investment)
    final trailingBurns = await DatabaseHelper.instance.getTrailingMonthlyBurnRates(trailingMonths: 6);
    double monthlyBurn = 0.0;
    if (trailingBurns.isNotEmpty) {
      final sum = trailingBurns.reduce((a, b) => a + b);
      monthlyBurn = sum / trailingBurns.length;
    } else {
      // Fallback: check current month's non-investment expenses
      double curMonthNonInv = 0.0;
      for (final e in expenses) {
        final cat = (e['category'] as String?) ?? '';
        if (!isInvestmentCategory(cat)) {
          curMonthNonInv += (e['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      monthlyBurn = curMonthNonInv;
    }

    // 5. Investment Allocations
    final allocations = await DatabaseHelper.instance.getInvestmentAllocation(
      includeStartingBalance: true,
    );

    final ftt = computeFiftyThirtyTwenty(
      totalIncome: income,
      categorizedExpenses: expenses,
    );

    final emergency = computeEmergencyRunway(
      totalLiquidCash: liquidCash,
      monthlyBurnRate: monthlyBurn,
    );

    double curMonthInv = 0.0;
    double curMonthNonInv = 0.0;
    for (final e in expenses) {
      final cat = (e['category'] as String?) ?? '';
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      if (isInvestmentCategory(cat)) {
        curMonthInv += amt;
      } else {
        curMonthNonInv += amt;
      }
    }

    final savings = computeSavingsRate(
      monthlyIncome: income,
      nonInvestmentExpense: curMonthNonInv,
      monthlyInvestments: curMonthInv,
    );

    final assetAlloc = computeAssetAllocation(
      investmentAllocations: allocations,
      totalLiquidCash: liquidCash,
    );

    return FinancialHealthReport(
      fiftyThirtyTwenty: ftt,
      emergencyRunway: emergency,
      savingsRate: savings,
      assetAllocation: assetAlloc,
      year: year,
      month: month,
    );
  }
}
