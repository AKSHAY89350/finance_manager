import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/extra_credit.dart';
import 'package:finance_manager/models/transaction_filter.dart';

void main() {
  group('Income Transaction Edit Unit Tests', () {
    test('ExtraCredit model updates fields cleanly via copyWith', () {
      final initialIncome = ExtraCredit(
        id: 101,
        date: '2026-11-20',
        userName: 'Initial Client',
        amount: 45000.0,
        mode: 'Salary',
        bank: 'HDFC',
      );

      final updatedIncome = initialIncome.copyWith(
        amount: 52000.0,
        userName: 'Client XYZ Bonus',
        mode: 'Freelance',
        bank: 'SBI',
        date: '2026-11-21',
      );

      expect(updatedIncome.id, 101);
      expect(updatedIncome.amount, 52000.0);
      expect(updatedIncome.userName, 'Client XYZ Bonus');
      expect(updatedIncome.mode, 'Freelance');
      expect(updatedIncome.bank, 'SBI');
      expect(updatedIncome.date, '2026-11-21');
    });

    test('ExtraCredit toMap and fromMap preserve updated attributes', () {
      final updatedIncome = ExtraCredit(
        id: 202,
        date: '2026-11-22',
        userName: 'Dividend Payout',
        amount: 3200.50,
        mode: 'Investment',
        bank: 'ICICI',
      );

      final map = updatedIncome.toMap();
      expect(map['id'], 202);
      expect(map['amount'], 3200.50);
      expect(map['user_name'], 'Dividend Payout');
      expect(map['mode'], 'Investment');
      expect(map['bank'], 'ICICI');

      final reconstructed = ExtraCredit.fromMap(map);
      expect(reconstructed.id, 202);
      expect(reconstructed.amount, 3200.50);
      expect(reconstructed.userName, 'Dividend Payout');
      expect(reconstructed.mode, 'Investment');
      expect(reconstructed.bank, 'ICICI');
    });

    test('UnifiedTransaction accurately references originalIncome for edit screen routing', () {
      final income = ExtraCredit(
        id: 303,
        date: '2026-11-22',
        userName: 'Consulting Fee',
        amount: 15000.0,
        mode: 'Freelance',
        bank: 'Kotak',
      );

      final unified = UnifiedTransaction.fromIncome(income);

      expect(unified.kind, TransactionKind.income);
      expect(unified.id, 303);
      expect(unified.originalIncome, isNotNull);
      expect(unified.originalIncome!.amount, 15000.0);
      expect(unified.originalIncome!.userName, 'Consulting Fee');
      expect(unified.originalExpense, isNull);
    });
  });
}
