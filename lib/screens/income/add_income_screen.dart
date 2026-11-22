import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extra_credit.dart';
import '../../providers/bank_provider.dart';
import '../../providers/income_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class AddIncomeScreen extends ConsumerStatefulWidget {
  final ExtraCredit? initialIncome;

  const AddIncomeScreen({super.key, this.initialIncome});

  @override
  ConsumerState<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends ConsumerState<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late String _selectedMode;
  late String _selectedBank;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIncome != null) {
      final inc = widget.initialIncome!;
      _selectedDate = AppFormatters.parseDbDate(inc.date);
      _selectedMode = inc.mode;
      _selectedBank = inc.bank;
      _amountController.text = inc.amount.toString();
      _sourceController.text = inc.userName ?? '';
    } else {
      _selectedDate = DateTime.now();
      _selectedMode = AppConstants.incomeModes.first;
      _selectedBank = AppConstants.defaultBanks.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = AppFormatters.parseCurrency(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final income = ExtraCredit(
      id: widget.initialIncome?.id,
      date: AppFormatters.dbDate(_selectedDate),
      userName: _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim(),
      amount: amount,
      mode: _selectedMode,
      bank: _selectedBank,
    );

    if (widget.initialIncome == null) {
      await ref.read(incomeProvider.notifier).addIncome(income);
    } else {
      await ref.read(incomeProvider.notifier).updateIncome(income);
    }
    await ref.read(bankProvider.notifier).loadBanks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.initialIncome == null ? 'Income credited successfully!' : 'Income updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankState = ref.watch(bankProvider);
    final bankList = bankState.maybeWhen(
      data: (items) => items.map((i) => i.bank.name).toList(),
      orElse: () => AppConstants.defaultBanks,
    );
    final allBanks = {...bankList, _selectedBank}.toList();
    if (!allBanks.contains(_selectedBank) && allBanks.isNotEmpty) {
      _selectedBank = allBanks.first;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialIncome == null ? 'Add Income / Credit' : 'Edit Income / Credit')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Income Amount (₹)',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter amount';
                        if (AppFormatters.parseCurrency(val) == null) return 'Enter valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.income),
                        title: const Text('Date'),
                        subtitle: Text(AppFormatters.displayDate(_selectedDate)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('mode_$_selectedMode'),
                      initialValue: _selectedMode,
                      decoration: const InputDecoration(labelText: 'Income Mode / Type'),
                      items: AppConstants.incomeModes.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMode = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('bank_$_selectedBank'),
                      initialValue: _selectedBank,
                      decoration: const InputDecoration(labelText: 'Credited Bank'),
                      items: allBanks.map((b) {
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
                        if (val != null) setState(() => _selectedBank = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        labelText: 'Source / Payer (e.g. Neosoft, Bank Interest)',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveIncome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.income,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.initialIncome == null ? 'Save Income' : 'Update Income',
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
