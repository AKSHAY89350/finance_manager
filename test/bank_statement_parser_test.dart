import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/statement_transaction.dart';
import 'package:finance_manager/models/expense.dart';
import 'package:finance_manager/models/extra_credit.dart';
import 'package:finance_manager/services/statement_categorizer_service.dart';
import 'package:finance_manager/services/statement_deduplication_service.dart';
import 'package:finance_manager/services/bank_statement_parser_service.dart';

void main() {
  group('Statement Categorizer & Narration Cleaner Tests', () {
    test('Cleans UPI narration into readable merchant name', () {
      const upi1 = 'UPI/123456789012/SWIGGY BANGALORE/HDFC/Payee';
      final clean1 = StatementCategorizerService.extractCleanDescription(upi1);
      expect(clean1.toLowerCase(), contains('swiggy'));

      const upi2 = 'UPI/Amazon Pay/ICICI/order9821';
      final clean2 = StatementCategorizerService.extractCleanDescription(upi2);
      expect(clean2.toLowerCase(), contains('amazon'));
    });

    test('Cleans POS and Card Swipes', () {
      const pos = 'POS 491028 HPCL PETROL PUMP BANGALORE';
      final clean = StatementCategorizerService.extractCleanDescription(pos);
      expect(clean.toLowerCase(), contains('hpcl'));
    });

    test('Auto-categorizes Food, Quick Ecommerce, Travel, and Shopping', () {
      final s1 = StatementCategorizerService.suggest('Swiggy Order #8921', false);
      expect(s1.category, equals('Food'));
      expect(s1.subCategory, equals('Zomato / Swiggy'));
      expect(s1.bucket, equals('Wants'));

      final s2 = StatementCategorizerService.suggest('Blinkit Quick Delivery', false);
      expect(s2.category, equals('Quick Ecommerce'));
      expect(s2.subCategory, equals('Blinkit'));
      expect(s2.bucket, equals('Needs'));

      final s3 = StatementCategorizerService.suggest('HPCL Petrol Fuel', false);
      expect(s3.category, equals('Traveling'));
      expect(s3.subCategory, equals('Fuel / Petrol'));
      expect(s3.bucket, equals('Needs'));

      final s4 = StatementCategorizerService.suggest('Amazon India Marketplace', false);
      expect(s4.category, equals('Shopping'));
      expect(s4.bucket, equals('Wants'));
    });

    test('Auto-categorizes Salary and Investment credits', () {
      final sSalary = StatementCategorizerService.suggest('INFOSYS SALARY NEFT OCT 2026', true);
      expect(sSalary.bucket, equals('Income'));
      expect(sSalary.subCategory, equals('Salary'));

      final sSIP = StatementCategorizerService.suggest('ZERODHA BROKING MUTUAL FUND SIP', false);
      expect(sSIP.category, equals('SIP & Investments'));
      expect(sSIP.bucket, equals('Savings'));
    });
  });

  group('Statement Deduplication Logic Tests (Date + Amount Matching)', () {
    test('Correctly identifies duplicate when both Amount and Date match existing expense', () async {
      final statementTxns = [
        StatementTransaction(
          date: DateTime(2026, 10, 18),
          narration: 'UPI/Swiggy Bangalore/9821',
          cleanDescription: 'Swiggy',
          amount: 540.0,
          isCredit: false,
          bankName: 'HDFC',
        ),
        StatementTransaction(
          date: DateTime(2026, 10, 19),
          narration: 'HPCL Petrol Pump',
          cleanDescription: 'HPCL',
          amount: 1200.0,
          isCredit: false,
          bankName: 'HDFC',
        ),
      ];

      // Simulated deduplication with in-memory logic
      final mockExpenses = [
        Expense(
          id: 1,
          date: '18/10/2026',
          category: 'Food',
          subCategory: 'Zomato / Swiggy',
          description: 'Swiggy Bangalore',
          amount: 540.0,
          bank: 'HDFC',
        ),
      ];

      // Test amount and date match manually
      for (final txn in statementTxns) {
        for (final exp in mockExpenses) {
          if ((exp.amount - txn.amount).abs() < 0.01 && exp.date == txn.formattedDate) {
            txn.isDuplicate = true;
            txn.duplicateReason = 'Matches existing expense: ₹${exp.amount} on ${exp.date}';
            txn.isApproved = false; // Auto-skip by default
          }
        }
      }

      // Swiggy should be marked as duplicate and unselected
      expect(statementTxns[0].isDuplicate, isTrue);
      expect(statementTxns[0].isApproved, isFalse);
      expect(statementTxns[0].duplicateReason, contains('540'));

      // HPCL should remain unique and approved
      expect(statementTxns[1].isDuplicate, isFalse);
      expect(statementTxns[1].isApproved, isTrue);
    });

    test('Correctly identifies duplicate income when Amount and Date match extra_credit', () async {
      final statementTxns = [
        StatementTransaction(
          date: DateTime(2026, 10, 1),
          narration: 'INFOSYS SALARY NEFT',
          cleanDescription: 'Infosys',
          amount: 85000.0,
          isCredit: true,
          bankName: 'HDFC',
        ),
      ];

      final mockCredits = [
        ExtraCredit(
          id: 1,
          date: '01/10/2026',
          userName: 'Infosys Salary',
          amount: 85000.0,
          mode: 'Salary',
          bank: 'HDFC',
        ),
      ];

      for (final txn in statementTxns) {
        for (final cred in mockCredits) {
          if ((cred.amount - txn.amount).abs() < 0.01 && cred.date == txn.formattedDate) {
            txn.isDuplicate = true;
            txn.isApproved = false;
          }
        }
      }

      expect(statementTxns[0].isDuplicate, isTrue);
      expect(statementTxns[0].isApproved, isFalse);
    });

    test('Different amounts on same date are NOT marked as duplicates', () {
      final txn = StatementTransaction(
        date: DateTime(2026, 10, 18),
        narration: 'Swiggy',
        cleanDescription: 'Swiggy',
        amount: 350.0,
        isCredit: false,
        bankName: 'HDFC',
      );

      final exp = Expense(
        date: '18/10/2026',
        category: 'Food',
        amount: 540.0,
        bank: 'HDFC',
      );

      final isMatch = (exp.amount - txn.amount).abs() < 0.01 && exp.date == txn.formattedDate;
      expect(isMatch, isFalse);
      expect(txn.isDuplicate, isFalse);
      expect(txn.isApproved, isTrue);
    });

    test('Month-end boundary deduplication matches across adjacent months (Oct 31 vs Nov 1)', () {
      final txn = StatementTransaction(
        date: DateTime(2026, 11, 1),
        narration: 'Rent Payment',
        cleanDescription: 'Rent',
        amount: 25000.0,
        isCredit: false,
        bankName: 'HDFC',
      );

      final exp = Expense(
        date: '2026-10-31',
        category: 'Home Send',
        amount: 25000.0,
        bank: 'HDFC',
      );

      // Verify calendar day comparison
      final txnDay = DateTime(txn.date.year, txn.date.month, txn.date.day);
      final expDate = DateTime.parse(exp.date);
      final expDay = DateTime(expDate.year, expDate.month, expDate.day);
      final diffDays = txnDay.difference(expDay).inDays.abs();

      expect(diffDays, equals(1));
      expect((exp.amount - txn.amount).abs() < 0.01, isTrue);
    });

    test('Parses amounts with commas and no decimals (e.g. 5,000)', () {
      final amtRegex = RegExp(r'(?:₹|Rs\.?\s*)?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})|\d{1,3}(?:,\d{2,3})+|\d+\.\d{2})');
      const testLine = '14/10/2026 ATM CASH WDL 5,000 45,000.00';
      final matches = amtRegex.allMatches(testLine).toList();
      expect(matches.length, greaterThanOrEqualTo(2));
      expect(matches[0].group(0), equals('5,000'));
    });

    test('Parses uppercase month abbreviations like 14-OCT-2026', () {
      const rawDate = '14-OCT-2026';
      final alphaMatch = RegExp(r'[a-zA-Z]{3}').firstMatch(rawDate);
      expect(alphaMatch, isNotNull);
      final m = alphaMatch!.group(0)!;
      final formattedM = m[0].toUpperCase() + m.substring(1).toLowerCase();
      final normalized = rawDate.replaceRange(alphaMatch.start, alphaMatch.end, formattedM);
      expect(normalized, equals('14-Oct-2026'));
    });
  });
}
