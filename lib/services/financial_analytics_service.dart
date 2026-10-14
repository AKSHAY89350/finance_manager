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

class SavingsInstrumentBreakdown {
  final double equitySip;
  final double stocks;
  final double gold;
  final double debtPpf;
  final double liquidBankSurplus;
  final double totalSavings;

  const SavingsInstrumentBreakdown({
    required this.equitySip,
    required this.stocks,
    required this.gold,
    required this.debtPpf,
    required this.liquidBankSurplus,
    required this.totalSavings,
  });
}

class SavingsTargetGap {
  final double minimumTarget; // 20%
  final double healthyTarget; // 30%
  final double fireTarget;    // 50%
  final double actualSaved;
  final double minimumShortfall; // > 0 if deficit, <= 0 if surplus
  final bool hasMetMinimum;
  final String statusHeadline;
  final String gapMessage;

  const SavingsTargetGap({
    required this.minimumTarget,
    required this.healthyTarget,
    required this.fireTarget,
    required this.actualSaved,
    required this.minimumShortfall,
    required this.hasMetMinimum,
    required this.statusHeadline,
    required this.gapMessage,
  });
}

class BudgetOverspendLeak {
  final bool isNeedsOverspent;
  final bool isWantsOverspent;
  final bool isDeficit;
  final double needsExcess;
  final double wantsExcess;
  final double deficitAmount;
  final List<Map<String, dynamic>> culpritCategories;
  final String leakSummary;

  const BudgetOverspendLeak({
    required this.isNeedsOverspent,
    required this.isWantsOverspent,
    required this.isDeficit,
    required this.needsExcess,
    required this.wantsExcess,
    required this.deficitAmount,
    required this.culpritCategories,
    required this.leakSummary,
  });
}

class BurnVelocityReport {
  final int daysPassed;
  final int daysRemaining;
  final int totalDaysInMonth;
  final double dailySafeSpendRemaining;
  final double currentDailyBurn;
  final bool isBurningTooFast;
  final double budgetRemaining;
  final String paceHeadline;
  final String paceMessage;

  const BurnVelocityReport({
    required this.daysPassed,
    required this.daysRemaining,
    required this.totalDaysInMonth,
    required this.dailySafeSpendRemaining,
    required this.currentDailyBurn,
    required this.isBurningTooFast,
    required this.budgetRemaining,
    required this.paceHeadline,
    required this.paceMessage,
  });
}

class LifestyleRatioReport {
  final double wantsToNeedsRatio;
  final bool isLifestyleInflated;
  final String statusBadge;
  final String headline;
  final String advice;

  const LifestyleRatioReport({
    required this.wantsToNeedsRatio,
    required this.isLifestyleInflated,
    required this.statusBadge,
    required this.headline,
    required this.advice,
  });
}

class IdleCashAdvice {
  final double idleCashAmount;
  final double recommendedDeployAmount;
  final bool hasExcessIdleCash;
  final String advice;

  const IdleCashAdvice({
    required this.idleCashAmount,
    required this.recommendedDeployAmount,
    required this.hasExcessIdleCash,
    required this.advice,
  });
}

class PayYourselfFirstReport {
  final bool hasEarlyMonthInvestments;
  final double earlyMonthInvested;
  final String tip;

  const PayYourselfFirstReport({
    required this.hasEarlyMonthInvestments,
    required this.earlyMonthInvested,
    required this.tip,
  });
}

class FiftyThirtyTwentyMonthlyDetails {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final double needsTotal;
  final double wantsTotal;
  final double savingsTotal;
  final double directInvestmentsTotal;
  final double unspentCashSurplus;
  final double needsPercentage;
  final double wantsPercentage;
  final double savingsPercentage;
  final bool isNeedsSafe;
  final bool isWantsSafe;
  final bool isSavingsSafe;
  final String advice;
  final List<Map<String, dynamic>> needsTransactions;
  final List<Map<String, dynamic>> wantsTransactions;
  final List<Map<String, dynamic>> savingsTransactions;
  final Map<String, double> needsCategorySums;
  final Map<String, int> needsCategoryCounts;
  final Map<String, double> wantsCategorySums;
  final Map<String, int> wantsCategoryCounts;
  final Map<String, double> savingsCategorySums;
  final Map<String, int> savingsCategoryCounts;
  final SavingsInstrumentBreakdown savingsInstruments;
  final SavingsTargetGap savingsGap;
  final BudgetOverspendLeak leakReport;
  final BurnVelocityReport burnVelocity;
  final LifestyleRatioReport lifestyleRatio;
  final IdleCashAdvice idleCashAdvice;
  final PayYourselfFirstReport payYourselfFirst;

  const FiftyThirtyTwentyMonthlyDetails({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.needsTotal,
    required this.wantsTotal,
    required this.savingsTotal,
    required this.directInvestmentsTotal,
    required this.unspentCashSurplus,
    required this.needsPercentage,
    required this.wantsPercentage,
    required this.savingsPercentage,
    required this.isNeedsSafe,
    required this.isWantsSafe,
    required this.isSavingsSafe,
    required this.advice,
    required this.needsTransactions,
    required this.wantsTransactions,
    required this.savingsTransactions,
    required this.needsCategorySums,
    required this.needsCategoryCounts,
    required this.wantsCategorySums,
    required this.wantsCategoryCounts,
    required this.savingsCategorySums,
    required this.savingsCategoryCounts,
    required this.savingsInstruments,
    required this.savingsGap,
    required this.leakReport,
    required this.burnVelocity,
    required this.lifestyleRatio,
    required this.idleCashAdvice,
    required this.payYourselfFirst,
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

  /// Deep-dive evaluation of 50-30-20 rule for a specific month and year,
  /// including itemized transactions and category totals for Needs, Wants, and Savings.
  static Future<FiftyThirtyTwentyMonthlyDetails> getFiftyThirtyTwentyDetails({
    required int year,
    required int month,
  }) async {
    final start = AppFormatters.monthStart(year, month);
    final end = AppFormatters.monthEnd(year, month);

    final expenses = await DatabaseHelper.instance.getExpensesFiltered(
      dateFrom: start,
      dateTo: end,
    );

    final totalIncome = await DatabaseHelper.instance.getPeriodIncome(
      dateFrom: start,
      dateTo: end,
    );

    final List<Map<String, dynamic>> needsTransactions = [];
    final List<Map<String, dynamic>> wantsTransactions = [];
    final List<Map<String, dynamic>> savingsTransactions = [];

    double needsTotal = 0.0;
    double wantsTotal = 0.0;
    double loggedSavingsTotal = 0.0;

    final Map<String, double> needsCategorySums = {};
    final Map<String, int> needsCategoryCounts = {};
    final Map<String, double> wantsCategorySums = {};
    final Map<String, int> wantsCategoryCounts = {};
    final Map<String, double> savingsCategorySums = {};
    final Map<String, int> savingsCategoryCounts = {};

    for (final exp in expenses) {
      final cat = (exp['category'] as String?) ?? '';
      final sub = exp['sub_category'] as String?;
      final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0) continue;

      final label = (sub != null && sub.trim().isNotEmpty) ? '$cat • $sub' : cat;

      if (isInvestmentCategory(cat)) {
        loggedSavingsTotal += amt;
        savingsTransactions.add(exp);
        savingsCategorySums[label] = (savingsCategorySums[label] ?? 0.0) + amt;
        savingsCategoryCounts[label] = (savingsCategoryCounts[label] ?? 0) + 1;
      } else if (isNeedExpense(cat, sub)) {
        needsTotal += amt;
        needsTransactions.add(exp);
        needsCategorySums[label] = (needsCategorySums[label] ?? 0.0) + amt;
        needsCategoryCounts[label] = (needsCategoryCounts[label] ?? 0) + 1;
      } else {
        wantsTotal += amt;
        wantsTransactions.add(exp);
        wantsCategorySums[label] = (wantsCategorySums[label] ?? 0.0) + amt;
        wantsCategoryCounts[label] = (wantsCategoryCounts[label] ?? 0) + 1;
      }
    }

    final totalExpense = needsTotal + wantsTotal + loggedSavingsTotal;
    final double unspentCashSurplus = (totalIncome > totalExpense) ? (totalIncome - totalExpense) : 0.0;
    final double totalSavings = loggedSavingsTotal + unspentCashSurplus;

    final double base = totalIncome > 0 ? totalIncome : totalExpense;
    final double needsPct = base > 0 ? (needsTotal / base) * 100 : 0.0;
    final double wantsPct = base > 0 ? (wantsTotal / base) * 100 : 0.0;
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

    // ── 1. Savings Instrument Breakdown ─────────────────────────
    double equitySip = 0.0;
    double stocks = 0.0;
    double gold = 0.0;
    double debtPpf = 0.0;

    for (final exp in savingsTransactions) {
      final sub = (exp['sub_category'] as String?)?.toUpperCase() ?? '';
      final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      if (sub.contains('GOLD') || sub.contains('SGB') || sub.contains('SILVER')) {
        gold += amt;
      } else if (sub.contains('STOCK') || sub.contains('SHARE') || sub.contains('EQUITY') || sub.contains('ZERODHA')) {
        stocks += amt;
      } else if (sub.contains('SIP') || sub.contains('MUTUAL') || sub.contains('INDEX') || sub.contains('GROWW')) {
        equitySip += amt;
      } else {
        debtPpf += amt;
      }
    }

    final savingsInstruments = SavingsInstrumentBreakdown(
      equitySip: equitySip,
      stocks: stocks,
      gold: gold,
      debtPpf: debtPpf,
      liquidBankSurplus: unspentCashSurplus,
      totalSavings: totalSavings,
    );

    // ── 2. Savings Gap Analysis ──────────────────────────────────
    final double minTarget = base * 0.20;
    final double healthyTarget = base * 0.30;
    final double fireTarget = base * 0.50;
    final double shortfall = minTarget - totalSavings;
    final bool hasMetMinimum = shortfall <= 0;

    final String gapHeadline = hasMetMinimum
        ? '🎉 Target Met (+${AppFormatters.currency(-shortfall)} above 20% goal)'
        : '⚠️ Shortfall of ${AppFormatters.currency(shortfall)} to reach 20% safe zone';

    final String gapMsg = hasMetMinimum
        ? 'Great discipline! You have met and exceeded your 20% minimum monthly savings goal.'
        : 'Aim to save ${AppFormatters.currency(shortfall)} more this month by curbing discretionary wants to reach safety.';

    final savingsGap = SavingsTargetGap(
      minimumTarget: minTarget,
      healthyTarget: healthyTarget,
      fireTarget: fireTarget,
      actualSaved: totalSavings,
      minimumShortfall: shortfall > 0 ? shortfall : 0.0,
      hasMetMinimum: hasMetMinimum,
      statusHeadline: gapHeadline,
      gapMessage: gapMsg,
    );

    // ── 3. Overspending & Budget Leak Detection ───────────────────
    final double targetNeeds = base * 0.50;
    final double targetWants = base * 0.30;
    final double needsExcess = (needsTotal - targetNeeds).clamp(0.0, double.infinity);
    final double wantsExcess = (wantsTotal - targetWants).clamp(0.0, double.infinity);
    final double deficitAmount = (totalIncome > 0 && totalExpense > totalIncome) ? (totalExpense - totalIncome) : 0.0;

    final List<Map<String, dynamic>> culprits = [];
    if (wantsExcess > 0) {
      final sortedWants = wantsCategorySums.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sortedWants.take(3)) {
        culprits.add({
          'category': e.key,
          'amount': e.value,
          'reason': 'Lifestyle wants exceeded limit by ${AppFormatters.currency(wantsExcess)}',
          'type': 'WANTS',
        });
      }
    }
    if (needsExcess > 0) {
      final sortedNeeds = needsCategorySums.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sortedNeeds.take(2)) {
        culprits.add({
          'category': e.key,
          'amount': e.value,
          'reason': 'Heavy essential commitments',
          'type': 'NEEDS',
        });
      }
    }

    String leakSummary;
    if (deficitAmount > 0) {
      leakSummary = 'Deficit Month: Total expenses exceeded earnings by ${AppFormatters.currency(deficitAmount)}.';
    } else if (wantsExcess > 0 && needsExcess > 0) {
      leakSummary = 'Both Needs and Wants breached targets. Discretionary lifestyle spending is the fastest area to trim.';
    } else if (wantsExcess > 0) {
      leakSummary = 'Lifestyle Wants exceeded 30% limit by ${AppFormatters.currency(wantsExcess)}. Review dining and leisure purchases.';
    } else if (needsExcess > 0) {
      leakSummary = 'Essential Needs exceeded 50% limit by ${AppFormatters.currency(needsExcess)}. Check recurring utilities or loan bills.';
    } else {
      leakSummary = 'No budget leaks detected! Spending in both Needs and Wants is safely controlled.';
    }

    final leakReport = BudgetOverspendLeak(
      isNeedsOverspent: needsExcess > 0,
      isWantsOverspent: wantsExcess > 0,
      isDeficit: deficitAmount > 0,
      needsExcess: needsExcess,
      wantsExcess: wantsExcess,
      deficitAmount: deficitAmount,
      culpritCategories: culprits,
      leakSummary: leakSummary,
    );

    // ── 4. Burn Velocity & Daily Safe Spend (Idea 1) ─────────────
    final now = DateTime.now();
    final bool isCurrentMonth = (year == now.year && month == now.month);
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int daysPassed = isCurrentMonth ? now.day : daysInMonth;
    final int daysRemaining = isCurrentMonth ? ((daysInMonth - daysPassed) + 1) : 0;

    final double allowedExpenseTarget = targetNeeds + targetWants;
    final double budgetRemaining = allowedExpenseTarget - (needsTotal + wantsTotal);
    final double dailyBurnSoFar = daysPassed > 0 ? (totalExpense / daysPassed) : 0.0;
    final double dailySafeSpendRemaining = (daysRemaining > 0 && budgetRemaining > 0)
        ? (budgetRemaining / daysRemaining)
        : 0.0;

    final double timeElapsedRatio = daysPassed / daysInMonth;
    final double expenseElapsedRatio = allowedExpenseTarget > 0 ? ((needsTotal + wantsTotal) / allowedExpenseTarget) : 0.0;
    final bool isBurningTooFast = isCurrentMonth && (expenseElapsedRatio - timeElapsedRatio) > 0.15;

    String paceHeadline;
    String paceMessage;
    if (!isCurrentMonth) {
      paceHeadline = 'Month Concluded';
      paceMessage = 'Average daily expense burn was ${AppFormatters.currency(dailyBurnSoFar)}/day.';
    } else if (budgetRemaining <= 0) {
      paceHeadline = 'Budget Depleted';
      paceMessage = 'Monthly expense budget is exhausted. Minimize further non-essential spending for the remaining $daysRemaining days.';
    } else if (isBurningTooFast) {
      paceHeadline = 'Burn Rate Alert';
      paceMessage = 'You have spent ${(expenseElapsedRatio * 100).toStringAsFixed(0)}% of your budget in only ${(timeElapsedRatio * 100).toStringAsFixed(0)}% of the month. Limit to ${AppFormatters.currency(dailySafeSpendRemaining)}/day.';
    } else {
      paceHeadline = 'Paced Well';
      paceMessage = 'Safe to spend up to ${AppFormatters.currency(dailySafeSpendRemaining)}/day for the remaining $daysRemaining days.';
    }

    final burnVelocity = BurnVelocityReport(
      daysPassed: daysPassed,
      daysRemaining: daysRemaining,
      totalDaysInMonth: daysInMonth,
      dailySafeSpendRemaining: dailySafeSpendRemaining,
      currentDailyBurn: dailyBurnSoFar,
      isBurningTooFast: isBurningTooFast,
      budgetRemaining: budgetRemaining > 0 ? budgetRemaining : 0.0,
      paceHeadline: paceHeadline,
      paceMessage: paceMessage,
    );

    // ── 5. Lifestyle Inflation / Wants vs Needs Ratio (Idea 2) ──
    final double wantsToNeedsRatio = needsTotal > 0 ? (wantsTotal / needsTotal) : (wantsTotal > 0 ? 1.5 : 0.0);
    final bool isLifestyleInflated = wantsToNeedsRatio > 0.8;
    String lifeBadge;
    String lifeHeadline;
    String lifeAdvice;

    if (wantsToNeedsRatio > 1.0) {
      lifeBadge = '🚨 Inverted (Wants > Needs)';
      lifeHeadline = 'Lifestyle Exceeds Necessities';
      lifeAdvice = 'You spent more on lifestyle desires (${AppFormatters.currency(wantsTotal)}) than essential survival needs (${AppFormatters.currency(needsTotal)}). Scale back discretionary buys.';
    } else if (wantsToNeedsRatio > 0.6) {
      lifeBadge = '⚠️ Elevated Lifestyle';
      lifeHeadline = 'Moderate Lifestyle Load';
      lifeAdvice = 'Wants are at ${(wantsToNeedsRatio * 100).toStringAsFixed(0)}% of Needs. Keep Wants well below 60% of Needs to build long-term safety.';
    } else {
      lifeBadge = '🟢 Controlled Discipline';
      lifeHeadline = 'Healthy Lifestyle Ratio';
      lifeAdvice = 'Excellent discipline! Essential needs take priority over lifestyle desires.';
    }

    final lifestyleRatio = LifestyleRatioReport(
      wantsToNeedsRatio: wantsToNeedsRatio,
      isLifestyleInflated: isLifestyleInflated,
      statusBadge: lifeBadge,
      headline: lifeHeadline,
      advice: lifeAdvice,
    );

    // ── 6. Idle Cash Deployment Advisor (Idea 3) ─────────────────
    final bool hasExcessCash = unspentCashSurplus > 20000;
    final double deployAmount = hasExcessCash ? (unspentCashSurplus * 0.60) : 0.0;
    final String cashAdvice = hasExcessCash
        ? '${AppFormatters.currency(unspentCashSurplus)} unspent surplus resting in bank. Deploying ${AppFormatters.currency(deployAmount)} into Liquid Funds or Recurring SIPs beats low savings interest.'
        : 'Bank liquidity is balanced for monthly living expenses.';

    final idleCashAdvice = IdleCashAdvice(
      idleCashAmount: unspentCashSurplus,
      recommendedDeployAmount: deployAmount,
      hasExcessIdleCash: hasExcessCash,
      advice: cashAdvice,
    );

    // ── 7. Pay Yourself First (Idea 4) ───────────────────────────
    int earlyMonthCount = 0;
    double earlyMonthSum = 0.0;
    for (final tx in savingsTransactions) {
      final dateStr = (tx['date'] as String?) ?? '';
      try {
        final dt = AppFormatters.parseDbDate(dateStr);
        if (dt.day <= 5) {
          earlyMonthCount++;
          earlyMonthSum += (tx['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {}
    }

    final bool hasEarlyInvestments = earlyMonthCount > 0;
    final String pyfTip = hasEarlyInvestments
        ? '🌟 Payday Wealth Champion! You invested ${AppFormatters.currency(earlyMonthSum)} right on payday (Day 1–5), locking in savings before lifestyle spends.'
        : '💡 Payday Rule: Automate SIPs on Day 1–3 right after salary so savings happen first, rather than relying on leftover month-end cash.';

    final payYourselfFirst = PayYourselfFirstReport(
      hasEarlyMonthInvestments: hasEarlyInvestments,
      earlyMonthInvested: earlyMonthSum,
      tip: pyfTip,
    );

    return FiftyThirtyTwentyMonthlyDetails(
      year: year,
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      needsTotal: needsTotal,
      wantsTotal: wantsTotal,
      savingsTotal: totalSavings,
      directInvestmentsTotal: loggedSavingsTotal,
      unspentCashSurplus: unspentCashSurplus,
      needsPercentage: needsPct,
      wantsPercentage: wantsPct,
      savingsPercentage: savingsPct,
      isNeedsSafe: isNeedsSafe,
      isWantsSafe: isWantsSafe,
      isSavingsSafe: isSavingsSafe,
      advice: advice,
      needsTransactions: needsTransactions,
      wantsTransactions: wantsTransactions,
      savingsTransactions: savingsTransactions,
      needsCategorySums: needsCategorySums,
      needsCategoryCounts: needsCategoryCounts,
      wantsCategorySums: wantsCategorySums,
      wantsCategoryCounts: wantsCategoryCounts,
      savingsCategorySums: savingsCategorySums,
      savingsCategoryCounts: savingsCategoryCounts,
      savingsInstruments: savingsInstruments,
      savingsGap: savingsGap,
      leakReport: leakReport,
      burnVelocity: burnVelocity,
      lifestyleRatio: lifestyleRatio,
      idleCashAdvice: idleCashAdvice,
      payYourselfFirst: payYourselfFirst,
    );
  }
}
