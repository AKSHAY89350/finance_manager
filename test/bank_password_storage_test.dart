import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/utils/constants.dart';

void main() {
  group('Bank Password Storage Logic Tests', () {
    test('AppConstants contains tableBankPasswords table identifier', () {
      expect(AppConstants.tableBankPasswords, equals('bank_passwords'));
    });

    test('Bank password list deduplication keeps most recent order', () {
      final sampleDbRecords = [
        {'bank_name': 'HDFC Bank', 'password': 'pass_latest', 'last_used': '2026-11-22T10:00:00'},
        {'bank_name': 'HDFC Bank', 'password': 'pass_older', 'last_used': '2026-11-20T10:00:00'},
        {'bank_name': 'HDFC Bank', 'password': 'pass_latest', 'last_used': '2026-11-19T10:00:00'},
      ];

      final Set<String> distinct = {};
      for (final m in sampleDbRecords) {
        final p = m['password'];
        if (p != null && p.trim().isNotEmpty) {
          distinct.add(p.trim());
        }
      }

      final list = distinct.toList();
      expect(list.length, equals(2));
      expect(list.first, equals('pass_latest'));
      expect(list[1], equals('pass_older'));
    });

    test('Masked password formatting produces clean previews', () {
      String mask(String pass) {
        if (pass.length > 4) {
          return '${pass.substring(0, 2)}${'•' * (pass.length - 4)}${pass.substring(pass.length - 2)}';
        }
        return '••••••••';
      }

      expect(mask('12345678'), equals('12••••78'));
      expect(mask('ABCD1234EF'), equals('AB••••••EF'));
      expect(mask('123'), equals('••••••••'));
    });

    test('Auto-Detect bank matches all banks, whereas specific bank matches only its own and All', () {
      bool shouldInclude(String bankFilter, String recordBank) {
        return recordBank == bankFilter || recordBank == 'All' || bankFilter == 'Auto-Detect';
      }

      // Auto-Detect includes everything
      expect(shouldInclude('Auto-Detect', 'HDFC Bank'), isTrue);
      expect(shouldInclude('Auto-Detect', 'SBI Bank'), isTrue);
      expect(shouldInclude('Auto-Detect', 'All'), isTrue);

      // Specific bank only matches its own and All
      expect(shouldInclude('HDFC Bank', 'HDFC Bank'), isTrue);
      expect(shouldInclude('HDFC Bank', 'All'), isTrue);
      expect(shouldInclude('HDFC Bank', 'SBI Bank'), isFalse);
    });
  });
}
