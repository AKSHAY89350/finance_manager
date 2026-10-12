import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/services/sms_parser_service.dart';
import 'package:finance_manager/services/merchant_categorizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9 - SMS Parser & Categorizer Tests', () {
    test('Debit Expense: Zomato Alert', () async {
      const msg = 'Rs 450.00 debited from A/c XX4589 on 12-Oct-26 to ZOMATO. Avl Bal: Rs 45,210.00';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 450.0);
      expect(parsed.merchant.toUpperCase(), contains('ZOMATO'));
      expect(parsed.suggestedCategory, 'Food');
      expect(parsed.suggestedSubCategory, 'Zomato / Swiggy');
    });

    test('Debit Expense: Blinkit Alert', () async {
      const msg = 'INR 1,299 debited from card ending 1024 for BLINKIT ref 429817291827';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 1299.0);
      expect(parsed.merchant.toUpperCase(), contains('BLINKIT'));
      expect(parsed.suggestedCategory, 'Quick Ecommerce');
      expect(parsed.suggestedSubCategory, 'Blinkit');
      expect(parsed.refId, '429817291827');
    });

    test('UPI App Debit: Chai Point', () async {
      const msg = 'Paid INR 75.00 to Chai Point via UPI ref 8921739182';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 75.0);
      expect(parsed.merchant, contains('Chai Point'));
      expect(parsed.suggestedCategory, 'Food');
      expect(parsed.suggestedSubCategory, 'Cafe & Snacks');
    });

    test('Credit Income: Salary Alert', () async {
      const msg = 'Rs 85,000.00 credited to A/c XX4589 on 01-Oct-26 by NEOSOFT SALARY. Avl Bal: Rs 1,20,500.00';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'INCOME');
      expect(parsed.amount, 85000.0);
      expect(parsed.merchant.toUpperCase(), contains('NEOSOFT SALARY'));
    });

    test('Anti-Noise Shield: OTP Discarded', () async {
      const otpMsg = 'Your HDFC Bank OTP is 482910 for txn of Rs 500. Do not share with anyone.';
      final parsed = await SmsParserService.parseMessage(otpMsg);
      expect(parsed, isNull);
    });

    test('Anti-Noise Shield: Promotional Loan Discarded', () async {
      const promoMsg = 'Congratulations! Pre-approved personal loan of Rs 5,00,000 at zero processing fee. Apply now.';
      final parsed = await SmsParserService.parseMessage(promoMsg);
      expect(parsed, isNull);
    });

    test('Anti-Noise Shield: Oversized Payload (>1000 chars) Discarded for ReDoS Prevention', () async {
      final oversizedMsg = 'Rs 500 debited to Zomato ${'A' * 1100}';
      final parsed = await SmsParserService.parseMessage(oversizedMsg);
      expect(parsed, isNull);
    });

    test('Debit Expense: Rupee symbol and Clean Merchant Name', () async {
      const msg = '₹ 450.00 debited from A/c XX4589 on 12-Oct-26 to ZOMATO. Avl Bal: Rs 45,210.00';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 450.0);
      expect(parsed.merchant, 'ZOMATO');
      expect(parsed.suggestedCategory, 'Food');
      expect(parsed.suggestedSubCategory, 'Zomato / Swiggy');
    });

    test('SBI Account-First Pattern with towards', () async {
      const msg = 'SBI: A/c *1234 debited by Rs.999.00 on 12-10-26 towards SWIGGY. Avl Bal Rs.25000';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 999.0);
      expect(parsed.accountDigits, '1234');
      expect(parsed.merchant, 'SWIGGY');
      expect(parsed.bank, 'SBI');
      expect(parsed.suggestedCategory, 'Food');
      expect(parsed.suggestedSubCategory, 'Zomato / Swiggy');
    });

    test('In-Body Bank Name Detection and Card Ending Format', () async {
      const msg = 'ICICI Bank: ₹ 1,500.00 spent on card ending 4589 to AMAZON ref 998877';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'EXPENSE');
      expect(parsed.amount, 1500.0);
      expect(parsed.bank, 'ICICI');
      expect(parsed.merchant, 'AMAZON');
      expect(parsed.accountDigits, '4589');
      expect(parsed.refId, '998877');
    });

    test('Preposition prefix stripping (towards Electricity Bill)', () async {
      const msg = 'Rs 1,250 debited from A/c XX1234 towards Electricity Bill';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.0);
      expect(parsed.merchant, 'Electricity Bill');
      expect(parsed.suggestedCategory, 'Bills & Utilities');
    });

    test('Credit Income: Rupee symbol and In-Body Bank Detection', () async {
      const msg = 'PNB: ₹ 45,000.00 credited to A/c XX4589 by FREELANCE. Avl Bal: Rs 65,000.00';
      final parsed = await SmsParserService.parseMessage(msg);

      expect(parsed, isNotNull);
      expect(parsed!.type, 'INCOME');
      expect(parsed.amount, 45000.0);
      expect(parsed.bank, 'PNB');
      expect(parsed.merchant, 'FREELANCE');
    });

    test('Merchant Categorizer Seed Keywords', () async {
      final uber = await MerchantCategorizer.categorize('UBER TRIP');
      expect(uber.$1, 'Traveling');

      final zerodha = await MerchantCategorizer.categorize('ZERODHA BROKING');
      expect(zerodha.$1, 'SIP & Investments');

      final jio = await MerchantCategorizer.categorize('JIO RECHARGE');
      expect(jio.$1, 'Bills & Utilities');
    });
  });
}
