import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bank.dart';
import '../../models/recurring_rule.dart';
import '../../providers/bank_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class RecurringRulesScreen extends ConsumerStatefulWidget {
  const RecurringRulesScreen({super.key});

  @override
  ConsumerState<RecurringRulesScreen> createState() => _RecurringRulesScreenState();
}

class _RecurringRulesScreenState extends ConsumerState<RecurringRulesScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Check and process due rules whenever the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringProvider.notifier).processDueAutoDebits(context: context);
    });
  }

  void _showAddEditDialog(BuildContext context, [RecurringRule? existingRule]) {
    final titleCtrl = TextEditingController(text: existingRule?.title ?? '');
    final amountCtrl = TextEditingController(text: existingRule != null ? existingRule.amount.toString() : '');
    final notesCtrl = TextEditingController(text: existingRule?.notes ?? '');

    String selectedType = existingRule?.type ?? 'SIP';
    String selectedCategory = existingRule?.category ?? 'SIP & Investments';
    String? selectedSubCategory = existingRule?.subCategory ?? 'Mutual Funds (SIP)';

    final bankState = ref.read(bankProvider);
    final banks = bankState.maybeWhen(
      data: (list) => list,
      orElse: () => <BankBalanceInfo>[],
    );

    String selectedBank = existingRule?.bank ?? (banks.isNotEmpty ? banks.first.bank.name : AppConstants.defaultBanks.first);
    int selectedDay = existingRule?.dayOfMonth ?? 5;
    DateTime selectedStartDate = existingRule != null
        ? AppFormatters.parseDbDate(existingRule.startDate)
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) {
                return Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: AppColors.textPrimary),
                    title: Text(
                      existingRule == null ? 'New Auto-Debit Rule' : 'Edit Auto-Debit Rule',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  body: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // Type Selector Chips
                      const Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: AppConstants.recurringTypes.map((type) {
                            final isSel = selectedType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: isSel,
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() {
                                      selectedType = type;
                                      if (type == 'SIP') {
                                        selectedCategory = 'SIP & Investments';
                                        selectedSubCategory = 'Mutual Funds (SIP)';
                                      } else if (type == 'Loan EMI') {
                                        selectedCategory = 'Loan';
                                        selectedSubCategory = 'Home Loan';
                                      } else if (type == 'Rent') {
                                        selectedCategory = 'Home Send';
                                        selectedSubCategory = 'House Rent';
                                      } else if (type == 'Bill') {
                                        selectedCategory = 'Bills & Utilities';
                                        selectedSubCategory = 'Electricity Bill';
                                      }
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title / Description *',
                          hintText: selectedType == 'SIP'
                              ? 'e.g. Parag Parikh Flexi Cap SIP'
                              : (selectedType == 'Loan EMI' ? 'e.g. SBI Home Loan EMI' : 'e.g. House Rent'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: InputDecoration(
                          labelText: 'Auto-Debit Amount (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Account Dropdown with live balance
                      const Text('Debit From Bank Account *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedBank,
                            items: (banks.isNotEmpty
                                    ? banks.map((b) => b.bank.name).toList()
                                    : AppConstants.defaultBanks)
                                .map((bName) {
                              final bankInfo = banks.firstWhere(
                                (item) => item.bank.name == bName,
                                orElse: () => BankBalanceInfo(
                                  bank: Bank(name: bName, startingBalance: 0),
                                  liveBalance: 0,
                                ),
                              );
                              return DropdownMenuItem<String>(
                                value: bName,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance, size: 18, color: AppColors.forBank(bName)),
                                        const SizedBox(width: 8),
                                        Text(bName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text(
                                      'Bal: ${AppFormatters.currency(bankInfo.liveBalance)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: bankInfo.liveBalance < 0 ? AppColors.expense : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedBank = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Day of month & Start date row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Deduction Day *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.divider),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: selectedDay,
                                      items: List.generate(31, (i) => i + 1).map((day) {
                                        return DropdownMenuItem(
                                          value: day,
                                          child: Text('Day $day of month'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedDay = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dialogCtx,
                                      initialDate: selectedStartDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => selectedStartDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.divider),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppFormatters.shortDate(selectedStartDate),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Optional Notes
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notes / Folio / Loan Account # (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim());

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a title')),
                            );
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount')),
                            );
                            return;
                          }

                          // Compute initial nextDueDate
                          DateTime initialDue = DateTime(
                            selectedStartDate.year,
                            selectedStartDate.month,
                            selectedDay,
                          );
                          // If that day has already passed in selectedStartDate month, move to next month
                          if (initialDue.isBefore(DateTime(selectedStartDate.year, selectedStartDate.month, selectedStartDate.day))) {
                            initialDue = DateTime(
                              selectedStartDate.month == 12 ? selectedStartDate.year + 1 : selectedStartDate.year,
                              selectedStartDate.month == 12 ? 1 : selectedStartDate.month + 1,
                              selectedDay,
                            );
                          }

                          final newRule = RecurringRule(
                            id: existingRule?.id,
                            title: title,
                            type: selectedType,
                            category: selectedCategory,
                            subCategory: selectedSubCategory,
                            amount: amount,
                            bank: selectedBank,
                            dayOfMonth: selectedDay,
                            startDate: AppFormatters.dbDate(selectedStartDate),
                            nextDueDate: existingRule?.nextDueDate ?? AppFormatters.dbDate(initialDue),
                            lastProcessedDate: existingRule?.lastProcessedDate,
                            isActive: existingRule?.isActive ?? true,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            lastStatus: existingRule?.lastStatus ?? 'PENDING',
                            lastStatusMessage: existingRule?.lastStatusMessage,
                          );

                          if (existingRule == null) {
                            await ref.read(recurringProvider.notifier).addRule(newRule);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto-Debit rule created successfully')),
                              );
                            }
                          } else {
                            await ref.read(recurringProvider.notifier).updateRule(newRule);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto-Debit rule updated')),
                              );
                            }
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          existingRule == null ? 'Set Auto-Debit' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(recurringProvider);
    final bankState = ref.watch(bankProvider);
    final monthlyTotal = ref.watch(totalMonthlyRecurringProvider);
    final lowBalanceAlertCount = ref.watch(lowBalanceAlertCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Auto-Debits (SIP & Loans)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Run Due Auto-Debits Check',
            onPressed: () {
              ref.read(recurringProvider.notifier).processDueAutoDebits(
                    context: context,
                    showFeedback: true,
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How Auto-Debits Work',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Auto-Debit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditDialog(context),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (rules) {
          final filtered = _selectedFilter == 'All'
              ? rules
              : rules.where((r) => r.type.toLowerCase() == _selectedFilter.toLowerCase()).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Monthly Commitments Summary Card
              _buildOverviewCard(monthlyTotal, rules.where((r) => r.isActive).length, lowBalanceAlertCount),
              const SizedBox(height: 16),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...AppConstants.recurringTypes].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSel,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedFilter = filter);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule_send_outlined, size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        const Text(
                          'No Auto-Debits Configured',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set your SIP investments, loan EMIs, and monthly rent once. They will automatically deduct on their fixed date if your bank has sufficient balance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Auto-Debit'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((rule) {
                  // Find current live balance for the bank
                  double liveBal = 0;
                  bankState.whenData((bankList) {
                    final item = bankList.firstWhere(
                      (b) => b.bank.name.toLowerCase() == rule.bank.toLowerCase(),
                      orElse: () => BankBalanceInfo(
                        bank: Bank(name: rule.bank, startingBalance: 0),
                        liveBalance: 0,
                      ),
                    );
                    liveBal = item.liveBalance;
                  });

                  return _buildRecurringCard(context, rule, liveBal);
                }),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(double monthlyTotal, int activeCount, int lowBalanceCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), AppColors.primary, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL MONTHLY RECURRING COMMITMENT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeCount Active',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppFormatters.currency(monthlyTotal),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.security, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Auto-deducts on fixed date only if bank balance is sufficient.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          if (lowBalanceCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$lowBalanceCount auto-debit(s) skipped due to insufficient balance.',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringCard(BuildContext context, RecurringRule rule, double liveBalance) {
    final isLowBalance = liveBalance < rule.amount;
    final isFailed = rule.lastStatus == 'INSUFFICIENT_BALANCE';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isFailed
            ? BorderSide(color: Colors.red.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type Avatar, Title, Active Switch, Popup Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _getTypeColor(rule.type).withValues(alpha: 0.15),
                  child: Icon(_getTypeIcon(rule.type), color: _getTypeColor(rule.type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rule.scheduleDescription,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: rule.isActive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(recurringProvider.notifier).toggleActive(rule.id!, val);
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditDialog(context, rule);
                    } else if (val == 'delete') {
                      _confirmDelete(context, rule);
                    } else if (val == 'process') {
                      ref.read(recurringProvider.notifier).retryRule(rule.id!, context: context);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'process', child: Text('Process / Retry Debit Now')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Middle Row: Bank & Live Balance vs Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bank chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.forBank(rule.bank).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance, size: 14, color: AppColors.forBank(rule.bank)),
                          const SizedBox(width: 4),
                          Text(
                            rule.bank,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.forBank(rule.bank),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bal: ${AppFormatters.currency(liveBalance)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLowBalance ? AppColors.expense : AppColors.textSecondary,
                        fontWeight: isLowBalance ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                // Amount
                Text(
                  AppFormatters.currency(rule.amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Next Due Date & Status Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Next Due: ${rule.nextDueDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: rule.isDue ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: rule.isDue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (!rule.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Paused', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  )
                else if (isFailed)
                  InkWell(
                    onTap: () {
                      ref.read(recurringProvider.notifier).retryRule(rule.id!, context: context);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Low Bal • Tap to Retry',
                            style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (rule.lastStatus == 'SUCCESS')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '✓ Debited on ${rule.lastProcessedDate ?? ''}',
                      style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sip':
        return Icons.trending_up_rounded;
      case 'loan emi':
      case 'loan':
        return Icons.account_balance_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'bill':
        return Icons.receipt_long_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'sip':
        return AppColors.investment;
      case 'loan emi':
      case 'loan':
        return AppColors.loan;
      case 'rent':
        return AppColors.income;
      case 'bill':
        return AppColors.catBills;
      default:
        return AppColors.primary;
    }
  }

  void _confirmDelete(BuildContext context, RecurringRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${rule.title}"?'),
        content: const Text(
          'Are you sure you want to delete this auto-debit rule? Past recorded transactions will not be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              await ref.read(recurringProvider.notifier).deleteRule(rule.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto-debit rule deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Smart Auto-Debit Shield'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Fixed Date Execution:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your SIPs, Loans, and Rent auto-deduct on their designated day of the month without manual entry.\n',
              style: TextStyle(fontSize: 13),
            ),
            Text(
              '2. Balance Verification Guarantee:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Before any deduction, the app checks if the selected bank account has sufficient balance. If funds are insufficient, it skips the deduction and alerts you so your balance is never negative.\n',
              style: TextStyle(fontSize: 13),
            ),
            Text(
              '3. 100% Offline & Private:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'No external bank logins or internet required. Everything runs securely on your device.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
