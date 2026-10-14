import 'package:flutter/material.dart';
import '../services/financial_analytics_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class AssetAllocationCard extends StatelessWidget {
  final AssetAllocationReport report;

  const AssetAllocationCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    const equityColor = Color(0xFF7C3AED); // Purple
    const debtColor = Color(0xFF10B981);   // Emerald
    const goldColor = Color(0xFFF59E0B);   // Amber Gold
    const cashColor = Color(0xFF0EA5E9);   // Sky Blue

    final total = report.totalNetWealth;
    final eqFlex = (report.equityPercent * 10).round();
    final debtFlex = (report.debtPercent * 10).round();
    final goldFlex = (report.goldPercent * 10).round();
    final cashFlex = (report.cashPercent * 10).round();
    final hasValidFlex = eqFlex > 0 || debtFlex > 0 || goldFlex > 0 || cashFlex > 0;

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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: equityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: equityColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asset Allocation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Equity • Debt • Gold • Cash',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  AppFormatters.currencyRounded(total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Segmented Distribution Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: (total > 0 && hasValidFlex)
                    ? Row(
                        children: [
                          if (eqFlex > 0)
                            Expanded(
                              flex: eqFlex,
                              child: Container(color: equityColor),
                            ),
                          if (debtFlex > 0)
                            Expanded(
                              flex: debtFlex,
                              child: Container(color: debtColor),
                            ),
                          if (goldFlex > 0)
                            Expanded(
                              flex: goldFlex,
                              child: Container(color: goldColor),
                            ),
                          if (cashFlex > 0)
                            Expanded(
                              flex: cashFlex,
                              child: Container(color: cashColor),
                            ),
                        ],
                      )
                    : Container(color: Colors.grey.shade300),
              ),
            ),

            const SizedBox(height: 16),

            // 4-Asset Breakdown Grid
            Row(
              children: [
                Expanded(
                  child: _buildAssetTile(
                    label: 'Equity',
                    icon: '📈',
                    amount: report.equityAmount,
                    pct: report.equityPercent,
                    color: equityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAssetTile(
                    label: 'Debt / Fixed',
                    icon: '🛡️',
                    amount: report.debtAmount,
                    pct: report.debtPercent,
                    color: debtColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAssetTile(
                    label: 'Gold / SGB',
                    icon: '🪙',
                    amount: report.goldAmount,
                    pct: report.goldPercent,
                    color: goldColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAssetTile(
                    label: 'Liquid Cash',
                    icon: '💵',
                    amount: report.cashAmount,
                    pct: report.cashPercent,
                    color: cashColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Diversification Guidance Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 16, color: equityColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.diversificationSummary,
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

  Widget _buildAssetTile({
    required String label,
    required String icon,
    required double amount,
    required double pct,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.currency(amount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
