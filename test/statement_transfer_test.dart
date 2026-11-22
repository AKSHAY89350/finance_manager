import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/statement_transaction.dart';
import 'package:finance_manager/services/statement_categorizer_service.dart';

void main() {
  group('Statement Internal Transfer (Self Transfer) Tests', () {
    test('StatementTransaction initializes with isTransfer false by default', () {
      final txn = StatementTransaction(
        date: DateTime(2026, 11, 22),
        narration: 'UPI-Swiggy-12345',
        cleanDescription: 'Swiggy',
        amount: 340.0,
        isCredit: false,
        bankName: 'HDFC',
      );

      expect(txn.isTransfer, isFalse);
      expect(txn.selectedBucket, 'Needs');
      expect(txn.transferOtherBank, isNull);
    });

    test('StatementTransaction can be flagged as an internal transfer', () {
      final txn = StatementTransaction(
        date: DateTime(2026, 11, 22),
        narration: 'TRF TO SELF SBI A/C 9876',
        cleanDescription: 'Self Transfer',
        amount: 15000.0,
        isCredit: false,
        bankName: 'HDFC',
        isTransfer: true,
        transferOtherBank: 'SBI',
        selectedCategory: 'Internal Transfer',
      );

      expect(txn.isTransfer, isTrue);
      expect(txn.selectedBucket, 'Transfer');
      expect(txn.transferOtherBank, 'SBI');
      expect(txn.selectedCategory, 'Internal Transfer');
    });

    test('StatementCategorizerService auto-detects self-transfer narrations', () {
      final debitSelf = StatementCategorizerService.suggest(
        'NEFT TO OWN A/C IN SBI BANK',
        false,
      );

      expect(debitSelf.isTransfer, isTrue);
      expect(debitSelf.category, 'Internal Transfer');
      expect(debitSelf.bucket, 'Transfer');

      final creditSelf = StatementCategorizerService.suggest(
        'IMPS FUNDS TRANSFER TO OWN ACCOUNT',
        true,
      );

      expect(creditSelf.isTransfer, isTrue);
      expect(creditSelf.category, 'Internal Transfer');
      expect(creditSelf.bucket, 'Transfer');
    });

    test('StatementCategorizerService.mapCategoryTo503020 maps Internal Transfer to Transfer bucket', () {
      expect(StatementCategorizerService.mapCategoryTo503020('Internal Transfer'), 'Transfer');
      expect(StatementCategorizerService.mapCategoryTo503020('SIP & Investments'), 'Savings');
      expect(StatementCategorizerService.mapCategoryTo503020('Food'), 'Needs');
    });

    test('Transfer direction logic: Debit sends from Target to Other, Credit sends from Other to Target', () {
      const targetBank = 'HDFC';
      const otherBank = 'SBI';

      // Case A: Debit of 10,000 from HDFC statement
      // Meaning: Money moved FROM HDFC TO SBI
      final debitTxn = StatementTransaction(
        date: DateTime(2026, 11, 22),
        narration: 'TRF TO SBI',
        cleanDescription: 'Self Transfer',
        amount: 10000.0,
        isCredit: false,
        bankName: targetBank,
        isTransfer: true,
        transferOtherBank: otherBank,
      );

      final debitFrom = debitTxn.isCredit ? debitTxn.transferOtherBank! : targetBank;
      final debitTo = debitTxn.isCredit ? targetBank : debitTxn.transferOtherBank!;

      expect(debitFrom, 'HDFC');
      expect(debitTo, 'SBI');

      // Case B: Credit of 5,000 on SBI statement
      // Meaning: Money received into SBI FROM HDFC
      final creditTxn = StatementTransaction(
        date: DateTime(2026, 11, 22),
        narration: 'TRF FROM HDFC',
        cleanDescription: 'Self Transfer',
        amount: 5000.0,
        isCredit: true,
        bankName: otherBank,
        isTransfer: true,
        transferOtherBank: targetBank,
      );

      final creditFrom = creditTxn.isCredit ? creditTxn.transferOtherBank! : otherBank;
      final creditTo = creditTxn.isCredit ? otherBank : creditTxn.transferOtherBank!;

      expect(creditFrom, 'HDFC');
      expect(creditTo, 'SBI');
    });
  });
}
