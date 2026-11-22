import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extra_credit.dart';
import '../../providers/bank_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/investment_provider.dart';
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
  late String _selectedSubCategory;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _buyAmountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final investmentSubs = AppConstants.categorySubMap['SIP & Investments'] ?? AppConstants.investmentTypes;
    if (widget.initialIncome != null) {
      final inc = widget.initialIncome!;
      _selectedDate = AppFormatters.parseDbDate(inc.date);
      _selectedMode = inc.mode;
      _selectedBank = inc.bank;
      _amountController.text = inc.amount.toString();
      _sourceController.text = inc.userName ?? '';
      _selectedSubCategory = inc.subCategory ?? investmentSubs.first;
      if (inc.buyAmount != null) {
        _buyAmountController.text = inc.buyAmount.toString();
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedMode = AppConstants.incomeModes.first;
      _selectedBank = AppConstants.defaultBanks.first;
      _selectedSubCategory = investmentSubs.first;
    }

    _amountController.addListener(_onAmountChanged);
    _buyAmountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _buyAmountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _buyAmountController.dispose();
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

    final isInvestmentSale = _selectedMode == 'Stock / Investment Sale';
    double? buyAmount;
    double? profitAmount;

    if (isInvestmentSale) {
      buyAmount = AppFormatters.parseCurrency(_buyAmountController.text);
      if (buyAmount == null || buyAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid rate/amount of buying')),
        );
        return;
      }
      profitAmount = amount - buyAmount;
    }

    setState(() => _isLoading = true);

    final income = ExtraCredit(
      id: widget.initialIncome?.id,
      date: AppFormatters.dbDate(_selectedDate),
      userName: _sourceController.text.trim().isEmpty
          ? (isInvestmentSale
              ? 'Sold $_selectedSubCategory (Buy: ₹${AppFormatters.number(buyAmount!)} • Profit: ${profitAmount! >= 0 ? '+' : ''}₹${AppFormatters.number(profitAmount)})'
              : null)
          : _sourceController.text.trim(),
      amount: amount,
      mode: _selectedMode,
      bank: _selectedBank,
      subCategory: isInvestmentSale ? _selectedSubCategory : null,
      buyAmount: buyAmount,
      profitAmount: profitAmount,
      isInvestmentRedemption: isInvestmentSale,
    );

    if (widget.initialIncome == null) {
      await ref.read(incomeProvider.notifier).addIncome(income);
    } else {
      await ref.read(incomeProvider.notifier).updateIncome(income);
    }
    await ref.read(bankProvider.notifier).loadBanks();
    await ref.read(investmentProvider.notifier).loadInvestments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialIncome == null
                ? (isInvestmentSale
                    ? 'Investment sale recorded! ₹${AppFormatters.number(buyAmount!)} deducted from $_selectedSubCategory, ₹${AppFormatters.number(amount)} credited to $_selectedBank.'
                    : 'Income credited successfully!')
                : 'Income updated successfully!',
          ),
        ),
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

    final isInvestmentSale = _selectedMode == 'Stock / Investment Sale';
    final investmentSubs = AppConstants.categorySubMap['SIP & Investments'] ?? AppConstants.investmentTypes;
    if (!investmentSubs.contains(_selectedSubCategory)) {
      _selectedSubCategory = investmentSubs.first;
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
                      decoration: InputDecoration(
                        labelText: isInvestmentSale ? 'Sale Amount Received (₹)' : 'Income Amount (₹)',
                        hintText: isInvestmentSale ? 'Total proceeds (e.g. 700)' : null,
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    if (isInvestmentSale) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('sub_$_selectedSubCategory'),
                        initialValue: _selectedSubCategory,
                        decoration: const InputDecoration(
                          labelText: 'Investment Sub-Category / Asset',
                          hintText: 'Select holding being sold',
                          prefixIcon: Icon(Icons.pie_chart_outline_rounded, color: AppColors.investment),
                        ),
                        items: investmentSubs.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSubCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _buyAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Rate of Buying / Original Purchase Price (₹)',
                          hintText: 'e.g. 500 (Amount originally invested)',
                          prefixText: '₹ ',
                          prefixIcon: Icon(Icons.shopping_cart_outlined, color: Colors.blueGrey),
                        ),
                        validator: (val) {
                          if (isInvestmentSale) {
                            if (val == null || val.isEmpty) return 'Enter original buying amount';
                            if (AppFormatters.parseCurrency(val) == null) return 'Enter valid number';
                          }
                          return null;
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final saleAmt = AppFormatters.parseCurrency(_amountController.text) ?? 0.0;
                          final buyAmt = AppFormatters.parseCurrency(_buyAmountController.text) ?? 0.0;
                          final profit = saleAmt - buyAmt;
                          final isProfit = profit >= 0;
                          final returnPct = buyAmt > 0 ? (profit / buyAmt) * 100 : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isProfit
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isProfit ? Colors.green.shade400 : Colors.red.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                          color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'P&L & INVESTMENT IMPACT',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                            color: isProfit ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${isProfit ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Principal Returned:', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                    Text('₹${AppFormatters.number(buyAmt)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isProfit ? 'Realized Profit / Gain:' : 'Realized Loss:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                    Text(
                                      '${isProfit ? '+' : ''}₹${AppFormatters.number(profit)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Text(
                                  '💡 ₹${AppFormatters.number(buyAmt)} will be erased from your "$_selectedSubCategory" active investment tab, and the full ₹${AppFormatters.number(saleAmt)} will be credited to $_selectedBank.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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
                      decoration: InputDecoration(
                        labelText: isInvestmentSale
                            ? 'Notes / Description (Optional)'
                            : 'Source / Payer (e.g. Neosoft, Bank Interest)',
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
