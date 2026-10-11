import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transactions')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📋', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text('All Transactions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Phase 3 — Expense list with filters', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
