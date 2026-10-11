import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class CategoryPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> categoryData;
  final double totalAmount;

  const CategoryPieChart({
    super.key,
    required this.categoryData,
    required this.totalAmount,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categoryData.isEmpty || widget.totalAmount <= 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text(
          'No expense data for chart',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    _touchedIndex = (idx >= 0 && idx < widget.categoryData.length) ? idx : -1;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _buildSections(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend List
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: widget.categoryData.map((data) {
            final cat = data['category'] as String;
            final amount = (data['total'] as num).toDouble();
            final pct = (amount / widget.totalAmount) * 100;
            final color = AppColors.forCategory(cat);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  '$cat (${pct.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    return List.generate(widget.categoryData.length, (i) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 65.0 : 55.0;
      final data = widget.categoryData[i];
      final cat = data['category'] as String;
      final amount = (data['total'] as num).toDouble();
      final pct = (amount / widget.totalAmount) * 100;
      final color = AppColors.forCategory(cat);

      return PieChartSectionData(
        color: color,
        value: amount,
        title: '${pct.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
}
