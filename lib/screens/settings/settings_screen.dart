import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database_helper.dart';
import '../../models/bank.dart';
import '../../models/initial_investment.dart';
import '../../models/merchant_rule.dart';
import '../../providers/bank_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../services/biometric_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/excel_import_helper.dart';
import '../../utils/export_helper.dart';
import '../../utils/formatters.dart';
import '../transactions/review_inbox_screen.dart';
import '../recurring/recurring_rules_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) setState(() => _isBiometricEnabled = enabled);
  }

  Future<void> _toggleBiometric(bool value) async {
    final success = await BiometricService.authenticate(
      reason: value
          ? 'Authenticate to enable biometric app lock'
          : 'Authenticate to disable biometric app lock',
    );
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed. Lock setting unchanged.')),
        );
      }
      return;
    }
    await BiometricService.setBiometricEnabled(value);
    if (mounted) setState(() => _isBiometricEnabled = value);
  }

  void _showBankEditDialog(BuildContext context, Bank bank) {
    final balCtrl = TextEditingController(text: bank.startingBalance.toString());
    final last4Ctrl = TextEditingController(text: bank.accountLast4 ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${bank.name} Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Starting Balance (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: last4Ctrl,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Last 4 Digits (for SMS Matching)',
                hintText: 'e.g. 4589',
                helperText: 'SMS stating A/c XX4589 will auto-link here',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (bank.id == null) return;
              final newBal = double.tryParse(balCtrl.text.trim()) ?? bank.startingBalance;
              final newLast4 = last4Ctrl.text.trim();
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              await DatabaseHelper.instance.updateBankBalance(bank.id!, newBal);
              await DatabaseHelper.instance.updateBankLast4(bank.id!, newLast4.isEmpty ? null : newLast4);
              await ref.read(bankProvider.notifier).loadBanks();

              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Updated ${bank.name} settings')),
                );
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
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(bankProvider.notifier).addBank(name, bal);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
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

  void _showInvestmentEditDialog(BuildContext context, InitialInvestment asset) {
    final balCtrl = TextEditingController(text: asset.startingBalance.toString());
    final notesCtrl = TextEditingController(text: asset.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${asset.assetName} Starting Value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Initial Holding / Starting Value (₹)',
                prefixText: '₹ ',
                helperText: 'Existing investment value before tracking in app',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes / Folio (Optional)',
                hintText: 'e.g. Zerodha, Groww, Folio #',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (asset.id == null) return;
              final newBal = double.tryParse(balCtrl.text.trim()) ?? asset.startingBalance;
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              await ref.read(investmentProvider.notifier).updateStartingBalance(asset.id!, newBal);

              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Updated ${asset.assetName} starting value')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddInvestmentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Investment Instrument'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Instrument Name (e.g. Real Estate, Crypto, US Stocks)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Initial Holding Value (₹)',
                prefixText: '₹ ',
              ),
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
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(investmentProvider.notifier).addInvestment(name, bal);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Added $name')),
                  );
                }
              }
            },
            child: const Text('Add Instrument'),
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

  Future<void> _handleExcelImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File exceeds 20MB limit. Please select a valid Excel file.')),
          );
        }
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final f = File(file.path!);
        bytes = await f.readAsBytes();
      }

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file')),
          );
        }
        return;
      }

      setState(() => _isExporting = true);

      final importRes = await ExcelImportHelper.importExcelFile(bytes);

      // Refresh live banks, expenses, incomes, and transfers
      await ref.read(bankProvider.notifier).loadBanks();
      await ref.read(expenseProvider.notifier).loadExpenses();
      await ref.read(incomeProvider.notifier).loadIncome();
      await ref.read(transferProvider.notifier).loadTransfers();

      if (mounted) {
        if (importRes.isSuccess) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excel Import Successful!'),
              content: Text(
                'Successfully imported:\n'
                '• ${importRes.expensesCount} Expenses\n'
                '• ${importRes.incomeCount} Income Entries\n'
                '• ${importRes.transferCount} Bank Transfers\n\n'
                'All live balances and reports have been updated automatically!',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: ${importRes.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing file: $e')),
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
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await DatabaseHelper.instance.clearAllData();
              await ref.read(bankProvider.notifier).loadBanks();
              await ref.read(expenseProvider.notifier).loadExpenses();
              await ref.read(incomeProvider.notifier).loadIncome();
              await ref.read(transferProvider.notifier).loadTransfers();
              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
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

  void _showLearnedRulesDialog(BuildContext context) async {
    final List<MerchantRule> rules = await DatabaseHelper.instance.getAllMerchantRules();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Text('Learned Categorization Rules'),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: rules.isEmpty
                  ? const Center(
                      child: Text(
                        'No custom merchant rules yet.\nRules are learned automatically whenever you edit an auto-detected transaction.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rules.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final r = rules[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.merchantKeyword, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${r.category}${r.subCategory != null ? " › ${r.subCategory}" : ""} (Used ${r.usageCount}x)'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteMerchantRule(r.merchantKeyword);
                              final updated = await DatabaseHelper.instance.getAllMerchantRules();
                              setDialogState(() {
                                rules.clear();
                                rules.addAll(updated);
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
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
                        final hasLast4 = item.bank.accountLast4 != null && item.bank.accountLast4!.isNotEmpty;
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
                            subtitle: Text(
                              'Start Bal: ${AppFormatters.currency(item.bank.startingBalance)}'
                              '${hasLast4 ? " • A/c: ••••${item.bank.accountLast4}" : " • No A/c digits"}',
                            ),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              onPressed: () {
                                _showBankEditDialog(context, item.bank);
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
                _sectionHeader('Investment Portfolio Management'),
                ref.watch(investmentProvider).when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $e')),
                  data: (holdings) => Column(
                    children: [
                      ...holdings.map((item) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.investment.withValues(alpha: 0.15),
                              child: const Icon(Icons.trending_up_rounded, color: AppColors.investment, size: 20),
                            ),
                            title: Text(item.asset.assetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Start Bal: ${AppFormatters.currency(item.asset.startingBalance)} • Live Total: ${AppFormatters.currency(item.liveTotal)}',
                            ),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              onPressed: () {
                                _showInvestmentEditDialog(context, item.asset);
                              },
                            ),
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddInvestmentDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Investment Asset'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('On-Time SMS & Review Tools (Phase 9)'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.inbox_outlined, color: AppColors.primary),
                    title: const Text('Review Inbox (Auto-Detected)'),
                    subtitle: const Text('Review, confirm or edit pending SMS and UPI entries'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReviewInboxScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.psychology_outlined, color: Colors.purple),
                    title: const Text('Learned Categorization Rules'),
                    subtitle: const Text('View & manage merchant auto-mapping rules learned on-device'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLearnedRulesDialog(context),
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('Automation & Standing Orders'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.schedule_send_rounded, color: AppColors.investment),
                    title: const Text('Auto-Debits (SIP, EMI & Loans)'),
                    subtitle: const Text('Manage fixed-date payments with bank balance verification'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecurringRulesScreen()),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('Security & Biometrics'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
                    title: const Text('Biometric App Lock'),
                    subtitle: const Text('Require Fingerprint / Face ID / PIN to open app'),
                    value: _isBiometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                ),

                const SizedBox(height: 16),
                _sectionHeader('Data Export & Import (100% Offline)'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.file_upload_outlined, color: AppColors.primary),
                    title: const Text('Import from Excel (.xlsx)'),
                    subtitle: const Text('Load your existing spreadsheet data directly into the app'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _handleExcelImport,
                  ),
                ),
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
                const Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                    title: Text(AppConstants.appName),
                    subtitle: Text('Version 1.0.0 • 100% Offline (SQLite Engine)'),
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
