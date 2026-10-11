import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_pie_chart.dart';
import '../../widgets/monthly_bar_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  bool _isLoading = true;
  List<Map<String, dynamic>> _categoryData = [];
  double _totalCategoryExpense = 0.0;
  List<double> _monthlyTotals = List.filled(12, 0.0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final start = AppFormatters.monthStart(_selectedYear, _selectedMonth);
    final end = AppFormatters.monthEnd(_selectedYear, _selectedMonth);

    // 1. Category Distribution
    final catData = await DatabaseHelper.instance.getCategoryBreakdown(
      dateFrom: start,
      dateTo: end,
    );
    double totalCat = 0;
    for (final row in catData) {
      totalCat += (row['total'] as num).toDouble();
    }

    // 2. Monthly Summary per bank for the entire year
    final bankRows = await DatabaseHelper.instance.getMonthlyBankSummary(year: _selectedYear);
    final totals = List<double>.filled(12, 0.0);
    for (final row in bankRows) {
      final m = (row['month'] as int) - 1;
      if (m >= 0 && m < 12) {
        totals[m] += (row['total'] as num).toDouble();
      }
    }

    if (mounted) {
      setState(() {
        _categoryData = catData;
        _totalCategoryExpense = totalCat;
        _monthlyTotals = totals;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline), text: 'Category Chart'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Monthly Matrix'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryChartView(),
                _buildMonthlyMatrixView(),
              ],
            ),
    );
  }

  Widget _buildCategoryChartView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filter Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(AppConstants.monthNames[index]),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _loadReportData();
                }
              },
            ),
            DropdownButton<int>(
              value: _selectedYear,
              items: [2024, 2025, 2026, 2027].map((y) {
                return DropdownMenuItem(value: y, child: Text('$y'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadReportData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Total Spent summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent (${AppConstants.shortMonthNames[_selectedMonth - 1]} $_selectedYear)',
                style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              Text(
                AppFormatters.currency(_totalCategoryExpense),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.expense),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Pie Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CategoryPieChart(
              categoryData: _categoryData,
              totalAmount: _totalCategoryExpense,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Category Detail Breakdown Table
        const Text(
          'Detailed Category Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),

        if (_categoryData.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No expense records for this month')),
          )
        else
          ..._categoryData.map((row) {
            final cat = row['category'] as String;
            final total = (row['total'] as num).toDouble();
            final count = row['txn_count'] as int;
            final pct = _totalCategoryExpense > 0 ? (total / _totalCategoryExpense) * 100 : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.forCategory(cat).withValues(alpha: 0.15),
                  child: Text(
                    AppConstants.categoryIcons[cat] ?? '🔹',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$count transactions (${pct.toStringAsFixed(1)}%)'),
                trailing: Text(
                  AppFormatters.currency(total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMonthlyMatrixView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Annual Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              value: _selectedYear,
              items: [2024, 2025, 2026, 2027].map((y) {
                return DropdownMenuItem(value: y, child: Text('$y'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadReportData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Monthly Bar Chart (Jan - Dec)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Spending Trends (Jan–Dec)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                MonthlyBarChart(monthlyTotals: _monthlyTotals),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Month-by-Month Expenses List
        const Text(
          'Month-by-Month Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...List.generate(12, (index) {
          final total = _monthlyTotals[index];
          final monthName = AppConstants.monthNames[index];
          if (total == 0) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(monthName, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text(
                AppFormatters.currency(total),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
              ),
            ),
          );
        }),
      ],
    );
  }
}
