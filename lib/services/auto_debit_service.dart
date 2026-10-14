import 'dart:math' as math;
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/recurring_rule.dart';
import '../utils/formatters.dart';

class AutoDebitResult {
  final RecurringRule rule;
  final bool success;
  final String message;
  final double requiredAmount;
  final double availableBalance;

  AutoDebitResult({
    required this.rule,
    required this.success,
    required this.message,
    required this.requiredAmount,
    required this.availableBalance,
  });
}

class AutoDebitExecutionReport {
  final List<AutoDebitResult> executed;
  final List<AutoDebitResult> skippedLowBalance;
  final DateTime executedAt;

  AutoDebitExecutionReport({
    required this.executed,
    required this.skippedLowBalance,
    required this.executedAt,
  });

  bool get hasChanges => executed.isNotEmpty || skippedLowBalance.isNotEmpty;
  int get totalChecked => executed.length + skippedLowBalance.length;
}

class AutoDebitService {
  AutoDebitService._();

  /// Calculates the next monthly due date keeping the intended day of the month.
  /// Handles 28, 29, 30, and 31-day months properly (e.g. 31st Jan -> 28th Feb -> 31st Mar).
  static String calculateNextDueDate(int dayOfMonth, String currentDueDateStr) {
    final current = AppFormatters.parseDbDate(currentDueDateStr);
    final nextYear = current.month == 12 ? current.year + 1 : current.year;
    final nextMonth = current.month == 12 ? 1 : current.month + 1;

    // Get last day of nextMonth: day 0 of (nextMonth + 1)
    final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final targetDay = math.min(dayOfMonth, daysInNextMonth);

    final nextDate = DateTime(nextYear, nextMonth, targetDay);
    return AppFormatters.dbDate(nextDate);
  }

  /// Processes all active recurring rules that are due on or before [asOfDate].
  ///
  /// CRITICAL RULE ENFORCEMENT:
  /// Before any deduction, checks the live balance of the configured bank account.
  /// If balance >= amount: automatically records the expense, updates balance, and advances due date.
  /// If balance < amount: skips deduction and marks rule as INSUFFICIENT_BALANCE so account never overdrafts.
  static Future<AutoDebitExecutionReport> processDueAutoDebits({DateTime? asOfDate}) async {
    final effectiveDate = asOfDate ?? DateTime.now();
    final asOfDateStr = AppFormatters.dbDate(effectiveDate);

    final dueRuleMaps = await DatabaseHelper.instance.getDueRecurringRules(asOfDateStr);
    final List<AutoDebitResult> executed = [];
    final List<AutoDebitResult> skippedLowBalance = [];

    for (final map in dueRuleMaps) {
      final rule = RecurringRule.fromMap(map);

      // Check current live balance of the configured bank account
      final liveBalance = await DatabaseHelper.instance.getLiveBalance(rule.bank);

      if (liveBalance >= rule.amount) {
        // Sufficient balance -> Execute deduction
        final expense = Expense(
          date: rule.nextDueDate,
          category: rule.category,
          subCategory: rule.subCategory,
          amount: rule.amount,
          bank: rule.bank,
          description: '[Auto-Debit] ${rule.title}',
        );
        await DatabaseHelper.instance.insertExpense(expense.toMap());

        final nextDue = calculateNextDueDate(rule.dayOfMonth, rule.nextDueDate);
        final statusMessage =
            'Auto-debited ${AppFormatters.currency(rule.amount)} from ${rule.bank} on $asOfDateStr.';

        await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
          'last_processed_date': asOfDateStr,
          'next_due_date': nextDue,
          'last_status': 'SUCCESS',
          'last_status_message': statusMessage,
        });

        final updatedRule = rule.copyWith(
          lastProcessedDate: asOfDateStr,
          nextDueDate: nextDue,
          lastStatus: 'SUCCESS',
          lastStatusMessage: statusMessage,
        );

        executed.add(AutoDebitResult(
          rule: updatedRule,
          success: true,
          message: statusMessage,
          requiredAmount: rule.amount,
          availableBalance: liveBalance,
        ));
      } else {
        // Insufficient balance -> Do NOT deduct, flag warning
        final warningMessage =
            'Insufficient balance in ${rule.bank}. Required: ${AppFormatters.currency(rule.amount)}, Available: ${AppFormatters.currency(liveBalance)}.';

        await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
          'last_status': 'INSUFFICIENT_BALANCE',
          'last_status_message': warningMessage,
        });

        final updatedRule = rule.copyWith(
          lastStatus: 'INSUFFICIENT_BALANCE',
          lastStatusMessage: warningMessage,
        );

        skippedLowBalance.add(AutoDebitResult(
          rule: updatedRule,
          success: false,
          message: warningMessage,
          requiredAmount: rule.amount,
          availableBalance: liveBalance,
        ));
      }
    }

    return AutoDebitExecutionReport(
      executed: executed,
      skippedLowBalance: skippedLowBalance,
      executedAt: effectiveDate,
    );
  }

  /// Manually triggers processing of a single recurring rule (e.g. user taps "Retry" after depositing money).
  static Future<AutoDebitResult> executeSingleRule(int ruleId, {DateTime? asOfDate}) async {
    final effectiveDate = asOfDate ?? DateTime.now();
    final asOfDateStr = AppFormatters.dbDate(effectiveDate);

    final map = await DatabaseHelper.instance.getRecurringRuleById(ruleId);
    if (map == null) {
      throw Exception('Recurring rule with id $ruleId not found');
    }

    final rule = RecurringRule.fromMap(map);
    final liveBalance = await DatabaseHelper.instance.getLiveBalance(rule.bank);

    if (liveBalance >= rule.amount) {
      final expense = Expense(
        date: rule.nextDueDate,
        category: rule.category,
        subCategory: rule.subCategory,
        amount: rule.amount,
        bank: rule.bank,
        description: '[Auto-Debit] ${rule.title}',
      );
      await DatabaseHelper.instance.insertExpense(expense.toMap());

      final nextDue = calculateNextDueDate(rule.dayOfMonth, rule.nextDueDate);
      final statusMessage =
          'Auto-debited ${AppFormatters.currency(rule.amount)} from ${rule.bank} on $asOfDateStr.';

      await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
        'last_processed_date': asOfDateStr,
        'next_due_date': nextDue,
        'last_status': 'SUCCESS',
        'last_status_message': statusMessage,
      });

      final updatedRule = rule.copyWith(
        lastProcessedDate: asOfDateStr,
        nextDueDate: nextDue,
        lastStatus: 'SUCCESS',
        lastStatusMessage: statusMessage,
      );

      return AutoDebitResult(
        rule: updatedRule,
        success: true,
        message: statusMessage,
        requiredAmount: rule.amount,
        availableBalance: liveBalance,
      );
    } else {
      final warningMessage =
          'Insufficient balance in ${rule.bank}. Required: ${AppFormatters.currency(rule.amount)}, Available: ${AppFormatters.currency(liveBalance)}.';

      await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
        'last_status': 'INSUFFICIENT_BALANCE',
        'last_status_message': warningMessage,
      });

      final updatedRule = rule.copyWith(
        lastStatus: 'INSUFFICIENT_BALANCE',
        lastStatusMessage: warningMessage,
      );

      return AutoDebitResult(
        rule: updatedRule,
        success: false,
        message: warningMessage,
        requiredAmount: rule.amount,
        availableBalance: liveBalance,
      );
    }
  }
}
