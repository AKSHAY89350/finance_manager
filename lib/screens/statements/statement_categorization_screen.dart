import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/statement_transaction.dart';
import '../../db/database_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/financial_health_provider.dart';
import '../../utils/app_colors.dart';
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
    final availableBanks = AppConstants.defaultBanks;
    final match = availableBanks.firstWhere(
      (b) => widget.selectedBank.toLowerCase().contains(b.toLowerCase()) ||
          b.toLowerCase().contains(widget.selectedBank.toLowerCase()),
      orElse: () => widget.selectedBank.isNotEmpty && widget.selectedBank != 'Auto-Detect'
          ? widget.selectedBank
          : availableBanks.first,
    );
    _targetBank = match;
  }

  Future<void> _commitToLedger() async {
    setState(() => _isCommitting = true);

    int expensesAdded = 0;
    int incomeAdded = 0;
    int transfersAdded = 0;
    double totalDebitAmt = 0;
    double totalCreditAmt = 0;
    double totalTransferAmt = 0;

    final db = DatabaseHelper.instance;

    try {
      final database = await db.database;

      // Execute all inserts atomically within a single SQLite transaction
      await database.transaction((txnDb) async {
        for (final txn in _transactions) {
          if (txn.isTransfer) {
            // Internal Transfer between user's own accounts
            final otherBank = txn.transferOtherBank ?? 'Cash';
            final fromBank = txn.isCredit ? otherBank : _targetBank;
            final toBank = txn.isCredit ? _targetBank : otherBank;

            await txnDb.insert(
              AppConstants.tableTransfers,
              {
                'date': txn.isoDate,
                'from_bank': fromBank,
                'to_bank': toBank,
                'amount': txn.amount,
                'description': txn.cleanDescription.isNotEmpty
                    ? txn.cleanDescription
                    : 'Self Transfer ($fromBank ➔ $toBank)',
              },
            );

            transfersAdded++;
            totalTransferAmt += txn.amount;
          } else if (txn.isCredit) {
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

            await txnDb.insert(
              AppConstants.tableExtraCredit,
              {
                'date': txn.isoDate,
                'user_name': txn.cleanDescription,
                'amount': txn.amount,
                'mode': mode,
                'bank': _targetBank,
              },
            );

            incomeAdded++;
            totalCreditAmt += txn.amount;
          } else {
            // Expense entry
            await txnDb.insert(
              AppConstants.tableExpenses,
              {
                'date': txn.isoDate,
                'category': txn.selectedCategory,
                'sub_category': txn.selectedSubCategory,
                'description': txn.cleanDescription,
                'amount': txn.amount,
                'bank': _targetBank,
              },
            );

            expensesAdded++;
            totalDebitAmt += txn.amount;
          }
        }
      });

      // Refresh Riverpod state
      ref.invalidate(expenseProvider);
      ref.invalidate(incomeProvider);
      ref.invalidate(transferProvider);
      ref.invalidate(bankProvider);
      ref.invalidate(financialHealthProvider);
      ref.invalidate(currentHealthReportProvider);

      if (!mounted) return;
      setState(() => _isCommitting = false);

      // Show Success Dialog
      _showSuccessDialog(
        expensesAdded,
        incomeAdded,
        transfersAdded,
        totalDebitAmt,
        totalCreditAmt,
        totalTransferAmt,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCommitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to commit records: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog(
    int expCount,
    int incCount,
    int transferCount,
    double debitAmt,
    double creditAmt,
    double transferAmt,
  ) {
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
                    if (expCount > 0)
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
                    if (incCount > 0) ...[
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
                    if (transferCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Internal Transfers ($transferCount):', style: const TextStyle(fontSize: 12)),
                          Text(
                            AppFormatters.currency(transferAmt),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.transfer),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Internal transfers adjust individual account balances without changing your total income or expenses.',
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

    // Dynamically retrieve all registered bank accounts plus defaults
    final bankListState = ref.watch(bankProvider);
    final Set<String> allBanks = Set.from(AppConstants.defaultBanks);
    if (bankListState.hasValue && bankListState.value != null) {
      for (final b in bankListState.value!) {
        allBanks.add(b.bank.name);
      }
    }
    allBanks.add(_targetBank);
    final availableBanks = allBanks.toList();

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
                return _buildCategorizationCard(txn, categories, availableBanks, theme, isDark);
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
    List<String> availableBanks,
    ThemeData theme,
    bool isDark,
  ) {
    final isCredit = txn.isCredit;

    // Accounts available for self transfer (excluding the statement bank itself)
    final otherBanks = availableBanks.where((b) => b != _targetBank).toList();
    if (otherBanks.isEmpty) {
      otherBanks.addAll(['Cash', 'Other Bank']);
    }
    if (txn.transferOtherBank == null || !otherBanks.contains(txn.transferOtherBank)) {
      txn.transferOtherBank = otherBanks.first;
    }

    final allCategories = ['Internal Transfer', ...categories];
    final subCategories = AppConstants.categorySubMap[txn.selectedCategory] ?? ['Other'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: txn.isTransfer
              ? AppColors.transfer
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: txn.isTransfer ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Description, Self-Transfer Quick Toggle, & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              txn.cleanDescription,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Quick Self-Transfer Toggle Chip
                          InkWell(
                            onTap: () {
                              setState(() {
                                txn.isTransfer = !txn.isTransfer;
                                if (txn.isTransfer) {
                                  txn.selectedCategory = 'Internal Transfer';
                                  txn.selectedBucket = 'Transfer';
                                  txn.transferOtherBank ??= otherBanks.first;
                                } else {
                                  txn.selectedCategory = 'Other';
                                  txn.selectedSubCategory = 'Other';
                                  txn.selectedBucket = isCredit ? 'Income' : 'Needs';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: txn.isTransfer
                                    ? AppColors.transfer.withValues(alpha: 0.18)
                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: txn.isTransfer ? AppColors.transfer : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 13,
                                    color: txn.isTransfer ? AppColors.transfer : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Self Transfer',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: txn.isTransfer ? FontWeight.bold : FontWeight.w500,
                                      color: txn.isTransfer ? AppColors.transfer : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(width: 8),
                Text(
                  txn.isTransfer
                      ? '🔄 ${AppFormatters.currency(txn.amount)}'
                      : '${isCredit ? "+" : "-"} ${AppFormatters.currency(txn.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: txn.isTransfer
                        ? AppColors.transfer
                        : (isCredit ? Colors.green : Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dropdowns Row: Category Dropdown & (Sub-Category OR Other Account Dropdown)
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
                      border: Border.all(
                        color: txn.isTransfer ? AppColors.transfer : Colors.grey.shade400,
                        width: txn.isTransfer ? 1.2 : 0.8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: allCategories.contains(txn.selectedCategory)
                            ? txn.selectedCategory
                            : (txn.isTransfer ? 'Internal Transfer' : 'Other'),
                        items: allCategories.map((cat) {
                          final icon = cat == 'Internal Transfer'
                              ? '🔄'
                              : (AppConstants.categoryIcons[cat] ?? '🔹');
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(
                              '$icon $cat',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: cat == 'Internal Transfer'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: cat == 'Internal Transfer'
                                    ? AppColors.transfer
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newCat) {
                          if (newCat != null) {
                            setState(() {
                              txn.selectedCategory = newCat;
                              if (newCat == 'Internal Transfer') {
                                txn.isTransfer = true;
                                txn.selectedBucket = 'Transfer';
                                txn.transferOtherBank ??= otherBanks.first;
                              } else {
                                txn.isTransfer = false;
                                final newSubs = AppConstants.categorySubMap[newCat];
                                txn.selectedSubCategory =
                                    (newSubs != null && newSubs.isNotEmpty) ? newSubs.first : 'Other';
                                if (isCredit) {
                                  txn.selectedBucket = 'Income';
                                } else if (newCat == 'SIP & Investments') {
                                  txn.selectedBucket = 'Savings';
                                } else if (['Shopping', 'Entertainment'].contains(newCat)) {
                                  txn.selectedBucket = 'Wants';
                                } else {
                                  txn.selectedBucket = 'Needs';
                                }
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Right Dropdown: Other Account (if Transfer) OR Sub-Category (if Regular)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: txn.isTransfer ? AppColors.transfer : Colors.grey.shade400,
                        width: txn.isTransfer ? 1.2 : 0.8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: txn.isTransfer
                          ? DropdownButton<String>(
                              isExpanded: true,
                              value: otherBanks.contains(txn.transferOtherBank)
                                  ? txn.transferOtherBank
                                  : otherBanks.first,
                              items: otherBanks.map((b) {
                                return DropdownMenuItem<String>(
                                  value: b,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCredit
                                            ? Icons.call_received_rounded
                                            : Icons.call_made_rounded,
                                        size: 13,
                                        color: AppColors.transfer,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${isCredit ? "From" : "To"}: $b',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newBank) {
                                if (newBank != null) {
                                  setState(() => txn.transferOtherBank = newBank);
                                }
                              },
                            )
                          : DropdownButton<String>(
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

            // Bottom Status Pill: Self-Transfer vs 50-30-20 Bucket
            if (txn.isTransfer)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.transfer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.transfer, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 12, color: AppColors.transfer),
                        SizedBox(width: 4),
                        Text(
                          'Self Transfer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.transfer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCredit
                          ? '${txn.transferOtherBank ?? "Other"} ➔ $_targetBank (Neutral • Money stayed with you)'
                          : '$_targetBank ➔ ${txn.transferOtherBank ?? "Other"} (Neutral • Money stayed with you)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
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
      case 'Transfer':
        return AppColors.transfer;
      case 'Income':
      default:
        return Colors.green.shade600;
    }
  }
}
