import 'dart:math' as math;
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

    String selectedDirection = existingRule?.direction ?? 'DEBIT'; // 'DEBIT' or 'CREDIT'
    String selectedType = existingRule?.type ?? (selectedDirection == 'DEBIT' ? 'SIP' : 'Salary');
    String selectedCategory = existingRule?.category ?? (selectedDirection == 'DEBIT' ? 'SIP & Investments' : 'Extra Credit');
    String? selectedSubCategory = existingRule?.subCategory ?? (selectedDirection == 'DEBIT' ? 'Mutual Funds (SIP)' : null);

    final bankState = ref.read(bankProvider);
    final banks = bankState.maybeWhen(
      data: (list) => list,
      orElse: () => <BankBalanceInfo>[],
    );

    String selectedBank = existingRule?.bank ?? (banks.isNotEmpty ? banks.first.bank.name : AppConstants.defaultBanks.first);
    int selectedDay = existingRule?.dayOfMonth ?? 1;
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
            final isCredit = selectedDirection == 'CREDIT';

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
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
                      existingRule == null
                          ? (isCredit ? 'New Auto-Income Rule' : 'New Auto-Debit Rule')
                          : (isCredit ? 'Edit Auto-Income Rule' : 'Edit Auto-Debit Rule'),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  body: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // Direction Toggle: Debit vs Credit
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedDirection = 'DEBIT';
                                    selectedType = 'SIP';
                                    selectedCategory = 'SIP & Investments';
                                    selectedSubCategory = 'Mutual Funds (SIP)';
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !isCredit ? AppColors.expense : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: !isCredit ? Colors.white : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Auto-Deduction',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: !isCredit ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedDirection = 'CREDIT';
                                    selectedType = 'Salary';
                                    selectedCategory = 'Extra Credit';
                                    selectedSubCategory = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isCredit ? AppColors.income : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: isCredit ? Colors.white : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Auto-Income',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isCredit ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Type Selector Chips
                      Text(
                        isCredit ? 'Income Type' : 'Deduction Type',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: (isCredit ? AppConstants.recurringIncomeTypes : AppConstants.recurringTypes).map((type) {
                            final isSel = selectedType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: isSel,
                                selectedColor: (isCredit ? AppColors.income : AppColors.primary).withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel
                                      ? (isCredit ? AppColors.income : AppColors.primary)
                                      : AppColors.textPrimary,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() {
                                      selectedType = type;
                                      if (!isCredit) {
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
                                      } else {
                                        selectedCategory = 'Extra Credit';
                                        selectedSubCategory = null;
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
                          labelText: isCredit ? 'Income Source / Title *' : 'Title / Description *',
                          hintText: isCredit
                              ? (selectedType == 'Salary' ? 'e.g. Monthly Salary (Neosoft)' : 'e.g. Tenant Rent')
                              : (selectedType == 'SIP'
                                  ? 'e.g. Parag Parikh Flexi Cap SIP'
                                  : (selectedType == 'Loan EMI' ? 'e.g. SBI Home Loan EMI' : 'e.g. House Rent')),
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
                          labelText: isCredit ? 'Auto-Income Amount (₹) *' : 'Auto-Debit Amount (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Account Dropdown
                      Text(
                        isCredit ? 'Credit Into Bank Account *' : 'Debit From Bank Account *',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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
                                Text(
                                  isCredit ? 'Credit Day *' : 'Deduction Day *',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
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
                          labelText: 'Notes / Details (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: isCredit ? AppColors.income : AppColors.primary,
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final amount = AppFormatters.parseCurrency(amountCtrl.text.trim());

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

                          // Compute initial nextDueDate with safe month length capping (e.g. Feb 28, Apr 30)
                          final daysInCurMonth = DateTime(selectedStartDate.year, selectedStartDate.month + 1, 0).day;
                          final safeCurDay = math.min(selectedDay, daysInCurMonth);
                          DateTime initialDue = DateTime(
                            selectedStartDate.year,
                            selectedStartDate.month,
                            safeCurDay,
                          );
                          // If that day has already passed in selectedStartDate month, move to next month
                          if (initialDue.isBefore(DateTime(selectedStartDate.year, selectedStartDate.month, selectedStartDate.day))) {
                            final nextYear = selectedStartDate.month == 12 ? selectedStartDate.year + 1 : selectedStartDate.year;
                            final nextMonth = selectedStartDate.month == 12 ? 1 : selectedStartDate.month + 1;
                            final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
                            final safeNextDay = math.min(selectedDay, daysInNextMonth);
                            initialDue = DateTime(nextYear, nextMonth, safeNextDay);
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
                            direction: selectedDirection,
                          );

                          if (existingRule == null) {
                            await ref.read(recurringProvider.notifier).addRule(newRule);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isCredit ? 'Auto-Income rule created successfully' : 'Auto-Debit rule created successfully'),
                                  backgroundColor: isCredit ? AppColors.income : AppColors.primary,
                                ),
                              );
                            }
                          } else {
                            await ref.read(recurringProvider.notifier).updateRule(newRule);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isCredit ? 'Auto-Income rule updated' : 'Auto-Debit rule updated'),
                                ),
                              );
                            }
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          existingRule == null
                              ? (isCredit ? 'Set Auto-Income' : 'Set Auto-Debit')
                              : 'Save Changes',
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
    final monthlyDeductions = ref.watch(totalMonthlyRecurringProvider);
    final monthlyIncome = ref.watch(totalMonthlyIncomeProvider);
    final netCashFlow = ref.watch(netMonthlyRecurringFlowProvider);
    final lowBalanceAlertCount = ref.watch(lowBalanceAlertCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recurring Rules (Auto Debit & Income)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Run Due Check Now',
            onPressed: () {
              ref.read(recurringProvider.notifier).processDueAutoDebits(
                    context: context,
                    showFeedback: true,
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How Recurring Rules Work',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Rule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditDialog(context),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (rules) {
          final filtered = rules.where((r) {
            if (_selectedFilter == 'All') return true;
            if (_selectedFilter == 'Debits') return r.isDebit;
            if (_selectedFilter == 'Income') return r.isCredit;
            return r.type.toLowerCase() == _selectedFilter.toLowerCase();
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Monthly Commitments & Income Summary Card
              _buildOverviewCard(
                monthlyDeductions: monthlyDeductions,
                monthlyIncome: monthlyIncome,
                netCashFlow: netCashFlow,
                activeCount: rules.where((r) => r.isActive).length,
                lowBalanceCount: lowBalanceAlertCount,
              ),
              const SizedBox(height: 16),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Debits', 'Income', 'Salary', 'SIP', 'Loan EMI', 'Rent'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter == 'Debits' ? 'Auto-Debits' : (filter == 'Income' ? 'Auto-Income' : filter)),
                        selected: isSel,
                        selectedColor: filter == 'Income'
                            ? AppColors.income.withValues(alpha: 0.2)
                            : (filter == 'Debits' ? AppColors.expense.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2)),
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
                          'No Recurring Rules Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set your monthly salary, tenant rent, SIP investments, and loan EMIs once. They will automatically credit or deduct on their scheduled day.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Rule'),
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

  Widget _buildOverviewCard({
    required double monthlyDeductions,
    required double monthlyIncome,
    required double netCashFlow,
    required int activeCount,
    required int lowBalanceCount,
  }) {
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
                'MONTHLY SCHEDULED SUMMARY',
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
          const SizedBox(height: 14),

          // Inflow vs Outflow Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF4ADE80)),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-Income',
                          style: TextStyle(color: Colors.green.shade200, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(monthlyIncome),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-Debits',
                          style: TextStyle(color: Colors.red.shade200, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(monthlyDeductions),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),

          // Net flow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Monthly Cash Flow:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${netCashFlow >= 0 ? '+' : ''}${AppFormatters.currency(netCashFlow)}',
                style: TextStyle(
                  color: netCashFlow >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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
    final isLowBalance = rule.isDebit && liveBalance < rule.amount;
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
                  backgroundColor: _getTypeColor(rule.type, rule.isCredit).withValues(alpha: 0.15),
                  child: Icon(
                    _getTypeIcon(rule.type, rule.isCredit),
                    color: _getTypeColor(rule.type, rule.isCredit),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (rule.isCredit ? AppColors.income : AppColors.expense).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rule.isCredit ? 'INCOME' : 'DEBIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: rule.isCredit ? AppColors.income : AppColors.expense,
                              ),
                            ),
                          ),
                        ],
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
                  activeThumbColor: rule.isCredit ? AppColors.income : AppColors.primary,
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
                    PopupMenuItem(
                      value: 'process',
                      child: Text(rule.isCredit ? 'Credit This Income Now' : 'Process / Retry Debit Now'),
                    ),
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
                  '${rule.isCredit ? '+' : ''}${AppFormatters.currency(rule.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: rule.isCredit ? AppColors.income : AppColors.textPrimary,
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
                        color: rule.isDue ? (rule.isCredit ? AppColors.income : AppColors.primary) : AppColors.textSecondary,
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
                    child: const Text('PAUSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  )
                else if (isFailed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('LOW BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                  )
                else if (rule.lastStatus == 'SUCCESS')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rule.isCredit ? 'CREDITED' : 'ACTIVE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ),
              ],
            ),

            if (rule.lastStatusMessage != null && rule.lastStatusMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rule.lastStatusMessage!,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isFailed ? Colors.red.shade700 : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type, bool isCredit) {
    if (isCredit) {
      switch (type.toLowerCase()) {
        case 'salary':
          return Icons.work_outline_rounded;
        case 'rental income':
          return Icons.real_estate_agent_outlined;
        case 'pension':
          return Icons.elderly_rounded;
        case 'interest / dividend':
        case 'interest':
        case 'dividend':
          return Icons.account_balance_wallet_outlined;
        case 'business / freelance':
        case 'freelance':
        case 'business':
          return Icons.store_rounded;
        default:
          return Icons.paid_outlined;
      }
    }
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

  Color _getTypeColor(String type, bool isCredit) {
    if (isCredit) return AppColors.income;
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
        content: Text(
          'Are you sure you want to delete this ${rule.isCredit ? 'auto-income' : 'auto-debit'} rule? Past recorded transactions will not be removed.',
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
                  SnackBar(content: Text('${rule.isCredit ? 'Auto-income' : 'Auto-debit'} rule deleted')),
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
            Text('Smart Recurring Engine'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Auto-Income (Credits):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Set your monthly salary, tenant rent, and dividends once. On the scheduled date, it automatically credits into your bank account.\n',
              style: TextStyle(fontSize: 13),
            ),
            Text(
              '2. Auto-Debits (Deductions):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your SIP investments, EMIs, and bills auto-deduct only if the account has enough balance, so your balance is never negative.\n',
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
