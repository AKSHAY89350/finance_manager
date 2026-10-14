import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/recurring_rule.dart';
import 'package:finance_manager/services/auto_debit_service.dart';
import 'package:finance_manager/utils/formatters.dart';

void main() {
  group('Auto-Debit & Recurring Rule Unit Tests', () {
    test('calculateNextDueDate correctly advances by 1 month on regular days', () {
      final next = AutoDebitService.calculateNextDueDate(5, '2026-10-05');
      expect(next, equals('2026-11-05'));
    });

    test('calculateNextDueDate handles month lengths gracefully (Jan 31 to Feb 28)', () {
      final nextFeb = AutoDebitService.calculateNextDueDate(31, '2026-01-31');
      expect(nextFeb, equals('2026-02-28'));

      // Advancing from Feb 28 to March should restore Day 31
      final nextMar = AutoDebitService.calculateNextDueDate(31, '2026-02-28');
      expect(nextMar, equals('2026-03-31'));
    });

    test('calculateNextDueDate rolls over year properly from December to January', () {
      final nextYear = AutoDebitService.calculateNextDueDate(15, '2026-12-15');
      expect(nextYear, equals('2027-01-15'));
    });

    test('RecurringRule serialization toMap and fromMap', () {
      final rule = RecurringRule(
        id: 1,
        title: 'HDFC Mid-Cap Opportunities SIP',
        type: 'SIP',
        category: 'SIP & Investments',
        subCategory: 'Mutual Funds (SIP)',
        amount: 5000.0,
        bank: 'HDFC',
        dayOfMonth: 5,
        startDate: '2026-10-01',
        nextDueDate: '2026-11-05',
        isActive: true,
        notes: 'Monthly SIP via ECS',
        lastStatus: 'SUCCESS',
        lastStatusMessage: 'Auto-debited ₹5,000.00 from HDFC',
      );

      final map = rule.toMap();
      expect(map['title'], equals('HDFC Mid-Cap Opportunities SIP'));
      expect(map['amount'], equals(5000.0));
      expect(map['is_active'], equals(1));
      expect(map['day_of_month'], equals(5));

      final deserialized = RecurringRule.fromMap(map);
      expect(deserialized.id, equals(1));
      expect(deserialized.title, equals(rule.title));
      expect(deserialized.amount, equals(rule.amount));
      expect(deserialized.isActive, isTrue);
      expect(deserialized.lastStatus, equals('SUCCESS'));
    });

    test('RecurringRule scheduleDescription formatting', () {
      final rule1 = RecurringRule(
        title: 'Test 1',
        type: 'SIP',
        category: 'SIP & Investments',
        amount: 1000,
        bank: 'SBI',
        dayOfMonth: 1,
        startDate: '2026-10-01',
        nextDueDate: '2026-11-01',
      );
      expect(rule1.scheduleDescription, equals('1st of every month'));

      final rule2 = rule1.copyWith(dayOfMonth: 2);
      expect(rule2.scheduleDescription, equals('2nd of every month'));

      final rule3 = rule1.copyWith(dayOfMonth: 3);
      expect(rule3.scheduleDescription, equals('3rd of every month'));

      final rule5 = rule1.copyWith(dayOfMonth: 5);
      expect(rule5.scheduleDescription, equals('5th of every month'));

      final rule21 = rule1.copyWith(dayOfMonth: 21);
      expect(rule21.scheduleDescription, equals('21st of every month'));

      final rule22 = rule1.copyWith(dayOfMonth: 22);
      expect(rule22.scheduleDescription, equals('22nd of every month'));
    });

    test('RecurringRule isDue and daysUntilDue logic', () {
      final todayStr = AppFormatters.dbDate(DateTime.now());
      final dueToday = RecurringRule(
        title: 'Due Today SIP',
        type: 'SIP',
        category: 'SIP & Investments',
        amount: 2500,
        bank: 'HDFC',
        dayOfMonth: 14,
        startDate: '2026-10-01',
        nextDueDate: todayStr,
      );
      expect(dueToday.isDue, isTrue);
      expect(dueToday.daysUntilDue, lessThanOrEqualTo(0));

      final futureDate = DateTime.now().add(const Duration(days: 10));
      final dueFuture = dueToday.copyWith(nextDueDate: AppFormatters.dbDate(futureDate));
      expect(dueFuture.isDue, isFalse);
      expect(dueFuture.daysUntilDue, greaterThan(0));
    });

    test('calculateNextDueDate consecutive monthly catch-up simulation', () {
      // User offline for 3 months: July to October
      var due = '2026-07-10';
      due = AutoDebitService.calculateNextDueDate(10, due);
      expect(due, equals('2026-08-10'));
      due = AutoDebitService.calculateNextDueDate(10, due);
      expect(due, equals('2026-09-10'));
      due = AutoDebitService.calculateNextDueDate(10, due);
      expect(due, equals('2026-10-10'));

      expect(AutoDebitService.maxCatchUpCycles, equals(12));
    });
  });
}
