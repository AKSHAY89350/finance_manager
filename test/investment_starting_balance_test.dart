import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/initial_investment.dart';

void main() {
  group('Initial Investment Model & Starting Balance Tests', () {
    test('InitialInvestment model serialization toMap and fromMap', () {
      const item = InitialInvestment(
        id: 1,
        assetName: 'Mutual Funds (SIP)',
        startingBalance: 250000.0,
        category: 'SIP & Investments',
        notes: 'Zerodha Coin Folio 1234',
      );

      final map = item.toMap();
      expect(map['id'], equals(1));
      expect(map['asset_name'], equals('Mutual Funds (SIP)'));
      expect(map['starting_balance'], equals(250000.0));
      expect(map['category'], equals('SIP & Investments'));
      expect(map['notes'], equals('Zerodha Coin Folio 1234'));

      final fromDb = InitialInvestment.fromMap(map);
      expect(fromDb.id, equals(1));
      expect(fromDb.assetName, equals('Mutual Funds (SIP)'));
      expect(fromDb.startingBalance, equals(250000.0));
      expect(fromDb.notes, equals('Zerodha Coin Folio 1234'));
    });

    test('InitialInvestment copyWith updates fields properly', () {
      const item = InitialInvestment(
        id: 1,
        assetName: 'PPF',
        startingBalance: 150000.0,
      );

      final updated = item.copyWith(startingBalance: 200000.0);
      expect(updated.startingBalance, equals(200000.0));
      expect(updated.assetName, equals('PPF'));
      expect(updated.id, equals(1));
    });

    test('InitialInvestment equality comparison', () {
      const item1 = InitialInvestment(
        id: 1,
        assetName: 'Gold / SGB',
        startingBalance: 75000.0,
      );
      const item2 = InitialInvestment(
        id: 1,
        assetName: 'Gold / SGB',
        startingBalance: 75000.0,
      );
      const item3 = InitialInvestment(
        id: 2,
        assetName: 'Gold / SGB',
        startingBalance: 75000.0,
      );

      expect(item1, equals(item2));
      expect(item1 == item3, isFalse);
    });
  });
}
