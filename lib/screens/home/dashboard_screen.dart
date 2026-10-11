import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Dashboard / Home screen — Phase 4 will fill this with live data.
/// For now shows a placeholder so the app compiles and runs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Finance Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏠', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Phase 4 — Live bank balances & charts',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
