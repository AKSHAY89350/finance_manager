import 'package:flutter/material.dart';
import '../services/financial_analytics_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class SavingsRateCard extends StatelessWidget {
  final SavingsRateReport report;

  const SavingsRateCard({super.key, required this.report});

  Color _getTierColor() {
    switch (report.tier) {
      case SavingsRateTier.elite:
        return const Color(0xFF8B5CF6); // Purple / Violet
      case SavingsRateTier.superSaver:
        return const Color(0xFF0EA5E9); // Sky Blue
      case SavingsRateTier.healthy:
        return const Color(0xFF10B981); // Emerald Green
      case SavingsRateTier.developing:
        return const Color(0xFFF59E0B); // Amber
      case SavingsRateTier.breakEven:
        return const Color(0xFFF97316); // Orange
      case SavingsRateTier.deficit:
        return const Color(0xFFEF4444); // Red
      case SavingsRateTier.noIncome:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor();
    final clampedProgress = (report.savingsRatePercent / 50.0).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tierColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.savings_outlined, color: tierColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Savings Rate %',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Wealth accumulation ratio',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Tier Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    report.tierBadge,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Hero Metric
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  report.tier == SavingsRateTier.noIncome
                      ? '0.0%'
                      : '${report.savingsRatePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: tierColor,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  report.tierTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tierColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Progress Bar towards 20% & 50% benchmarks
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: clampedProgress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      '20% (Standard 🎯)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: report.savingsRatePercent >= 20.0 ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                    Text(
                      '50% (FIRE / Elite 🏆)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: report.savingsRatePercent >= 50.0 ? const Color(0xFF8B5CF6) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Breakdown Grid: Income | Saved | Living Expense
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Income', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(report.monthlyIncome),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.income),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saved / Inv', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(report.netSavings),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tierColor),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Living Spends', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(report.monthlyNonInvestmentExpense),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.expense),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Description / Guidance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.insights_rounded, size: 16, color: tierColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.description,
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
}
