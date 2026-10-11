import 'package:flutter/material.dart';
import '../../models/bank.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class BankBalanceCard extends StatelessWidget {
  final Bank bank;
  final double liveBalance;
  final VoidCallback? onTap;

  const BankBalanceCard({
    super.key,
    required this.bank,
    required this.liveBalance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bankColor = AppColors.forBank(bank.name);
    final isNegative = liveBalance < 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bankColor.withValues(alpha: 0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: bankColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: bankColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bank.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: bankColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Net Status',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppFormatters.currency(liveBalance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isNegative ? AppColors.expense : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
