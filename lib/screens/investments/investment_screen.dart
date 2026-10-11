import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class InvestmentScreen extends StatelessWidget {
  const InvestmentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Investments')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📈', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text('Investment Portfolio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Phase 6 — Portfolio tracker & asset allocation', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
