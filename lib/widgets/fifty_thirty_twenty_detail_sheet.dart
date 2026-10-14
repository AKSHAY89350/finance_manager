import 'package:flutter/material.dart';
import '../services/financial_analytics_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class FiftyThirtyTwentyDetailSheet extends StatefulWidget {
  final int year;
  final int month;
  final int initialTabIndex;

  const FiftyThirtyTwentyDetailSheet({
    super.key,
    required this.year,
    required this.month,
    this.initialTabIndex = 0,
  });

  @override
  State<FiftyThirtyTwentyDetailSheet> createState() => _FiftyThirtyTwentyDetailSheetState();
}

class _FiftyThirtyTwentyDetailSheetState extends State<FiftyThirtyTwentyDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<FiftyThirtyTwentyMonthlyDetails> _detailsFuture;

  // Simulator state (Idea 5)
  double _cutAmount = 2000.0;

  static const Color needsColor = Color(0xFF3B82F6);   // Blue
  static const Color wantsColor = Color(0xFFEC4899);   // Pink
  static const Color savingsColor = Color(0xFF10B981); // Emerald Green
  static const Color amberColor = Color(0xFFF59E0B);   // Amber

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _detailsFuture = FinancialAnalyticsService.getFiftyThirtyTwentyDetails(
      year: widget.year,
      month: widget.month,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = AppFormatters.monthYear(DateTime(widget.year, widget.month));

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag Handle & Header ───────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '50-30-20 Financial Deep Dive',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Tab Bar (5 Tabs) ────────────────────────────────────────────────
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.indigo,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
              Tab(icon: Icon(Icons.shopping_basket_rounded, size: 18), text: 'Needs (≤50%)'),
              Tab(icon: Icon(Icons.celebration_rounded, size: 18), text: 'Wants (≤30%)'),
              Tab(icon: Icon(Icons.savings_rounded, size: 18), text: 'Savings (≥20%)'),
              Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'What-If Simulator'),
            ],
          ),

          const Divider(height: 1, thickness: 1),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<FiftyThirtyTwentyMonthlyDetails>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load breakdown: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    ),
                  );
                }

                final details = snapshot.data!;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(details),
                    _buildNeedsTab(details),
                    _buildWantsTab(details),
                    _buildSavingsTab(details),
                    _buildSimulatorTab(details),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. OVERVIEW TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab(FiftyThirtyTwentyMonthlyDetails details) {
    final double targetIncome = details.totalIncome > 0 ? details.totalIncome : details.totalExpense;
    final double targetNeedsAmt = targetIncome * 0.50;
    final double targetWantsAmt = targetIncome * 0.30;
    final double targetSavingsAmt = targetIncome * 0.20;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Monthly Cash Flow Snapshot
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFlowStat(
                label: 'Monthly Income',
                amount: details.totalIncome,
                color: const Color(0xFF047857),
                icon: Icons.arrow_downward_rounded,
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade300),
              _buildFlowStat(
                label: 'Total Expenses',
                amount: details.totalExpense,
                color: const Color(0xFFB91C1C),
                icon: Icons.arrow_upward_rounded,
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade300),
              _buildFlowStat(
                label: 'Total Savings',
                amount: details.savingsTotal,
                color: Colors.indigo,
                icon: Icons.account_balance_wallet_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── IDEA 1: Burn Velocity & Daily Safe Spend ──────────────────────
        _buildBurnVelocityCard(details.burnVelocity),

        const SizedBox(height: 12),

        // ── Overspending Leaks Alert Banner (If Any Breaches) ─────────────
        if (details.leakReport.isNeedsOverspent ||
            details.leakReport.isWantsOverspent ||
            details.leakReport.isDeficit) ...[
          _buildLeakReportCard(details.leakReport),
          const SizedBox(height: 12),
        ],

        // ── IDEA 2: Lifestyle Ratio (Wants vs Needs) ─────────────────────
        _buildLifestyleRatioCard(details.lifestyleRatio),

        const SizedBox(height: 14),

        // ── 3 Bucket Cards ────────────────────────────────────────────────
        // 1. Needs Card
        _buildBucketCard(
          title: 'Essential Needs',
          targetPct: 50,
          targetAmount: targetNeedsAmt,
          actualAmount: details.needsTotal,
          actualPct: details.needsPercentage,
          color: needsColor,
          isSafe: details.isNeedsSafe,
          safeBadge: 'Within 50% Limit',
          unsafeBadge: 'Over Limit by ${(details.needsPercentage - 50).toStringAsFixed(1)}%',
          description: 'Groceries, Rent, Utilities, Fuel/Commute, EMIs & Medical bills.',
          onTapDetails: () => _tabController.animateTo(1),
          topCategories: details.needsCategorySums,
        ),

        const SizedBox(height: 12),

        // 2. Wants Card
        _buildBucketCard(
          title: 'Lifestyle Wants',
          targetPct: 30,
          targetAmount: targetWantsAmt,
          actualAmount: details.wantsTotal,
          actualPct: details.wantsPercentage,
          color: wantsColor,
          isSafe: details.isWantsSafe,
          safeBadge: 'Controlled (≤30%)',
          unsafeBadge: 'Elevated by ${(details.wantsPercentage - 30).toStringAsFixed(1)}%',
          description: 'Dining out, Shopping, Movies, Leisure Trips & Discretionary spends.',
          onTapDetails: () => _tabController.animateTo(2),
          topCategories: details.wantsCategorySums,
        ),

        const SizedBox(height: 12),

        // 3. Savings Card
        _buildBucketCard(
          title: 'Savings & Investments',
          targetPct: 20,
          targetAmount: targetSavingsAmt,
          actualAmount: details.savingsTotal,
          actualPct: details.savingsPercentage,
          color: savingsColor,
          isSafe: details.isSavingsSafe,
          safeBadge: 'Target Met (≥20%)',
          unsafeBadge: 'Low Savings (Need 20%)',
          description: 'SIPs, Stocks, Gold, PPF + Retained unspent bank cash surplus.',
          onTapDetails: () => _tabController.animateTo(3),
          topCategories: details.savingsCategorySums,
          extraNote: 'Investments: ${AppFormatters.currency(details.directInvestmentsTotal)} • Liquid Bank Surplus: ${AppFormatters.currency(details.unspentCashSurplus)}',
        ),

        // ── IDEA 3: Idle Cash Deployment Card ─────────────────────────────
        if (details.idleCashAdvice.hasExcessIdleCash) ...[
          const SizedBox(height: 14),
          _buildIdleCashCard(details.idleCashAdvice),
        ],

        const SizedBox(height: 14),

        // Smart Advice Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_rounded, color: Colors.indigo, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  details.advice,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Idea 1 Card: Burn Velocity ─────────────────────────────────────────────
  Widget _buildBurnVelocityCard(BurnVelocityReport burn) {
    final Color badgeColor = burn.isBurningTooFast
        ? const Color(0xFFEF4444)
        : (burn.daysRemaining > 0 ? const Color(0xFF10B981) : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: badgeColor, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Budget Burn Velocity',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  burn.paceHeadline,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (burn.daysRemaining > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Safe Spending Limit',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppFormatters.currency(burn.dailySafeSpendRemaining)} / day',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: badgeColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Days Remaining',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${burn.daysRemaining} days left',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(
            burn.paceMessage,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ── Overspending Leaks Card (Culprits Detection) ───────────────────────────
  Widget _buildLeakReportCard(BudgetOverspendLeak leak) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              SizedBox(width: 6),
              Text(
                'Budget Leakage & Overspend Alert',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            leak.leakSummary,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.3),
          ),
          if (leak.culpritCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Top Culprit Categories:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            ...leak.culpritCategories.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '• ${c['category']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      AppFormatters.currency(c['amount'] as double),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Idea 2 Card: Lifestyle Ratio (Wants vs Needs) ─────────────────────────
  Widget _buildLifestyleRatioCard(LifestyleRatioReport life) {
    final Color badgeColor = life.isLifestyleInflated ? amberColor : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_rounded, color: badgeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      life.headline,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        life.statusBadge,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  life.advice,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Idea 3 Card: Idle Cash Deployment Advisor ─────────────────────────────
  Widget _buildIdleCashCard(IdleCashAdvice cash) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.savings_outlined, color: Colors.teal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Idle Cash Deployment Opportunity',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    Text(
                      AppFormatters.currencyCompact(cash.recommendedDeployAmount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cash.advice,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStat({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          AppFormatters.currencyCompact(amount),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildBucketCard({
    required String title,
    required int targetPct,
    required double targetAmount,
    required double actualAmount,
    required double actualPct,
    required Color color,
    required bool isSafe,
    required String safeBadge,
    required String unsafeBadge,
    required String description,
    required VoidCallback onTapDetails,
    required Map<String, double> topCategories,
    String? extraNote,
  }) {
    final double progress = (actualPct / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSafe ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSafe ? safeBadge : unsafeBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSafe ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Amount & Target Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    AppFormatters.currency(actualAmount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${actualPct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              Text(
                'Goal: $targetPct% (${AppFormatters.currencyCompact(targetAmount)})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSafe ? color : const Color(0xFFEF4444),
              ),
            ),
          ),

          if (extraNote != null) ...[
            const SizedBox(height: 8),
            Text(
              extraNote,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          // Top categories chips snippet (if any)
          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: topCategories.entries.take(3).map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '${e.key}: ${AppFormatters.currencyCompact(e.value)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 8),

          // View Details Action Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTapDetails,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              icon: Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              label: Text(
                'View Transactions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. NEEDS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNeedsTab(FiftyThirtyTwentyMonthlyDetails details) {
    return _buildBucketTransactionsView(
      bucketName: 'Essential Needs',
      targetLabel: 'Target ≤ 50%',
      totalAmount: details.needsTotal,
      percentage: details.needsPercentage,
      color: needsColor,
      categorySums: details.needsCategorySums,
      categoryCounts: details.needsCategoryCounts,
      transactions: details.needsTransactions,
      emptyMessage: 'No essential Needs expenses recorded in this month.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. WANTS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWantsTab(FiftyThirtyTwentyMonthlyDetails details) {
    return _buildBucketTransactionsView(
      bucketName: 'Lifestyle Wants',
      targetLabel: 'Target ≤ 30%',
      totalAmount: details.wantsTotal,
      percentage: details.wantsPercentage,
      color: wantsColor,
      categorySums: details.wantsCategorySums,
      categoryCounts: details.wantsCategoryCounts,
      transactions: details.wantsTransactions,
      emptyMessage: 'No lifestyle Wants expenses recorded in this month.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SAVINGS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSavingsTab(FiftyThirtyTwentyMonthlyDetails details) {
    final gap = details.savingsGap;
    final inst = details.savingsInstruments;
    final pyf = details.payYourselfFirst;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Savings Target & Shortfall / Surplus Banner ───────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: savingsColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: savingsColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Monthly Savings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: savingsColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gap.hasMetMinimum ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${details.savingsPercentage.toStringAsFixed(1)}% (Goal ≥ 20%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gap.hasMetMinimum ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppFormatters.currency(details.savingsTotal),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                gap.statusHeadline,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: gap.hasMetMinimum ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                gap.gapMessage,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Savings Benchmark Ladder ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Milestones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMilestonePill('Minimum (20%)', gap.minimumTarget, details.savingsTotal >= gap.minimumTarget),
                  _buildMilestonePill('Healthy (30%)', gap.healthyTarget, details.savingsTotal >= gap.healthyTarget),
                  _buildMilestonePill('FIRE (50%)', gap.fireTarget, details.savingsTotal >= gap.fireTarget),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Savings Instruments Breakdown ─────────────────────────────────
        const Text(
          'Savings by Instrument',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(child: _buildInstrumentTile('📈 Equity SIP', inst.equitySip, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildInstrumentTile('📊 Stocks', inst.stocks, Colors.indigo)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildInstrumentTile('🟡 Gold / SGB', inst.gold, Colors.amber.shade800)),
            const SizedBox(width: 8),
            Expanded(child: _buildInstrumentTile('🛡️ Debt / PPF', inst.debtPpf, Colors.purple)),
          ],
        ),
        const SizedBox(height: 8),
        _buildInstrumentTile('💰 Liquid Bank Surplus', inst.liquidBankSurplus, Colors.teal),

        const SizedBox(height: 14),

        // ── IDEA 4: Pay Yourself First Card ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.alarm_on_rounded, color: Colors.indigo, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pyf.tip,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'Investment Transactions',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),

        if (details.savingsTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 28),
                const SizedBox(height: 8),
                Text(
                  'No direct investment expenses logged this month.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your savings for this month are currently preserved as unspent cash balance in your bank accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ...details.savingsTransactions.map((tx) => _buildTransactionCard(tx, savingsColor)),
      ],
    );
  }

  Widget _buildMilestonePill(String title, double target, bool achieved) {
    final color = achieved ? const Color(0xFF047857) : Colors.grey.shade600;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(achieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 12, color: color),
            const SizedBox(width: 4),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(AppFormatters.currencyCompact(target),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildInstrumentTile(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(
            AppFormatters.currency(amount),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. WHAT-IF SIMULATOR TAB (IDEA 5)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSimulatorTab(FiftyThirtyTwentyMonthlyDetails details) {
    final double base = details.totalIncome > 0 ? details.totalIncome : details.totalExpense;
    if (base <= 0) {
      return const Center(child: Text('Add income or expenses to simulate budget scenarios.'));
    }

    final double maxCut = (details.wantsTotal > 1000) ? details.wantsTotal : 10000.0;
    final double cut = _cutAmount.clamp(0.0, maxCut);

    final double simWants = (details.wantsTotal - cut).clamp(0.0, double.infinity);
    final double simSavings = details.savingsTotal + cut;

    final double simNeedsPct = (details.needsTotal / base) * 100;
    final double simWantsPct = (simWants / base) * 100;
    final double simSavingsPct = (simSavings / base) * 100;

    // Compounding wealth projections (12% CAGR equity return)
    // Formula for SIP Future Value: P * ((1+i)^n - 1) / i * (1+i), with i = 0.01 per month
    final double oneYearExtra = cut * 12;
    final double fiveYearWealth = cut * 82.48;     // 5 years at 12%
    final double tenYearWealth = cut * 232.33;    // 10 years at 12%

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: Colors.indigo, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'What-If Spending & Wealth Simulator',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'See how trimming non-essential lifestyle spending can dramatically increase your savings rate and compound your wealth.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Slider control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trim Monthly Lifestyle Wants By:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              AppFormatters.currency(_cutAmount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.indigo),
            ),
          ],
        ),
        Slider(
          value: _cutAmount.clamp(500.0, maxCut > 500 ? maxCut : 10000.0),
          min: 500.0,
          max: maxCut > 1000 ? maxCut : 10000.0,
          divisions: ((maxCut > 1000 ? maxCut : 10000.0) / 500).round(),
          activeColor: Colors.indigo,
          inactiveColor: Colors.indigo.shade100,
          onChanged: (val) {
            setState(() {
              _cutAmount = val;
            });
          },
        ),

        const SizedBox(height: 12),

        // Simulated 50-30-20 Mini Meter
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simulated Monthly Ratio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (simNeedsPct * 10).round().clamp(1, 1000),
                        child: Container(color: needsColor),
                      ),
                      Expanded(
                        flex: (simWantsPct * 10).round().clamp(1, 1000),
                        child: Container(color: wantsColor),
                      ),
                      Expanded(
                        flex: (simSavingsPct * 10).round().clamp(1, 1000),
                        child: Container(color: savingsColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Needs: ${simNeedsPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: needsColor, fontWeight: FontWeight.bold)),
                  Text('Wants: ${simWantsPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: wantsColor, fontWeight: FontWeight.bold)),
                  Text('Savings: ${simSavingsPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: savingsColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Long-term compounding wealth cards
        const Text(
          'Future Wealth Compounded (at 12% CAGR in Mutual Funds)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildWealthPill('1 Year Extra', AppFormatters.currencyCompact(oneYearExtra), 'Direct Cash Saved', Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWealthPill('5 Years Wealth', AppFormatters.currencyCompact(fiveYearWealth), 'With Compounding', Colors.teal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWealthPill('10 Years Wealth', AppFormatters.currencyCompact(tenYearWealth), 'Wealth Multiplier', Colors.green.shade700),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'By redirecting ${AppFormatters.currency(cut)} from dining/shopping into a monthly SIP, you create ${AppFormatters.currency(tenYearWealth)} in 10 years without affecting your standard of living!',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade900, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWealthPill(String title, String amount, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERIC BUCKET TRANSACTIONS LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBucketTransactionsView({
    required String bucketName,
    required String targetLabel,
    required double totalAmount,
    required double percentage,
    required Color color,
    required Map<String, double> categorySums,
    required Map<String, int> categoryCounts,
    required List<Map<String, dynamic>> transactions,
    required String emptyMessage,
  }) {
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bucketName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.currency(totalAmount),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}% of Income',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Category Breakdown Chips
        if (sortedCategories.isNotEmpty) ...[
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedCategories.map((entry) {
              final count = categoryCounts[entry.key] ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppFormatters.currencyCompact(entry.value),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],

        // Transactions Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transactions (${transactions.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          )
        else
          ...transactions.map((tx) => _buildTransactionCard(tx, color)),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, Color bucketColor) {
    final cat = (tx['category'] as String?) ?? 'Other';
    final sub = (tx['sub_category'] as String?) ?? '';
    final bank = (tx['bank'] as String?) ?? '';
    final dateStr = (tx['date'] as String?) ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final icon = AppConstants.categoryIcons[cat] ?? '🔹';

    String formattedDate = dateStr;
    try {
      final dt = AppFormatters.parseDbDate(dateStr);
      formattedDate = AppFormatters.shortDate(dt);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: bucketColor.withValues(alpha: 0.12),
          child: Text(icon, style: const TextStyle(fontSize: 18)),
        ),
        title: Text(
          sub.isNotEmpty ? '$cat • $sub' : cat,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$formattedDate • $bank',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Text(
          AppFormatters.currency(amount),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
