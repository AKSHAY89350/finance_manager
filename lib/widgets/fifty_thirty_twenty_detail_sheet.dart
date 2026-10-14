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

  static const Color needsColor = Color(0xFF3B82F6);   // Blue
  static const Color wantsColor = Color(0xFFEC4899);   // Pink
  static const Color savingsColor = Color(0xFF10B981); // Emerald Green

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
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
      height: MediaQuery.of(context).size.height * 0.90,
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
                          '50-30-20 Monthly Breakdown',
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

          // ── Tab Bar ────────────────────────────────────────────────────────
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

        const SizedBox(height: 16),

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

        const SizedBox(height: 14),

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

        const SizedBox(height: 14),

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
          extraNote: 'Direct Investments: ${AppFormatters.currency(details.directInvestmentsTotal)} • Liquid Surplus: ${AppFormatters.currency(details.unspentCashSurplus)}',
        ),

        const SizedBox(height: 16),

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Header Card
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
                      color: details.isSavingsSafe ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${details.savingsPercentage.toStringAsFixed(1)}% of Income (Target ≥ 20%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: details.isSavingsSafe ? const Color(0xFF047857) : const Color(0xFFB91C1C),
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
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2 Pillars of Savings
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: Colors.blue, size: 16),
                        SizedBox(width: 4),
                        Text('Investments', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(details.directInvestmentsTotal),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SIP, Stocks, Gold, PPF',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_rounded, color: Colors.teal, size: 16),
                        SizedBox(width: 4),
                        Text('Liquid Surplus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(details.unspentCashSurplus),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unspent in bank balance',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        const Text(
          'Investment Transactions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
    // Sort category breakdown descending by amount
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
