import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transfer.dart';
import '../../providers/bank_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../db/database_helper.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  String _fromBank = AppConstants.defaultBanks.first;
  String _toBank = AppConstants.defaultBanks.length > 1 ? AppConstants.defaultBanks[1] : AppConstants.defaultBanks.first;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isLoading = false;

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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromBank == _toBank) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From Bank and To Bank cannot be the same')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final transfer = Transfer(
      date: AppFormatters.dbDate(_selectedDate),
      fromBank: _fromBank,
      toBank: _toBank,
      amount: amount,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );

    await DatabaseHelper.instance.insertTransfer(transfer.toMap());
    await ref.read(bankProvider.notifier).loadBanks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funds transferred successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Transfer')),
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
                        labelText: 'Transfer Amount (₹)',
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
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.transfer),
                        title: const Text('Date'),
                        subtitle: Text(AppFormatters.displayDate(_selectedDate)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _fromBank,
                      decoration: const InputDecoration(labelText: 'From Bank (Debited)'),
                      items: AppConstants.defaultBanks.map((b) {
                        return DropdownMenuItem(value: b, child: Text(b));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _fromBank = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _toBank,
                      decoration: const InputDecoration(labelText: 'To Bank (Credited)'),
                      items: AppConstants.defaultBanks.map((b) {
                        return DropdownMenuItem(value: b, child: Text(b));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _toBank = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Purpose (optional)',
                        hintText: 'e.g., Transfer for SIP or credit card payment',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.transfer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Confirm Transfer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
