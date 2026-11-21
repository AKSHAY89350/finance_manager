import 'package:flutter/material.dart';
import '../../models/statement_transaction.dart';
import '../../services/statement_deduplication_service.dart';
import '../../utils/formatters.dart';
import 'statement_categorization_screen.dart';

class StatementReviewScreen extends StatefulWidget {
  final DeduplicationResult result;
  final String selectedBank;
  final String fileName;

  const StatementReviewScreen({
    super.key,
    required this.result,
    required this.selectedBank,
    required this.fileName,
  });

  @override
  State<StatementReviewScreen> createState() => _StatementReviewScreenState();
}

class _StatementReviewScreenState extends State<StatementReviewScreen> {
  late List<StatementTransaction> _transactions;
  String _activeFilter = 'All'; // 'All' | 'Debits' | 'Credits' | 'Duplicates'

  @override
  void initState() {
    super.initState();
    _transactions = widget.result.transactions;
  }

  int get _selectedCount => _transactions.where((t) => t.isApproved).length;

  List<StatementTransaction> get _filteredTransactions {
    switch (_activeFilter) {
      case 'Debits':
        return _transactions.where((t) => !t.isCredit).toList();
      case 'Credits':
        return _transactions.where((t) => t.isCredit).toList();
      case 'Duplicates':
        return _transactions.where((t) => t.isDuplicate).toList();
      case 'All':
      default:
        return _transactions;
    }
  }

  void _skipAllDuplicates() {
    setState(() {
      for (final t in _transactions) {
        if (t.isDuplicate) {
          t.isApproved = false;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unselected all ${widget.result.duplicateCount} duplicate transactions.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _selectAllUnique() {
    setState(() {
      for (final t in _transactions) {
        if (!t.isDuplicate) {
          t.isApproved = true;
        }
      }
    });
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      for (final t in _filteredTransactions) {
        t.isApproved = selectAll;
      }
    });
  }

  void _proceedToCategorization() {
    final approvedList = _transactions.where((t) => t.isApproved).toList();

    if (approvedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 transaction to move forward.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatementCategorizationScreen(
          approvedTransactions: approvedList,
          selectedBank: widget.selectedBank,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final debitCount = _transactions.where((t) => !t.isCredit).length;
    final creditCount = _transactions.where((t) => t.isCredit).length;
    final dupCount = widget.result.duplicateCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Transactions'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Select all in view',
            icon: const Icon(Icons.select_all_rounded),
            onPressed: () => _toggleSelectAll(true),
          ),
          IconButton(
            tooltip: 'Deselect all in view',
            icon: const Icon(Icons.deselect_rounded),
            onPressed: () => _toggleSelectAll(false),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Duplicate Alert Banner
          if (dupCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: Colors.amber.shade700, width: 1.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dupCount Duplicate Transactions Found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                          ),
                        ),
                        Text(
                          'Matches existing amount & date. Unselected by default.',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade800,
                          side: BorderSide(color: Colors.amber.shade700),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _selectAllUnique,
                        child: const Text('Unique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _skipAllDuplicates,
                        child: const Text('Skip All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 2. Summary Statistics Card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.fileName.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${_transactions.length} Total Found',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Debits ($debitCount)', style: const TextStyle(fontSize: 11, color: Colors.red)),
                          Text(
                            AppFormatters.currency(widget.result.totalDebits),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Credits ($creditCount)', style: const TextStyle(fontSize: 11, color: Colors.green)),
                          Text(
                            AppFormatters.currency(widget.result.totalCredits),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Duplicates', style: TextStyle(fontSize: 11, color: Colors.orange)),
                          Text(
                            '$dupCount',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('All', _transactions.length),
                _buildFilterChip('Debits', debitCount),
                _buildFilterChip('Credits', creditCount),
                if (dupCount > 0) _buildFilterChip('Duplicates', dupCount),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. List of Transactions
          Expanded(
            child: _filteredTransactions.isEmpty
                ? const Center(
                    child: Text('No transactions match the selected filter.'),
                  )
                : ListView.builder(
                    itemCount: _filteredTransactions.length,
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 90),
                    itemBuilder: (context, index) {
                      final item = _filteredTransactions[index];
                      return _buildTransactionCard(item, theme, isDark);
                    },
                  ),
          ),
        ],
      ),

      // 5. Bottom Floating Action Bar
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedCount of ${_transactions.length} Selected',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Tap checkbox to approve or exclude',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _proceedToCategorization,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Next: Categorize ($_selectedCount)'),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _activeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
        selectedColor: Theme.of(context).primaryColor,
        onSelected: (val) {
          if (val) setState(() => _activeFilter = label);
        },
      ),
    );
  }

  Widget _buildTransactionCard(StatementTransaction txn, ThemeData theme, bool isDark) {
    final isCredit = txn.isCredit;
    final isDup = txn.isDuplicate;

    Color borderColor;
    if (isDup) {
      borderColor = Colors.amber.shade700;
    } else if (txn.isApproved) {
      borderColor = isCredit ? Colors.green.shade600 : theme.primaryColor;
    } else {
      borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isDup || txn.isApproved ? 1.5 : 1),
      ),
      color: isDup
          ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.12) : Colors.amber.shade50.withValues(alpha: 0.6))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            txn.isApproved = !txn.isApproved;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Approval Checkbox
                  Checkbox(
                    value: txn.isApproved,
                    activeColor: isDup ? Colors.amber.shade700 : theme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        txn.isApproved = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),

                  // Narration & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txn.cleanDescription,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${txn.formattedDate} • ${txn.narration}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Amount & Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? "+" : "-"} ${AppFormatters.currency(txn.amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDup
                              ? Colors.amber.shade800
                              : (isCredit ? Colors.green.shade800 : Colors.red.shade800),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDup ? 'DUPLICATE' : (isCredit ? 'CREDIT' : 'DEBIT'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Duplicate Warning Details
              if (isDup && txn.duplicateReason != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          txn.duplicateReason!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
