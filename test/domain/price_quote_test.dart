import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/domain/models/price_reference.dart';

import '../helpers/price.dart';

void main() {
  group('PriceQuote', () {
    test('the price per base unit is per LITRE for a soft drink', () {
      // 4200 ml for R$ 48,00 is R$ 11,43 a litre — the head of the wireframe's
      // table.
      final line = quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3));

      expect(line.costPerBaseUnit, 1143);
    });

    test('and per KILO for something sold by weight', () {
      // 1500 g for R$ 45,00 is R$ 30,00 a kilo.
      final line = meatQuote(
        quantity: 1500,
        cents: 4500,
        on: DateTime(2026, 8, 10),
      );

      expect(line.costPerBaseUnit, 3000);
    });

    test('it hands the ids and the day over without repeating the fields', () {
      final line = quote(
        quantity: 4200,
        cents: 6200,
        on: DateTime(2026, 8, 18),
        store: grocery,
      );

      expect(line.productId, 'prod-4');
      expect(line.productTypeId, 'type-1');
      expect(line.purchasedOn, DateTime(2026, 8, 18));
      expect(line.paid, const Money(6200));
      // The store came DEACTIVATED and stayed that way: the `==` of the quote
      // depends on it, and the fake and the database have to agree.
      expect(line.store.active, isFalse);
    });

    test('== covers every field, so Riverpod can filter an update', () {
      PriceQuote line({
        int cents = 6200,
        String categoryId = 'cat-1',
        String categoryName = 'Bebidas',
      }) => PriceQuote(
        option: cokeCrate,
        categoryId: categoryId,
        categoryName: categoryName,
        store: carrefour,
        price: PriceReference(
          paid: Money(cents),
          quantityInBaseUnit: 4200,
          purchasedOn: DateTime(2026, 8, 18),
        ),
      );

      expect(line(), line());
      expect(line().hashCode, line().hashCode);
      expect(line(), isNot(line(cents: 6300)));
      expect(line(), isNot(line(categoryId: 'cat-2')));
      expect(line(), isNot(line(categoryName: 'Carnes')));
      expect(
        line(),
        isNot(
          PriceQuote(
            option: cokeCan,
            categoryId: 'cat-1',
            categoryName: 'Bebidas',
            store: carrefour,
            price: PriceReference(
              paid: const Money(6200),
              quantityInBaseUnit: 4200,
              purchasedOn: DateTime(2026, 8, 18),
            ),
          ),
        ),
      );
      expect(
        line(),
        isNot(
          PriceQuote(
            option: cokeCrate,
            categoryId: 'cat-1',
            categoryName: 'Bebidas',
            store: streetMarket,
            price: PriceReference(
              paid: const Money(6200),
              quantityInBaseUnit: 4200,
              purchasedOn: DateTime(2026, 8, 18),
            ),
          ),
        ),
      );
    });

    test('toString names the leaf, the store and the unit price', () {
      final line = quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3));

      expect(
        line.toString(),
        'PriceQuote(Coca-Cola 12 × 350 ml @ Carrefour, 1143)',
      );
    });
  });
}
