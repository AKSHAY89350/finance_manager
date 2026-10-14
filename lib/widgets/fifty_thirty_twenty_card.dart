import 'package:flutter/material.dart';
import '../services/financial_analytics_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class FiftyThirtyTwentyCard extends StatelessWidget {
  final FiftyThirtyTwentyReport report;

  const FiftyThirtyTwentyCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    const needsColor = Color(0xFF3B82F6);  // Blue
    const wantsColor = Color(0xFFEC4899);  // Pink/Coral
    const savingsColor = Color(0xFF10B981); // Emerald Green

    final totalPct = report.needsPercentage + report.wantsPercentage + report.savingsPercentage;
    final double normNeeds = totalPct > 0 ? report.needsPercentage / totalPct : 0.5;
    final double normWants = totalPct > 0 ? report.wantsPercentage / totalPct : 0.3;
    final double normSavings = totalPct > 0 ? report.savingsPercentage / totalPct : 0.2;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: Colors.indigo, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '50-30-20 Rule Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Needs ≤50% • Wants ≤30% • Savings ≥20%',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Gauge / Segmented Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    if (normNeeds > 0)
                      Expanded(
                        flex: (normNeeds * 1000).toInt(),
                        child: Container(
                          color: needsColor,
                          alignment: Alignment.center,
                          child: normNeeds > 0.15
                              ? Text(
                                  '${report.needsPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    if (normWants > 0)
                      Expanded(
                        flex: (normWants * 1000).toInt(),
                        child: Container(
                          color: wantsColor,
                          alignment: Alignment.center,
                          child: normWants > 0.15
                              ? Text(
                                  '${report.wantsPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    if (normSavings > 0)
                      Expanded(
                        flex: (normSavings * 1000).toInt(),
                        child: Container(
                          color: savingsColor,
                          alignment: Alignment.center,
                          child: normSavings > 0.15
                              ? Text(
                                  '${report.savingsPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3 Column Breakdown
            Row(
              children: [
                // Needs
                Expanded(
                  child: _buildCategoryColumn(
                    title: 'Needs',
                    target: '≤ 50%',
                    amount: report.needsAmount,
                    pct: report.needsPercentage,
                    color: needsColor,
                    isSafe: report.isNeedsSafe,
                    safeLabel: 'On Track',
                    unsafeLabel: 'High',
                  ),
                ),
                const SizedBox(width: 8),
                // Wants
                Expanded(
                  child: _buildCategoryColumn(
                    title: 'Wants',
                    target: '≤ 30%',
                    amount: report.wantsAmount,
                    pct: report.wantsPercentage,
                    color: wantsColor,
                    isSafe: report.isWantsSafe,
                    safeLabel: 'Controlled',
                    unsafeLabel: 'Elevated',
                  ),
                ),
                const SizedBox(width: 8),
                // Savings
                Expanded(
                  child: _buildCategoryColumn(
                    title: 'Savings',
                    target: '≥ 20%',
                    amount: report.savingsAmount,
                    pct: report.savingsPercentage,
                    color: savingsColor,
                    isSafe: report.isSavingsSafe,
                    safeLabel: 'Target Met',
                    unsafeLabel: 'Low',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Advice Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.advice,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryColumn({
    required String title,
    required String target,
    required double amount,
    required double pct,
    required Color color,
    required bool isSafe,
    required String safeLabel,
    required String unsafeLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSafe ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSafe ? safeLabel : unsafeLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSafe ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormatters.currencyCompact(amount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Goal $target',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
