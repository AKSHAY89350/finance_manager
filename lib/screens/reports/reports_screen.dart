import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📊', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Phase 5 — Monthly summary & pie charts', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
