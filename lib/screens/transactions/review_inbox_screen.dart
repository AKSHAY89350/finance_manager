import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pending_transaction.dart';
import '../../providers/pending_provider.dart';
import '../../providers/bank_provider.dart';
import '../../services/sms_sync_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class ReviewInboxScreen extends ConsumerStatefulWidget {
  const ReviewInboxScreen({super.key});

  @override
  ConsumerState<ReviewInboxScreen> createState() => _ReviewInboxScreenState();
}

class _ReviewInboxScreenState extends ConsumerState<ReviewInboxScreen> {
  String? _bankFilter;
  String? _typeFilter;
  bool _isSyncing = false;

  Future<void> _syncBankSms() async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning phone SMS inbox for bank transactions...'),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await SmsSyncService.instance.syncRecentInbox(ref);
    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (!result.permissionGranted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'To automatically detect bank debits, credits, and UPI payments, Finance Manager needs permission to read SMS messages. Your data is 100% offline and never leaves your phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SmsSyncService.instance.requestPermission();
                if (mounted) {
                  _syncBankSms();
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.newAdded > 0
              ? 'Found ${result.newAdded} new bank transaction(s)!'
              : 'Inbox scanned. No new unreviewed bank transactions.',
        ),
        backgroundColor: result.newAdded > 0 ? Colors.green : Colors.grey[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Inbox'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync SMS from Phone',
            onPressed: _isSyncing ? null : () => _syncBankSms(),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Simulate Test Bank SMS',
            onPressed: () => _showSimulateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(pendingNotifierProvider.notifier).loadPending(),
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 72, color: Colors.green[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No Pending Transactions',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Incoming bank SMS alerts and UPI app notifications will automatically appear here for 1-tap review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_isSyncing ? 'Scanning Inbox...' : 'Sync Recent Bank SMS'),
                      onPressed: _isSyncing ? null : () => _syncBankSms(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Simulate Test Bank SMS'),
                      onPressed: () => _showSimulateDialog(context),
                    ),
                  ],
                ),
              ),
            );
          }

          final uniqueBanks = list.map((e) => e.bank).toSet().toList();
          final displayed = list.where((txn) {
            if (_bankFilter != null && txn.bank.toLowerCase() != _bankFilter!.toLowerCase()) {
              return false;
            }
            if (_typeFilter != null && txn.type.toUpperCase() != _typeFilter!.toUpperCase()) {
              return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              if (uniqueBanks.length > 1 || list.length > 2)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _bankFilter == null && _typeFilter == null,
                          onSelected: (_) {
                            setState(() {
                              _bankFilter = null;
                              _typeFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...uniqueBanks.map((b) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(b),
                                selected: _bankFilter?.toLowerCase() == b.toLowerCase(),
                                onSelected: (sel) {
                                  setState(() => _bankFilter = sel ? b : null);
                                },
                              ),
                            )),
                        ChoiceChip(
                          label: const Text('Debits'),
                          selected: _typeFilter == 'EXPENSE',
                          onSelected: (sel) {
                            setState(() => _typeFilter = sel ? 'EXPENSE' : null);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Credits'),
                          selected: _typeFilter == 'INCOME',
                          onSelected: (sel) {
                            setState(() => _typeFilter = sel ? 'INCOME' : null);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'No pending SMS match the selected filter',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _bankFilter = null;
                                  _typeFilter = null;
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayed.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final txn = displayed[index];
                          return _buildPendingCard(context, txn);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, PendingTransaction txn) {
    final isExpense = txn.type == 'EXPENSE';
    final categoryIcon = AppConstants.categoryIcons[txn.suggestedCategory] ?? '🔹';

    return Dismissible(
      key: ValueKey(txn.fingerprint),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(pendingNotifierProvider.notifier).discardTransaction(txn);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction discarded')),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Type badge, Date, and Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isExpense ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      txn.type,
                      style: TextStyle(
                        color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    txn.date,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    AppFormatters.currency(txn.amount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Merchant & Bank
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txn.merchant,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      txn.accountDigits != null
                          ? '${txn.bank} ••••${txn.accountDigits}'
                          : txn.bank,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Suggested Category
              Row(
                children: [
                  Text(categoryIcon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    txn.suggestedCategory,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (txn.suggestedSubCategory != null) ...[
                    const Text(' › ', style: TextStyle(color: Colors.grey)),
                    Text(
                      txn.suggestedSubCategory!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Raw SMS preview (subtle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  txn.rawMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 14),

              // Action buttons: Discard on left, Edit & Confirm on right
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                      label: const Text('Discard', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        ref.read(pendingNotifierProvider.notifier).discardTransaction(txn);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction discarded')),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => _showEditBottomSheet(context, txn),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Confirm', style: TextStyle(fontSize: 13)),
                      onPressed: () async {
                        await ref.read(pendingNotifierProvider.notifier).confirmTransaction(txn);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Saved: ${AppFormatters.currency(txn.amount)} to ${txn.suggestedCategory} (${txn.bank})',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBottomSheet(BuildContext context, PendingTransaction txn) {
    String selectedCategory = txn.suggestedCategory;
    String? selectedSubCategory = txn.suggestedSubCategory;
    String selectedBank = txn.bank;
    final amountController = TextEditingController(text: txn.amount.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final subCats = AppConstants.categorySubMap[selectedCategory] ?? [];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit & Confirm Transaction',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount field
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: AppConstants.categorySubMap.containsKey(selectedCategory)
                        ? selectedCategory
                        : 'Other',
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.categorySubMap.keys.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text('${AppConstants.categoryIcons[cat] ?? ""} $cat'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedCategory = val;
                          final newSubs = AppConstants.categorySubMap[val] ?? [];
                          selectedSubCategory = newSubs.isNotEmpty ? newSubs.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Sub-Category dropdown
                  if (subCats.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: subCats.contains(selectedSubCategory)
                          ? selectedSubCategory
                          : subCats.first,
                      decoration: const InputDecoration(
                        labelText: 'Sub-Category',
                        border: OutlineInputBorder(),
                      ),
                      items: subCats.map((sub) {
                        return DropdownMenuItem(value: sub, child: Text(sub));
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() => selectedSubCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Bank selector
                  Consumer(
                    builder: (context, ref, _) {
                      final banksAsync = ref.watch(bankProvider);
                      final banks = banksAsync.maybeWhen(
                        data: (list) => list.map((b) => b.bank.name).toList(),
                        orElse: () => AppConstants.defaultBanks,
                      );

                      return DropdownButtonFormField<String>(
                        initialValue: banks.contains(selectedBank) ? selectedBank : banks.first,
                        decoration: const InputDecoration(
                          labelText: 'Bank Account',
                          border: OutlineInputBorder(),
                        ),
                        items: banks.map((b) {
                          return DropdownMenuItem(value: b, child: Text(b));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedBank = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final parsedAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (parsedAmount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount greater than 0'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);

                        await ref.read(pendingNotifierProvider.notifier).confirmTransaction(
                          txn,
                          category: selectedCategory,
                          subCategory: selectedSubCategory,
                          bank: selectedBank,
                          amount: parsedAmount,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Confirmed: ${AppFormatters.currency(parsedAmount)} to $selectedCategory ($selectedBank)',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      },
                      child: const Text('Save to Ledger & Learn Rule', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSimulateDialog(BuildContext context) {
    final sampleMessages = [
      'Rs 450.00 debited from A/c XX4589 on 12-Oct-26 to ZOMATO. Avl Bal: Rs 45,210.00',
      'INR 1,299 debited from card ending 1024 for BLINKIT ref 429817291827',
      'Paid INR 75.00 to Chai Point via UPI ref 8921739182',
      'Rs 85,000.00 credited to A/c XX4589 on 01-Oct-26 by NEOSOFT SALARY. Avl Bal: Rs 1,20,500.00',
    ];

    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Simulate Incoming SMS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a sample Indian banking alert or type your own to test on-device parsing:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...sampleMessages.map((msg) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(dialogCtx);
                          final added = await ref
                              .read(pendingNotifierProvider.notifier)
                              .processIncomingMessage(msg);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? 'SMS Parsed & Added to Review Inbox!'
                                      : 'Duplicate or Ignored (Already exists)',
                                ),
                                backgroundColor: added ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(msg, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    )),
                const Divider(),
                TextField(
                  controller: customController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Paste custom bank SMS text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = customController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  final added = await ref
                      .read(pendingNotifierProvider.notifier)
                      .processIncomingMessage(text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? 'Custom SMS Parsed Successfully!'
                              : 'Could not extract financial details or duplicate.',
                        ),
                        backgroundColor: added ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: const Text('Parse'),
            ),
          ],
        );
      },
    );
  }
}
