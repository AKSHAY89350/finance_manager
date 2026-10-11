import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/bank_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../expense/add_expense_screen.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  Future<bool?> _confirmDelete(BuildContext context, String itemType) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $itemType?'),
        content: Text('Are you sure you want to delete this $itemType record? This will also update bank balances.'),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseState = ref.watch(expenseProvider);
    final incomeState = ref.watch(incomeProvider);
    final transferState = ref.watch(transferProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Transactions Ledger'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.arrow_downward_rounded, size: 18), text: 'Expenses'),
              Tab(icon: Icon(Icons.arrow_upward_rounded, size: 18), text: 'Income'),
              Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Transfers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Expenses ──────────────────────────────────────
            expenseState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading expenses: $err')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text('No expenses recorded yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Dismissible(
                      key: Key('expense_${expense.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, 'expense'),
                      background: Container(
                        color: AppColors.expense,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
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
                                Text(expense.description!, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(expense.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
              },
            ),

            // ── Tab 2: Income / Extra Credit ─────────────────────────
            incomeState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading income: $err')),
              data: (incomes) {
                if (incomes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.savings_outlined, size: 64, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text('No income records yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: incomes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final income = incomes[index];
                    return Dismissible(
                      key: Key('income_${income.id}'),
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
                                Text(income.userName!, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(income.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
              },
            ),

            // ── Tab 3: Bank Transfers ────────────────────────────────
            transferState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading transfers: $err')),
              data: (transfers) {
                if (transfers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 64, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text('No transfers recorded yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final transfer = transfers[index];
                    return Dismissible(
                      key: Key('transfer_${transfer.id}'),
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
                                Text(transfer.description!, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(transfer.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
