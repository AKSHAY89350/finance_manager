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

  static Future<AutoDebitExecutionReport>? _activeBatchProcessing;

  /// Safety cap: prevents runaway deductions if an old start date was entered
  static const int maxCatchUpCycles = 12;

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
  ///
  /// Concurrency Guard: If an execution is already in progress, concurrent callers await
  /// the active Future rather than triggering duplicate expense deductions.
  static Future<AutoDebitExecutionReport> processDueAutoDebits({DateTime? asOfDate}) async {
    if (_activeBatchProcessing != null) {
      return await _activeBatchProcessing!;
    }

    final future = _processDueAutoDebitsInternal(asOfDate: asOfDate);
    _activeBatchProcessing = future;
    try {
      return await future;
    } finally {
      _activeBatchProcessing = null;
    }
  }

  static Future<AutoDebitExecutionReport> _processDueAutoDebitsInternal({DateTime? asOfDate}) async {
    final effectiveDate = asOfDate ?? DateTime.now();
    final asOfDateStr = AppFormatters.dbDate(effectiveDate);

    final dueRuleMaps = await DatabaseHelper.instance.getDueRecurringRules(asOfDateStr);
    final List<AutoDebitResult> executed = [];
    final List<AutoDebitResult> skippedLowBalance = [];

    for (final map in dueRuleMaps) {
      var rule = RecurringRule.fromMap(map);
      int cycleCount = 0;

      // Safe multi-month catch-up loop (e.g. user was offline 2 months)
      while (rule.nextDueDate.compareTo(asOfDateStr) <= 0 && cycleCount < maxCatchUpCycles) {
        cycleCount++;

        // Check current live balance of the configured bank account before this cycle
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
              'Auto-debited ${AppFormatters.currency(rule.amount)} from ${rule.bank} for ${rule.nextDueDate}.';

          await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
            'last_processed_date': asOfDateStr,
            'next_due_date': nextDue,
            'last_status': 'SUCCESS',
            'last_status_message': statusMessage,
          });

          rule = rule.copyWith(
            lastProcessedDate: asOfDateStr,
            nextDueDate: nextDue,
            lastStatus: 'SUCCESS',
            lastStatusMessage: statusMessage,
          );

          executed.add(AutoDebitResult(
            rule: rule,
            success: true,
            message: statusMessage,
            requiredAmount: rule.amount,
            availableBalance: liveBalance,
          ));
        } else {
          // Insufficient balance -> Do NOT deduct, flag warning and stop catch-up
          final warningMessage =
              'Insufficient balance in ${rule.bank}. Required: ${AppFormatters.currency(rule.amount)}, Available: ${AppFormatters.currency(liveBalance)}.';

          await DatabaseHelper.instance.updateRecurringRule(rule.id!, {
            'last_status': 'INSUFFICIENT_BALANCE',
            'last_status_message': warningMessage,
          });

          rule = rule.copyWith(
            lastStatus: 'INSUFFICIENT_BALANCE',
            lastStatusMessage: warningMessage,
          );

          skippedLowBalance.add(AutoDebitResult(
            rule: rule,
            success: false,
            message: warningMessage,
            requiredAmount: rule.amount,
            availableBalance: liveBalance,
          ));
          break; // Stop further catch-up cycles until user funds the account
        }
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
    // If a batch auto-debit process is running, wait for it first
    if (_activeBatchProcessing != null) {
      await _activeBatchProcessing!;
    }

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
