import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/recurring_rule.dart';
import '../services/auto_debit_service.dart';
import 'bank_provider.dart';
import 'expense_provider.dart';

class RecurringNotifier extends StateNotifier<AsyncValue<List<RecurringRule>>> {
  final Ref ref;

  RecurringNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadRules();
  }

  Future<void> loadRules() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final rows = await DatabaseHelper.instance.getAllRecurringRules();
      final rules = rows.map((r) => RecurringRule.fromMap(r)).toList();
      state = AsyncValue.data(rules);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addRule(RecurringRule rule) async {
    await DatabaseHelper.instance.insertRecurringRule(rule.toMap());
    await loadRules();
  }

  Future<void> updateRule(RecurringRule rule) async {
    if (rule.id != null) {
      await DatabaseHelper.instance.updateRecurringRule(rule.id!, rule.toMap());
      await loadRules();
    }
  }

  Future<void> deleteRule(int id) async {
    await DatabaseHelper.instance.deleteRecurringRule(id);
    await loadRules();
  }

  Future<void> toggleActive(int id, bool isActive) async {
    await DatabaseHelper.instance.updateRecurringRule(id, {
      'is_active': isActive ? 1 : 0,
    });
    await loadRules();
  }

  /// Checks and automatically executes all due recurring auto-debits (SIP, EMI, loans, bills).
  /// Verifies bank balance before deduction.
  Future<AutoDebitExecutionReport> processDueAutoDebits({
    BuildContext? context,
    bool showFeedback = false,
  }) async {
    final report = await AutoDebitService.processDueAutoDebits();

    if (report.hasChanges) {
      // Reload providers since expenses and balances were updated
      await ref.read(expenseProvider.notifier).loadExpenses();
      await ref.read(bankProvider.notifier).loadBanks();
      await loadRules();

      ref.read(latestAutoDebitReportProvider.notifier).state = report;

      if (context != null && context.mounted) {
        if (report.executed.isNotEmpty && report.skippedLowBalance.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚡ ${report.executed.length} Auto-Debit(s) processed. ⚠️ ${report.skippedLowBalance.length} skipped due to low balance.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (report.executed.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ ${report.executed.length} Auto-Debit(s) successfully processed!'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (report.skippedLowBalance.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ ${report.skippedLowBalance.length} Auto-Debit(s) skipped: Insufficient bank balance.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else if (showFeedback && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All auto-debits are up to date. No pending payments due.'),
        ),
      );
    }

    return report;
  }

  /// Retries processing a single rule (e.g. after user deposits funds).
  Future<AutoDebitResult> retryRule(int id, {BuildContext? context}) async {
    final result = await AutoDebitService.executeSingleRule(id);

    if (result.success) {
      await ref.read(expenseProvider.notifier).loadExpenses();
      await ref.read(bankProvider.notifier).loadBanks();
      await loadRules();

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      await loadRules();
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }

    return result;
  }
}

final recurringProvider =
    StateNotifierProvider<RecurringNotifier, AsyncValue<List<RecurringRule>>>((ref) {
  return RecurringNotifier(ref);
});

/// Holds the latest execution report for banner display
final latestAutoDebitReportProvider = StateProvider<AutoDebitExecutionReport?>((ref) => null);

/// Filtered upcoming active auto-debits sorted by next due date
final upcomingAutoDebitsProvider = Provider<List<RecurringRule>>((ref) {
  final rulesAsync = ref.watch(recurringProvider);
  return rulesAsync.maybeWhen(
    data: (rules) {
      final active = rules.where((r) => r.isActive).toList();
      active.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      return active;
    },
    orElse: () => [],
  );
});

/// Total monthly recurring commitment amount for active rules
final totalMonthlyRecurringProvider = Provider<double>((ref) {
  final rules = ref.watch(upcomingAutoDebitsProvider);
  return rules.fold<double>(0.0, (sum, r) => sum + r.amount);
});

/// Count of rules with INSUFFICIENT_BALANCE status
final lowBalanceAlertCountProvider = Provider<int>((ref) {
  final rulesAsync = ref.watch(recurringProvider);
  return rulesAsync.maybeWhen(
    data: (rules) => rules.where((r) => r.isActive && r.lastStatus == 'INSUFFICIENT_BALANCE').length,
    orElse: () => 0,
  );
});
