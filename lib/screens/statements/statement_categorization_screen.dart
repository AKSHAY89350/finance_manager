import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/statement_transaction.dart';
import '../../db/database_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/financial_health_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class StatementCategorizationScreen extends ConsumerStatefulWidget {
  final List<StatementTransaction> approvedTransactions;
  final String selectedBank;

  const StatementCategorizationScreen({
    super.key,
    required this.approvedTransactions,
    required this.selectedBank,
  });

  @override
  ConsumerState<StatementCategorizationScreen> createState() =>
      _StatementCategorizationScreenState();
}

class _StatementCategorizationScreenState
    extends ConsumerState<StatementCategorizationScreen> {
  late List<StatementTransaction> _transactions;
  late String _targetBank;
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _transactions = widget.approvedTransactions;

    // Default target bank
    const availableBanks = AppConstants.defaultBanks;
    final match = availableBanks.firstWhere(
      (b) => widget.selectedBank.toLowerCase().contains(b.toLowerCase()),
      orElse: () => availableBanks.first,
    );
    _targetBank = match;
  }

  Future<void> _commitToLedger() async {
    setState(() => _isCommitting = true);

    int expensesAdded = 0;
    int incomeAdded = 0;
    double totalDebitAmt = 0;
    double totalCreditAmt = 0;

    final db = DatabaseHelper.instance;

    try {
      for (final txn in _transactions) {
        if (txn.isCredit) {
          // Income entry
          String mode = 'Salary';
          if (AppConstants.incomeModes.contains(txn.selectedSubCategory)) {
            mode = txn.selectedSubCategory!;
          } else if (txn.selectedCategory == 'Income' &&
              txn.selectedSubCategory != null) {
            mode = txn.selectedSubCategory!;
          } else {
            mode = 'Other';
          }

          await db.insertIncome({
            'date': txn.isoDate,
            'user_name': txn.cleanDescription,
            'amount': txn.amount,
            'mode': mode,
            'bank': _targetBank,
          });

          incomeAdded++;
          totalCreditAmt += txn.amount;
        } else {
          // Expense entry
          await db.insertExpense({
            'date': txn.isoDate,
            'category': txn.selectedCategory,
            'sub_category': txn.selectedSubCategory,
            'description': txn.cleanDescription,
            'amount': txn.amount,
            'bank': _targetBank,
          });

          expensesAdded++;
          totalDebitAmt += txn.amount;
        }
      }

      // Refresh Riverpod state
      ref.invalidate(expenseProvider);
      ref.invalidate(incomeProvider);
      ref.invalidate(bankProvider);
      ref.invalidate(financialHealthProvider);
      ref.invalidate(currentHealthReportProvider);

      if (!mounted) return;
      setState(() => _isCommitting = false);

      // Show Success Dialog
      _showSuccessDialog(expensesAdded, incomeAdded, totalDebitAmt, totalCreditAmt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCommitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to commit records: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog(
      int expCount, int incCount, double debitAmt, double creditAmt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Statement Committed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully added ${_transactions.length} verified transactions to your official ledger under $_targetBank.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expenses Recorded ($expCount):', style: const TextStyle(fontSize: 12)),
                        Text(
                          AppFormatters.currency(debitAmt),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Income Records Added ($incCount):', style: const TextStyle(fontSize: 12)),
                        Text(
                          AppFormatters.currency(creditAmt),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Expenses tab, Transaction History, and 50-30-20 Gauge Meter have been automatically updated.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Return to main app root
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Go to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = AppConstants.categories;
    const availableBanks = AppConstants.defaultBanks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Categories & Account'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Auto-Categorization Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.primaryColor.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ Smart Auto-Categorization Applied',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.primaryColor),
                      ),
                      Text(
                        'Categories & 50-30-20 tags pre-filled based on merchant keywords.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Target Bank Selector Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 22, color: Colors.blueGrey),
                const SizedBox(width: 10),
                const Text(
                  'Target Account:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _targetBank,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(10),
                  items: availableBanks.map((b) {
                    return DropdownMenuItem<String>(
                      value: b,
                      child: Text(
                        b,
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _targetBank = val);
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. Transactions Categorization List
          Expanded(
            child: ListView.builder(
              itemCount: _transactions.length,
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 90),
              itemBuilder: (context, index) {
                final txn = _transactions[index];
                return _buildCategorizationCard(txn, categories, theme, isDark);
              },
            ),
          ),
        ],
      ),

      // 4. Bottom Commit Button
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isCommitting ? null : _commitToLedger,
              child: _isCommitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Saving to Official Ledger...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'Confirm & Move to Ledger (${_transactions.length}) ➔',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorizationCard(
    StatementTransaction txn,
    List<String> categories,
    ThemeData theme,
    bool isDark,
  ) {
    final isCredit = txn.isCredit;
    final subCategories = AppConstants.categorySubMap[txn.selectedCategory] ?? ['Other'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Description & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.cleanDescription,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${txn.formattedDate} • ${txn.narration}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? "+" : "-"} ${AppFormatters.currency(txn.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dropdowns Row
            Row(
              children: [
                // Category Dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: categories.contains(txn.selectedCategory) ? txn.selectedCategory : 'Other',
                        items: categories.map((cat) {
                          final icon = AppConstants.categoryIcons[cat] ?? '🔹';
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(
                              '$icon $cat',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newCat) {
                          if (newCat != null) {
                            setState(() {
                              txn.selectedCategory = newCat;
                              final newSubs = AppConstants.categorySubMap[newCat];
                              txn.selectedSubCategory = (newSubs != null && newSubs.isNotEmpty) ? newSubs.first : 'Other';

                              // Update 50-30-20 bucket automatically based on category
                              if (isCredit) {
                                txn.selectedBucket = 'Income';
                              } else if (newCat == 'SIP & Investments') {
                                txn.selectedBucket = 'Savings';
                              } else if (['Shopping', 'Entertainment'].contains(newCat)) {
                                txn.selectedBucket = 'Wants';
                              } else {
                                txn.selectedBucket = 'Needs';
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Sub-Category Dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: subCategories.contains(txn.selectedSubCategory)
                            ? txn.selectedSubCategory
                            : subCategories.first,
                        items: subCategories.map((sub) {
                          return DropdownMenuItem<String>(
                            value: sub,
                            child: Text(
                              sub,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newSub) {
                          if (newSub != null) {
                            setState(() => txn.selectedSubCategory = newSub);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 50-30-20 Bucket Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getBucketColor(txn.selectedBucket).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _getBucketColor(txn.selectedBucket), width: 1),
                  ),
                  child: Text(
                    txn.selectedBucket,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getBucketColor(txn.selectedBucket),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Status: Ready to commit',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBucketColor(String bucket) {
    switch (bucket) {
      case 'Needs':
        return Colors.blue.shade600;
      case 'Wants':
        return Colors.orange.shade700;
      case 'Savings':
        return Colors.purple.shade600;
      case 'Income':
      default:
        return Colors.green.shade600;
    }
  }
}
