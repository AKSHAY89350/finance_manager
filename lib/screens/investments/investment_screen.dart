import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;

  double _totalInvested = 0.0;
  double _totalSip = 0.0;
  double _totalFdRd = 0.0;
  double _totalPpfRetirement = 0.0;
  int _totalTxnCount = 0;

  List<Map<String, dynamic>> _allocationList = [];
  List<Map<String, dynamic>> _monthlyRows = [];

  @override
  void initState() {
    super.initState();
    _loadInvestmentData();
  }

  Future<void> _loadInvestmentData() async {
    setState(() => _isLoading = true);

    final total = await DatabaseHelper.instance.getTotalInvested(year: _selectedYear);
    final alloc = await DatabaseHelper.instance.getInvestmentAllocation(year: _selectedYear);
    final monthly = await DatabaseHelper.instance.getMonthlyInvestmentBreakdown(_selectedYear);

    double sip = 0.0;
    double fdRd = 0.0;
    double ppf = 0.0;
    int txns = 0;

    for (final item in alloc) {
      final sub = (item['sub_category'] as String?)?.toUpperCase() ?? '';
      final amt = (item['total'] as num).toDouble();
      final count = (item['txn_count'] as int?) ?? 0;
      txns += count;

      if (sub.contains('SIP')) {
        sip += amt;
      } else if (sub.contains('FD') || sub.contains('RD')) {
        fdRd += amt;
      } else if (sub.contains('PPF') || sub.contains('NPS')) {
        ppf += amt;
      }
    }

    if (mounted) {
      setState(() {
        _totalInvested = total;
        _totalSip = sip;
        _totalFdRd = fdRd;
        _totalPpfRetirement = ppf;
        _totalTxnCount = txns;
        _allocationList = alloc;
        _monthlyRows = monthly;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Investment Portfolio'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<int>(
              dropdownColor: AppColors.primaryDark,
              underline: const SizedBox.shrink(),
              iconEnabledColor: Colors.white,
              value: _selectedYear,
              items: [2024, 2025, 2026, 2027].map((y) {
                return DropdownMenuItem(
                  value: y,
                  child: Text('$y', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadInvestmentData();
                }
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvestmentData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Banner Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B21B6), AppColors.investment, Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.investment.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL INVESTED (YTD)',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                            ),
                            Icon(Icons.auto_graph_rounded, color: Colors.white70, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.currency(_totalInvested),
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_totalTxnCount verified investments across asset classes',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Key Asset Breakdown Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'TOTAL SIPs',
                          amount: _totalSip,
                          icon: Icons.repeat_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'FD & RD',
                          amount: _totalFdRd,
                          icon: Icons.account_balance_rounded,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'PPF / RETIRE',
                          amount: _totalPpfRetirement,
                          icon: Icons.shield_outlined,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Asset Allocation Section
                  const Text(
                    'Asset Type Allocation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _allocationList.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No investment records found for this year'),
                              ),
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 180,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 36,
                                      sections: _buildAllocationSections(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ..._allocationList.map((item) {
                                  final sub = item['sub_category'] ?? 'Other';
                                  final amt = (item['total'] as num).toDouble();
                                  final count = item['txn_count'] as int;
                                  final pct = _totalInvested > 0 ? (amt / _totalInvested) * 100 : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('$sub ($count txns)', style: const TextStyle(fontWeight: FontWeight.w500)),
                                        Text('${AppFormatters.currency(amt)}  (${pct.toStringAsFixed(1)}%)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.investment)),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Monthly Breakdown Tracker
                  const Text(
                    'Monthly Breakdown Ledger',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  if (_monthlyRows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                      child: const Center(child: Text('No monthly investment ledger for this year', style: TextStyle(color: AppColors.textSecondary))),
                    )
                  else
                    ..._monthlyRows.map((row) {
                      final monthIndex = (row['month'] as int) - 1;
                      final monthName = monthIndex >= 0 && monthIndex < 12 ? AppConstants.monthNames[monthIndex] : 'Month ${row['month']}';
                      final sub = row['sub_category'] as String? ?? 'General';
                      final total = (row['total'] as num).toDouble();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF3E8FF),
                            child: Icon(Icons.trending_up, color: AppColors.investment),
                          ),
                          title: Text('$monthName • $sub', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: Text(
                            AppFormatters.currency(total),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.investment, fontSize: 14),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  List<PieChartSectionData> _buildAllocationSections() {
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF0284C7),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
    ];

    return List.generate(_allocationList.length, (i) {
      final item = _allocationList[i];
      final amt = (item['total'] as num).toDouble();
      final pct = _totalInvested > 0 ? (amt / _totalInvested) * 100 : 0.0;
      final color = colors[i % colors.length];

      return PieChartSectionData(
        value: amt,
        color: color,
        radius: 44,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppFormatters.currency(amount),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
