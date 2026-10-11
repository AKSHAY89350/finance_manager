import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/bank_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../db/database_helper.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? initialExpense;

  const AddExpenseScreen({super.key, this.initialExpense});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  late String _selectedCategory;
  String? _selectedSubCategory;
  late String _selectedBank;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<String> _subCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialExpense != null) {
      final e = widget.initialExpense!;
      _selectedDate = AppFormatters.parseDbDate(e.date);
      _selectedCategory = e.category;
      _selectedSubCategory = e.subCategory;
      _selectedBank = e.bank;
      _amountController.text = e.amount.toString();
      _descController.text = e.description ?? '';
    } else {
      _selectedDate = DateTime.now();
      _selectedCategory = AppConstants.categories.first;
      _selectedBank = AppConstants.defaultBanks.first;
    }
    _loadSubCategories(_selectedCategory);
  }

  Future<void> _loadSubCategories(String category) async {
    final subs = await DatabaseHelper.instance.getSubCategories(category);
    setState(() {
      _subCategories = subs;
      if (widget.initialExpense != null && widget.initialExpense!.category == category) {
        _selectedSubCategory = widget.initialExpense!.subCategory;
      } else {
        _selectedSubCategory = subs.isNotEmpty ? subs.first : null;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final expense = Expense(
      id: widget.initialExpense?.id,
      date: AppFormatters.dbDate(_selectedDate),
      category: _selectedCategory,
      subCategory: _selectedSubCategory,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      amount: amount,
      bank: _selectedBank,
    );

    if (widget.initialExpense == null) {
      await ref.read(expenseProvider.notifier).addExpense(expense);
    } else {
      await ref.read(expenseProvider.notifier).updateExpense(expense);
    }
    
    // Refresh bank live balances
    await ref.read(bankProvider.notifier).loadBanks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.initialExpense == null ? 'Expense added!' : 'Expense updated!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialExpense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter amount';
                        if (double.tryParse(val) == null) return 'Enter valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Tile
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                        title: const Text('Date'),
                        subtitle: Text(AppFormatters.displayDate(_selectedDate)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: AppConstants.categories.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${AppConstants.categoryIcons[c] ?? "🔹"}  $c'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                          _loadSubCategories(val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Sub-Category Dropdown
                    if (_subCategories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedSubCategory,
                        decoration: const InputDecoration(labelText: 'Sub-Category'),
                        items: _subCategories.map((sc) {
                          return DropdownMenuItem(value: sc, child: Text(sc));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubCategory = val;
                          });
                        },
                      ),
                    if (_subCategories.isNotEmpty) const SizedBox(height: 16),

                    // Bank Selector
                    DropdownButtonFormField<String>(
                      value: _selectedBank,
                      decoration: const InputDecoration(labelText: 'Debited Bank'),
                      items: AppConstants.defaultBanks.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.forBank(b),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(b),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedBank = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description / Note (optional)',
                        hintText: 'e.g., Grocery trip, Sai mess, etc.',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.initialExpense == null ? 'Save Expense' : 'Update Expense',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
