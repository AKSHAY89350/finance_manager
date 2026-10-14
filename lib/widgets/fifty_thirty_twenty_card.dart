import 'package:flutter/material.dart';
import '../services/financial_analytics_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'fifty_thirty_twenty_detail_sheet.dart';

class FiftyThirtyTwentyCard extends StatelessWidget {
  final FiftyThirtyTwentyReport report;
  final int? year;
  final int? month;

  const FiftyThirtyTwentyCard({
    super.key,
    required this.report,
    this.year,
    this.month,
  });

  void _openDetails(BuildContext context, {int initialTab = 0}) {
    final effectiveYear = year ?? DateTime.now().year;
    final effectiveMonth = month ?? DateTime.now().month;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FiftyThirtyTwentyDetailSheet(
        year: effectiveYear,
        month: effectiveMonth,
        initialTabIndex: initialTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const needsColor = Color(0xFF3B82F6);  // Blue
    const wantsColor = Color(0xFFEC4899);  // Pink/Coral
    const savingsColor = Color(0xFF10B981); // Emerald Green

    final totalPct = report.needsPercentage + report.wantsPercentage + report.savingsPercentage;
    final double normNeeds = totalPct > 0 ? report.needsPercentage / totalPct : 0.5;
    final double normWants = totalPct > 0 ? report.wantsPercentage / totalPct : 0.3;
    final double normSavings = totalPct > 0 ? report.savingsPercentage / totalPct : 0.2;

    final int needsFlex = (normNeeds * 1000).round();
    final int wantsFlex = (normWants * 1000).round();
    final int savingsFlex = (normSavings * 1000).round();
    final bool hasValidFlex = needsFlex > 0 || wantsFlex > 0 || savingsFlex > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context, initialTab: 0),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.indigo),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Gauge / Segmented Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 18,
                  child: hasValidFlex
                      ? Row(
                          children: [
                            if (needsFlex > 0)
                              Expanded(
                                flex: needsFlex,
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
                            if (wantsFlex > 0)
                              Expanded(
                                flex: wantsFlex,
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
                            if (savingsFlex > 0)
                              Expanded(
                                flex: savingsFlex,
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
                        )
                      : Container(color: Colors.grey.shade200),
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
                      onTap: () => _openDetails(context, initialTab: 1),
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
                      onTap: () => _openDetails(context, initialTab: 2),
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
                      onTap: () => _openDetails(context, initialTab: 3),
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

              const SizedBox(height: 8),
              Center(
                child: Text(
                  '💡 Tap card or any bucket to view itemized monthly transactions',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
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
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Goal $target',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded, size: 9, color: color.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
