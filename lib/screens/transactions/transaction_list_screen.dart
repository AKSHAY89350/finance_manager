import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense.dart';
import '../../models/extra_credit.dart';
import '../../models/transfer.dart';
import '../../models/transaction_filter.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/pending_provider.dart';
import '../../providers/transaction_filter_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../expense/add_expense_screen.dart';
import 'review_inbox_screen.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  final String? initialBankFilter;

  const TransactionListScreen({super.key, this.initialBankFilter});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialBankFilter != null && widget.initialBankFilter!.isNotEmpty) {
        ref.read(transactionFilterProvider.notifier).setBank(widget.initialBankFilter);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool?> _confirmDelete(BuildContext context, String itemType) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $itemType?'),
        content: Text(
          'Are you sure you want to delete this $itemType record? This will automatically update your bank balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final summary = ref.watch(transactionSummaryProvider);
    final pendingCount = ref.watch(pendingCountProvider);

    final filteredAll = ref.watch(filteredUnifiedTransactionsProvider);
    final filteredExpenses = ref.watch(filteredExpensesProvider);
    final filteredIncome = ref.watch(filteredIncomeProvider);
    final filteredTransfers = ref.watch(filteredTransfersProvider);

    final expenseState = ref.watch(expenseProvider);
    final incomeState = ref.watch(incomeProvider);
    final transferState = ref.watch(transferProvider);

    final isLoading = expenseState.isLoading || incomeState.isLoading || transferState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search merchant, note, amount...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(transactionFilterProvider.notifier).setSearchQuery('');
                      setState(() => _showSearch = false);
                    },
                  ),
                ),
                onChanged: (val) {
                  ref.read(transactionFilterProvider.notifier).setSearchQuery(val);
                },
              )
            : const Text('Transactions Ledger'),
        actions: [
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search transactions',
              onPressed: () => setState(() => _showSearch = true),
            ),
          // Filter button with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Advanced Filters',
                onPressed: () => _showFilterBottomSheet(context),
              ),
              if (filter.isFiltered)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.income,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${filter.activeFilterCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Review Inbox Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox_outlined),
                tooltip: 'Review Inbox (On-Time SMS)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewInboxScreen()),
                  );
                },
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.all_inclusive_rounded, size: 18), text: 'All'),
            Tab(icon: Icon(Icons.arrow_downward_rounded, size: 18), text: 'Expenses'),
            Tab(icon: Icon(Icons.arrow_upward_rounded, size: 18), text: 'Income'),
            Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Transfers'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Horizontal Quick Filter Chips ──────────────────────────
          _buildQuickFilterBar(context, filter),

          // ── Filter Result Summary Bar ──────────────────────────────
          _buildSummaryBar(summary, filter),

          // ── Tab Bar Views ──────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 0: All Unified Transactions
                      _buildUnifiedList(context, filteredAll, filter),

                      // Tab 1: Expenses
                      _buildExpensesList(context, filteredExpenses, filter),

                      // Tab 2: Income
                      _buildIncomeList(context, filteredIncome, filter),

                      // Tab 3: Transfers
                      _buildTransfersList(context, filteredTransfers, filter),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Quick Filter Chips ─────────────────────────────────────────────
  Widget _buildQuickFilterBar(BuildContext context, TransactionFilter filter) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Date / Month Chip
            _FilterActionChip(
              icon: Icons.calendar_today_rounded,
              label: filter.getDateLabel(),
              isActive: filter.datePreset != DateFilterPreset.allTime,
              onTap: () => _showDateFilterDialog(context),
              onClear: filter.datePreset != DateFilterPreset.allTime
                  ? () => ref.read(transactionFilterProvider.notifier).resetDate()
                  : null,
            ),
            const SizedBox(width: 8),

            // Bank Chip
            _FilterActionChip(
              icon: Icons.account_balance_rounded,
              label: filter.bank ?? 'All Banks',
              isActive: filter.bank != null,
              onTap: () => _showBankPickerDialog(context),
              onClear: filter.bank != null
                  ? () => ref.read(transactionFilterProvider.notifier).resetBank()
                  : null,
            ),
            const SizedBox(width: 8),

            // Category Chip
            _FilterActionChip(
              icon: Icons.category_rounded,
              label: filter.category ?? 'All Categories',
              isActive: filter.category != null,
              onTap: () => _showCategoryPickerDialog(context),
              onClear: filter.category != null
                  ? () => ref.read(transactionFilterProvider.notifier).resetCategory()
                  : null,
            ),
            const SizedBox(width: 8),

            // Sort Chip
            _FilterActionChip(
              icon: Icons.sort_rounded,
              label: _getSortLabel(filter.sortOption),
              isActive: filter.sortOption != TransactionSortOption.dateDesc,
              onTap: () => _showSortPickerDialog(context),
            ),

            // Reset All Button (visible only when filters active)
            if (filter.isFiltered) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _searchController.clear();
                  ref.read(transactionFilterProvider.notifier).resetFilters();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 14, color: AppColors.expense),
                      const SizedBox(width: 4),
                      Text(
                        'Clear (${filter.activeFilterCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Summary Bar ────────────────────────────────────────────────────
  Widget _buildSummaryBar(TransactionSummary summary, TransactionFilter filter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '${summary.totalCount} records',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              if (filter.isFiltered) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Filtered',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                if (summary.totalIncome > 0) ...[
                  Text(
                    '+${AppFormatters.currency(summary.totalIncome)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (summary.totalExpense > 0)
                  Text(
                    '-${AppFormatters.currency(summary.totalExpense)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Unified List ────────────────────────────────────────────
  Widget _buildUnifiedList(
    BuildContext context,
    List<UnifiedTransaction> items,
    TransactionFilter filter,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        message: filter.isFiltered
            ? 'No transactions match your active filters'
            : 'No transactions recorded yet',
        isFiltered: filter.isFiltered,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final item = items[index];

        return Dismissible(
          key: ValueKey('unified_${item.kind.name}_${item.id ?? item.hashCode}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context, item.kind.name),
          background: Container(
            color: AppColors.expense,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            if (item.id != null) {
              if (item.kind == TransactionKind.expense) {
                await ref.read(expenseProvider.notifier).deleteExpense(item.id!);
              } else if (item.kind == TransactionKind.income) {
                await ref.read(incomeProvider.notifier).deleteIncome(item.id!);
              } else if (item.kind == TransactionKind.transfer) {
                await ref.read(transferProvider.notifier).deleteTransfer(item.id!);
              }
              await ref.read(bankProvider.notifier).loadBanks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.kind.name.toUpperCase()} deleted')),
                );
              }
            }
          },
          child: Card(
            child: ListTile(
              onTap: () {
                if (item.kind == TransactionKind.expense && item.originalExpense != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(initialExpense: item.originalExpense),
                    ),
                  );
                }
              },
              leading: _buildLeadingAvatar(item),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatAmountWithSign(item),
                    style: TextStyle(
                      color: _getAmountColor(item),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Text(
                      item.subtitle!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.date,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.forBank(item.bank).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.bank,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forBank(item.bank),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab 1: Expenses List ───────────────────────────────────────────
  Widget _buildExpensesList(
    BuildContext context,
    List<Expense> expenses,
    TransactionFilter filter,
  ) {
    if (expenses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        message: filter.isFiltered
            ? 'No expenses match your active filters'
            : 'No expenses recorded yet',
        isFiltered: filter.isFiltered,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return Dismissible(
          key: ValueKey('expense_${expense.id ?? expense.hashCode}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context, 'expense'),
          background: Container(
            color: AppColors.expense,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            if (expense.id != null) {
              await ref.read(expenseProvider.notifier).deleteExpense(expense.id!);
              await ref.read(bankProvider.notifier).loadBanks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
              }
            }
          },
          child: Card(
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(initialExpense: expense),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.forCategory(expense.category).withValues(alpha: 0.15),
                child: Text(
                  expense.category.isNotEmpty ? expense.category[0] : '₹',
                  style: TextStyle(
                    color: AppColors.forCategory(expense.category),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      expense.subCategory ?? expense.category,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '-${AppFormatters.currency(expense.amount)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (expense.description != null && expense.description!.isNotEmpty)
                    Text(expense.description!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(expense.date,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.forBank(expense.bank).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          expense.bank,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forBank(expense.bank),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab 2: Income List ─────────────────────────────────────────────
  Widget _buildIncomeList(
    BuildContext context,
    List<ExtraCredit> incomes,
    TransactionFilter filter,
  ) {
    if (incomes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.savings_outlined,
        message: filter.isFiltered
            ? 'No income records match your active filters'
            : 'No income records yet',
        isFiltered: filter.isFiltered,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: incomes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final income = incomes[index];
        return Dismissible(
          key: ValueKey('income_${income.id ?? income.hashCode}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context, 'income'),
          background: Container(
            color: AppColors.expense,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            if (income.id != null) {
              await ref.read(incomeProvider.notifier).deleteIncome(income.id!);
              await ref.read(bankProvider.notifier).loadBanks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Income record deleted')),
                );
              }
            }
          },
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.income.withValues(alpha: 0.15),
                child: const Icon(Icons.arrow_upward_rounded, color: AppColors.income),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      income.mode,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '+${AppFormatters.currency(income.amount)}',
                    style: const TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (income.userName != null && income.userName!.isNotEmpty)
                    Text(income.userName!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(income.date,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.forBank(income.bank).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          income.bank,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forBank(income.bank),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: Transfers List ──────────────────────────────────────────
  Widget _buildTransfersList(
    BuildContext context,
    List<Transfer> transfers,
    TransactionFilter filter,
  ) {
    if (transfers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.swap_horiz_rounded,
        message: filter.isFiltered
            ? 'No transfers match your active filters'
            : 'No transfers recorded yet',
        isFiltered: filter.isFiltered,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transfers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return Dismissible(
          key: ValueKey('transfer_${transfer.id ?? transfer.hashCode}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context, 'transfer'),
          background: Container(
            color: AppColors.expense,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            if (transfer.id != null) {
              await ref.read(transferProvider.notifier).deleteTransfer(transfer.id!);
              await ref.read(bankProvider.notifier).loadBanks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transfer deleted')),
                );
              }
            }
          },
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.transfer.withValues(alpha: 0.15),
                child: const Icon(Icons.swap_horiz_rounded, color: AppColors.transfer),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${transfer.fromBank} ➔ ${transfer.toBank}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    AppFormatters.currency(transfer.amount),
                    style: const TextStyle(
                      color: AppColors.transfer,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (transfer.description != null && transfer.description!.isNotEmpty)
                    Text(transfer.description!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(transfer.date,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helper Widgets & Dialogs ───────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required bool isFiltered,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ref.read(transactionFilterProvider.notifier).resetFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Reset All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingAvatar(UnifiedTransaction item) {
    if (item.kind == TransactionKind.expense) {
      final cat = item.category ?? '';
      return CircleAvatar(
        backgroundColor: AppColors.forCategory(cat).withValues(alpha: 0.15),
        child: Text(
          cat.isNotEmpty ? cat[0] : '₹',
          style: TextStyle(
            color: AppColors.forCategory(cat),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (item.kind == TransactionKind.income) {
      return CircleAvatar(
        backgroundColor: AppColors.income.withValues(alpha: 0.15),
        child: const Icon(Icons.arrow_upward_rounded, color: AppColors.income),
      );
    } else {
      return CircleAvatar(
        backgroundColor: AppColors.transfer.withValues(alpha: 0.15),
        child: const Icon(Icons.swap_horiz_rounded, color: AppColors.transfer),
      );
    }
  }

  String _formatAmountWithSign(UnifiedTransaction item) {
    if (item.kind == TransactionKind.expense) {
      return '-${AppFormatters.currency(item.amount)}';
    } else if (item.kind == TransactionKind.income) {
      return '+${AppFormatters.currency(item.amount)}';
    } else {
      return AppFormatters.currency(item.amount);
    }
  }

  Color _getAmountColor(UnifiedTransaction item) {
    if (item.kind == TransactionKind.expense) {
      return AppColors.expense;
    } else if (item.kind == TransactionKind.income) {
      return AppColors.income;
    } else {
      return AppColors.transfer;
    }
  }

  String _getSortLabel(TransactionSortOption opt) {
    switch (opt) {
      case TransactionSortOption.dateDesc:
        return 'Newest First';
      case TransactionSortOption.dateAsc:
        return 'Oldest First';
      case TransactionSortOption.amountDesc:
        return 'Amount High-Low';
      case TransactionSortOption.amountAsc:
        return 'Amount Low-High';
    }
  }

  // ── Dialogs & Pickers ──────────────────────────────────────────────
  void _showDateFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Date & Month',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('All Time'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setDatePreset(DateFilterPreset.allTime);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('This Month'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setDatePreset(DateFilterPreset.thisMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Last Month'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setDatePreset(DateFilterPreset.lastMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: const Text('Last 30 Days'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setDatePreset(DateFilterPreset.last30Days);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Pick Specific Month & Year'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMonthYearPicker(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('Custom Date Range'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      ref.read(transactionFilterProvider.notifier).setCustomDateRange(picked.start, picked.end);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    int curMonth = DateTime.now().month;
    int curYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month & Year'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Year: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: curYear,
                        items: List.generate(10, (i) => DateTime.now().year - 4 + i).map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => curYear = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Month:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final m = index + 1;
                      final isSelected = curMonth == m;
                      return ChoiceChip(
                        label: Text(AppConstants.shortMonthNames[index]),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() => curMonth = m);
                          }
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(transactionFilterProvider.notifier).setSpecificMonth(curMonth, curYear);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBankPickerDialog(BuildContext context) {
    final bankState = ref.read(bankProvider);
    final banks = bankState.maybeWhen(
      data: (list) => list.map((b) => b.bank.name).toList(),
      orElse: () => AppConstants.defaultBanks,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter by Bank Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('All Banks'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).resetBank();
                    Navigator.pop(ctx);
                  },
                ),
                ...banks.map((b) => ListTile(
                      leading: Icon(Icons.account_balance_rounded, color: AppColors.forBank(b)),
                      title: Text(b),
                      onTap: () {
                        ref.read(transactionFilterProvider.notifier).setBank(b);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPickerDialog(BuildContext context) {
    final categories = AppConstants.categorySubMap.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.clear_all),
                            title: const Text('All Categories'),
                            onTap: () {
                              ref.read(transactionFilterProvider.notifier).resetCategory();
                              Navigator.pop(ctx);
                            },
                          ),
                          ...categories.map((c) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.forCategory(c).withValues(alpha: 0.15),
                                  child: Text(
                                    c[0],
                                    style: TextStyle(
                                      color: AppColors.forCategory(c),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(c),
                                onTap: () {
                                  ref.read(transactionFilterProvider.notifier).setCategory(c);
                                  Navigator.pop(ctx);
                                },
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sort Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.arrow_downward),
                  title: const Text('Newest First (Default)'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setSortOption(TransactionSortOption.dateDesc);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text('Oldest First'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setSortOption(TransactionSortOption.dateAsc);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_down),
                  title: const Text('Amount: High to Low'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setSortOption(TransactionSortOption.amountDesc);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up),
                  title: const Text('Amount: Low to High'),
                  onTap: () {
                    ref.read(transactionFilterProvider.notifier).setSortOption(TransactionSortOption.amountAsc);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Consumer(
              builder: (context, refConsumer, _) {
                final currentFilter = refConsumer.watch(transactionFilterProvider);
                final bankState = refConsumer.watch(bankProvider);
                final banks = bankState.maybeWhen(
                  data: (list) => list.map((b) => b.bank.name).toList(),
                  orElse: () => AppConstants.defaultBanks,
                );
                final categories = AppConstants.categorySubMap.keys.toList();

                return Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: AppColors.textPrimary),
                    title: const Text(
                      'All Filters',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          refConsumer.read(transactionFilterProvider.notifier).resetFilters();
                        },
                        child: const Text('Reset All', style: TextStyle(color: AppColors.expense)),
                      ),
                    ],
                  ),
                  body: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // Date / Period Section
                      const Text('Period & Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All Time'),
                            selected: currentFilter.datePreset == DateFilterPreset.allTime,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setDatePreset(DateFilterPreset.allTime),
                          ),
                          ChoiceChip(
                            label: const Text('This Month'),
                            selected: currentFilter.datePreset == DateFilterPreset.thisMonth,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setDatePreset(DateFilterPreset.thisMonth),
                          ),
                          ChoiceChip(
                            label: const Text('Last Month'),
                            selected: currentFilter.datePreset == DateFilterPreset.lastMonth,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setDatePreset(DateFilterPreset.lastMonth),
                          ),
                          ChoiceChip(
                            label: const Text('Last 30 Days'),
                            selected: currentFilter.datePreset == DateFilterPreset.last30Days,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setDatePreset(DateFilterPreset.last30Days),
                          ),
                          ChoiceChip(
                            label: const Text('This Year'),
                            selected: currentFilter.datePreset == DateFilterPreset.thisYear,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setDatePreset(DateFilterPreset.thisYear),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_month, size: 16),
                            label: Text(currentFilter.datePreset == DateFilterPreset.specificMonth
                                ? currentFilter.getDateLabel()
                                : 'Select Month...'),
                            onPressed: () => _showMonthYearPicker(context),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.date_range, size: 16),
                            label: Text(currentFilter.datePreset == DateFilterPreset.customRange
                                ? currentFilter.getDateLabel()
                                : 'Custom Date Range...'),
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                refConsumer
                                    .read(transactionFilterProvider.notifier)
                                    .setCustomDateRange(picked.start, picked.end);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bank Section
                      const Text('Bank Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All Banks'),
                            selected: currentFilter.bank == null,
                            onSelected: (_) =>
                                refConsumer.read(transactionFilterProvider.notifier).resetBank(),
                          ),
                          ...banks.map((b) => ChoiceChip(
                                label: Text(b),
                                selected: currentFilter.bank?.toLowerCase() == b.toLowerCase(),
                                onSelected: (sel) {
                                  refConsumer
                                      .read(transactionFilterProvider.notifier)
                                      .setBank(sel ? b : null);
                                },
                              )),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Category Section
                      const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All Categories'),
                            selected: currentFilter.category == null,
                            onSelected: (_) =>
                                refConsumer.read(transactionFilterProvider.notifier).resetCategory(),
                          ),
                          ...categories.map((c) => ChoiceChip(
                                label: Text(c),
                                selected: currentFilter.category?.toLowerCase() == c.toLowerCase(),
                                onSelected: (sel) {
                                  refConsumer
                                      .read(transactionFilterProvider.notifier)
                                      .setCategory(sel ? c : null);
                                },
                              )),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sort Section
                      const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Newest First'),
                            selected: currentFilter.sortOption == TransactionSortOption.dateDesc,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setSortOption(TransactionSortOption.dateDesc),
                          ),
                          ChoiceChip(
                            label: const Text('Oldest First'),
                            selected: currentFilter.sortOption == TransactionSortOption.dateAsc,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setSortOption(TransactionSortOption.dateAsc),
                          ),
                          ChoiceChip(
                            label: const Text('Amount: High to Low'),
                            selected: currentFilter.sortOption == TransactionSortOption.amountDesc,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setSortOption(TransactionSortOption.amountDesc),
                          ),
                          ChoiceChip(
                            label: const Text('Amount: Low to High'),
                            selected: currentFilter.sortOption == TransactionSortOption.amountAsc,
                            onSelected: (_) => refConsumer
                                .read(transactionFilterProvider.notifier)
                                .setSortOption(TransactionSortOption.amountAsc),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Apply button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Show Results (${refConsumer.watch(transactionSummaryProvider).totalCount})',
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
}

// ── Private Reusable Filter Action Chip ──────────────────────────────
class _FilterActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterActionChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
