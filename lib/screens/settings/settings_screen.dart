import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database_helper.dart';
import '../../providers/bank_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/export_helper.dart';
import '../../utils/formatters.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  void _showStartingBalanceDialog(BuildContext context, int bankId, String bankName, double currentStart) {
    final controller = TextEditingController(text: currentStart.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Starting Balance ($bankName)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Starting Balance (₹)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBal = double.tryParse(controller.text.trim());
              if (newBal != null) {
                await DatabaseHelper.instance.updateBankBalance(bankId, newBal);
                await ref.read(bankProvider.notifier).loadBanks();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated starting balance for $bankName')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddBankDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Bank'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Bank Code / Name (e.g. AXIS, ICICI)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Initial Balance (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty) {
                await ref.read(bankProvider.notifier).addBank(name, bal);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $name')),
                  );
                }
              }
            },
            child: const Text('Add Bank'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExcelExport() async {
    setState(() => _isExporting = true);
    try {
      final path = await ExportHelper.exportToExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported Excel file: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleCsvExport() async {
    setState(() => _isExporting = true);
    try {
      final path = await ExportHelper.exportExpensesCSV();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported CSV file: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Transactions?'),
        content: const Text(
          'This will permanently delete all expense, income, and transfer records. Bank accounts and categories will remain intact.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              await DatabaseHelper.instance.clearAllData();
              await ref.read(bankProvider.notifier).loadBanks();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All transactions deleted')),
                );
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankState = ref.watch(bankProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings & Tools')),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating offline export file...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _sectionHeader('Bank Account Management'),
                bankState.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $e')),
                  data: (banks) => Column(
                    children: [
                      ...banks.map((item) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.forBank(item.bank.name).withValues(alpha: 0.15),
                              child: Text(
                                item.bank.name.isNotEmpty ? item.bank.name[0] : 'B',
                                style: TextStyle(color: AppColors.forBank(item.bank.name), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(item.bank.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Starting Bal: ${AppFormatters.currency(item.bank.startingBalance)}'),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Adjust'),
                              onPressed: () {
                                if (item.bank.id != null) {
                                  _showStartingBalanceDialog(context, item.bank.id!, item.bank.name, item.bank.startingBalance);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddBankDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Bank Account'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('Data Export & Backup (100% Offline)'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.table_view_rounded, color: Color(0xFF16A34A)),
                    title: const Text('Export to Excel (.xlsx)'),
                    subtitle: const Text('Saves workbook with Expenses, Income, Transfers & Balances'),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: _handleExcelExport,
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                    title: const Text('Export Expenses to CSV'),
                    subtitle: const Text('Comma-separated raw transaction logs'),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: _handleCsvExport,
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('Data Maintenance'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: AppColors.expense),
                    title: const Text('Clear All Transactions', style: TextStyle(color: AppColors.expense)),
                    subtitle: const Text('Permanently wipe transaction ledger'),
                    onTap: _showClearDataConfirmation,
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('About Application'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                    title: const Text(AppConstants.appName),
                    subtitle: const Text('Version 1.0.0 • 100% Offline (SQLite Engine)'),
                  ),
                ),
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
