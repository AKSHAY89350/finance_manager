import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/financial_health_provider.dart';
import '../../providers/investment_provider.dart';
import '../../screens/main_scaffold.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/asset_allocation_card.dart';
import '../recurring/recurring_rules_screen.dart';

class InvestmentScreen extends ConsumerStatefulWidget {
  const InvestmentScreen({super.key});

  @override
  ConsumerState<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends ConsumerState<InvestmentScreen> {
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

  Future<void> _loadInvestmentData({bool showSpinner = false}) async {
    if (showSpinner || _allocationList.isEmpty) {
      setState(() => _isLoading = true);
    }

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

      if (sub.contains('SIP') || sub.contains('MUTUAL') || sub.contains('STOCK') || sub.contains('SHARE')) {
        sip += amt;
      } else if (sub.contains('FD') || sub.contains('RD') || sub.contains('GOLD') || sub.contains('SGB')) {
        fdRd += amt;
      } else {
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

  List<int> _availableYears() {
    final curYear = DateTime.now().year;
    final years = List.generate(7, (i) => curYear - 4 + i);
    if (!years.contains(_selectedYear)) {
      years.add(_selectedYear);
      years.sort();
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    // Auto-refresh when switching to Invest tab (index 3), or when expenses/investments update
    ref.listen(selectedTabProvider, (prev, next) {
      if (next == 3) {
        _loadInvestmentData();
      }
    });
    ref.listen(expenseProvider, (prev, next) {
      _loadInvestmentData();
    });
    ref.listen(investmentProvider, (prev, next) {
      _loadInvestmentData();
    });

    final years = _availableYears();

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
              items: years.map((y) {
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
                              'TOTAL PORTFOLIO HOLDINGS',
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
                          'Starting holdings + $_totalTxnCount verified investments across asset classes',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Key Asset Breakdown Stats (All investments grouped)
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'SIP & STOCKS',
                          amount: _totalSip,
                          icon: Icons.repeat_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'FD, RD & GOLD',
                          amount: _totalFdRd,
                          icon: Icons.account_balance_rounded,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'PPF & OTHER',
                          amount: _totalPpfRetirement,
                          icon: Icons.shield_outlined,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Auto-Debit SIPs & Investments Action Card
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecurringRulesScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.investment.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.investment.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.investment.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.schedule_send_rounded, color: AppColors.investment, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SIP & Loan Auto-Debits',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Set fixed-date deductions with live balance verification',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.investment),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Equity vs Debt vs Gold vs Cash Allocation Card
                  ref.watch(financialHealthProvider(HealthFilter(_selectedYear, DateTime.now().month))).maybeWhen(
                    data: (health) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AssetAllocationCard(report: health.assetAllocation),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 8),

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
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('No monthly investment data logged yet')),
                      ),
                    )
                  else
                    ..._buildMonthlyCards(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildMonthlyCards() {
    final Map<int, List<Map<String, dynamic>>> byMonth = {};
    for (final row in _monthlyRows) {
      final m = row['month'] as int;
      byMonth.putIfAbsent(m, () => []).add(row);
    }

    final sortedMonths = byMonth.keys.toList()..sort();

    return sortedMonths.map((m) {
      final rows = byMonth[m]!;
      final monthName = (m >= 1 && m <= 12) ? AppConstants.monthNames[m - 1] : 'Month $m';
      final total = rows.fold<double>(0.0, (sum, r) => sum + (r['total'] as num).toDouble());

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0x1F7C3AED),
            child: Icon(Icons.calendar_month_rounded, color: AppColors.investment, size: 20),
          ),
          title: Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${rows.length} asset classes funded', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: Text(
            AppFormatters.currency(total),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.investment, fontSize: 14),
          ),
          children: rows.map((r) {
            final sub = r['sub_category'] ?? 'Investment';
            final amt = (r['total'] as num).toDouble();
            return ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_right_rounded, color: AppColors.investment),
              title: Text(sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: Text(AppFormatters.currency(amt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  List<PieChartSectionData> _buildAllocationSections() {
    final colors = [
      const Color(0xFF0284C7),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
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
