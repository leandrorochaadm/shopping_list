import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_summary.dart';

/// One line of the history. The `==` is not hygiene here: it travels inside
/// the `T` of an AsyncNotifier, and the case that swaps ONE field at a time
/// is what fails the day a seventh field is added and left out of it.
void main() {
  PurchaseSummary summary({
    String id = 'a1',
    DateTime? date,
    String storeName = 'Carrefour',
    String registeredBy = 'Leandro',
    int cents = 31245,
    int itemCount = 4,
  }) => PurchaseSummary(
    id: id,
    purchaseDate: date ?? DateTime(2026, 8, 28),
    storeName: storeName,
    registeredBy: registeredBy,
    total: Money(cents),
    itemCount: itemCount,
  );

  group('fromJson', () {
    test('adds the items up in Dart and counts them (D9)', () {
      final read = PurchaseSummary.fromJson({
        'id': 'a1',
        'purchase_date': '2026-08-28',
        'registered_by': 'Leandro',
        'store': {'name': 'Carrefour'},
        'purchase_item': [
          {'total_paid': 6200},
          {'total_paid': 4750},
        ],
      });

      expect(read.total, const Money(10950));
      expect(read.itemCount, 2);
      expect(read.storeName, 'Carrefour');
      expect(read.purchaseDate, DateTime(2026, 8, 28));
    });

    test('a purchase with no item is a zero total, not a crash', () {
      final read = PurchaseSummary.fromJson({
        'id': 'a1',
        'purchase_date': '2026-08-28',
        'registered_by': 'Leandro',
        'store': {'name': 'Feira'},
        'purchase_item': <Map<String, dynamic>>[],
      });

      expect(read.total, Money.zero);
      expect(read.itemCount, 0);
    });

    test('a missing embed still draws a line', () {
      // The history that ends at the first odd row is worse than a blank
      // store name on one of them.
      final read = PurchaseSummary.fromJson({
        'id': 'a1',
        'purchase_date': '2026-08-28',
      });

      expect(read.storeName, '');
      expect(read.registeredBy, '');
      expect(read.total, Money.zero);
    });
  });

  group('== and hashCode cover every field (rule 8)', () {
    test('two summaries with the same fields are equal', () {
      expect(summary(), summary());
      expect(summary().hashCode, summary().hashCode);
    });

    test('one field at a time breaks it', () {
      expect(summary(), isNot(summary(id: 'a2')));
      expect(summary(), isNot(summary(date: DateTime(2026, 8, 27))));
      expect(summary(), isNot(summary(storeName: 'Feira')));
      expect(summary(), isNot(summary(registeredBy: 'esposa')));
      expect(summary(), isNot(summary(cents: 31246)));
      expect(summary(), isNot(summary(itemCount: 5)));
    });
  });

  test('toString names the day, the store and the total', () {
    expect(summary().toString(), contains('2026-08-28'));
    expect(summary().toString(), contains('Carrefour'));
    expect(summary().toString(), contains('31245'));
  });
}
