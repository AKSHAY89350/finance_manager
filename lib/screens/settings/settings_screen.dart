import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _sectionHeader('App Info'),
          _tile(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            value: AppConstants.appVersion,
          ),
          _tile(
            icon: Icons.phone_android_rounded,
            label: 'Platform',
            value: '100% Offline — Android',
          ),
          const SizedBox(height: 8),
          _sectionHeader('Coming in Phase 7'),
          _tile(icon: Icons.account_balance_rounded,   label: 'Banks Management',     value: ''),
          _tile(icon: Icons.category_rounded,          label: 'Category Management',  value: ''),
          _tile(icon: Icons.file_download_outlined,    label: 'Export to Excel',       value: ''),
          _tile(icon: Icons.backup_rounded,            label: 'Backup & Restore',      value: ''),
          _tile(icon: Icons.dark_mode_outlined,        label: 'Dark Mode',             value: ''),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textHint, letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile({required IconData icon, required String label, required String value}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        trailing: value.isEmpty
            ? const Icon(Icons.chevron_right_rounded, color: AppColors.textHint)
            : Text(value, style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
