import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_reference.dart';

void main() {
  // Never DateTime.now(): a fixed instant, always.
  final day = DateTime(2026, 8, 18);

  PriceReference reference(int cents, int quantity) => PriceReference(
    paid: Money(cents),
    quantityInBaseUnit: quantity,
    purchasedOn: day,
  );

  group('estimateFor', () {
    test('gives back exactly what was paid for the same quantity', () {
      // The case the whole class exists for: 12 L for R$ 62,00 is R$ 5,1667 a
      // litre, and a rounded 517 cents/L would answer R$ 62,04 for the very
      // same purchase — four cents off the receipt in the person's hand.
      final twelveLiters = reference(6200, 12000);

      expect(twelveLiters.estimateFor(12000), const Money(6200));
      expect(
        twelveLiters.costPerBaseUnit(BaseUnit.milliliter),
        517,
        reason: 'the rounded price per litre, which is NOT what pre-fills',
      );
    });

    test('scales by the rule of three', () {
      final oneLiter = reference(600, 1000);

      expect(oneLiter.estimateFor(2000), const Money(1200));
      expect(oneLiter.estimateFor(500), const Money(300));
    });

    test('rounds half up on the last cent', () {
      // 3 pieces of a 1000 for 1001 cents: 1001/3 = 333.67 -> 334.
      final three = reference(1001, 3000);
      expect(three.estimateFor(1000), const Money(334));

      // Exactly one half: 5 cents for 2 -> 2.5 -> 3, never 2.
      final half = reference(5, 2000);
      expect(half.estimateFor(1000), const Money(3));
    });

    test('the "compre 2 leve 3" is a plain division, with no markup', () {
      // Three packagings for the price of two: the cost per base unit falls
      // out of the division, and nothing anywhere marks the promotion.
      final threeForTwo = reference(1000, 3 * 350);

      expect(threeForTwo.costPerBaseUnit(BaseUnit.milliliter), 952);
      // The next purchase of a single one is estimated at a third.
      expect(threeForTwo.estimateFor(350), const Money(333));
    });

    test('a quantity of zero estimates nothing', () {
      // The screen calls this while the Quantity field is still empty.
      expect(reference(6200, 12000).estimateFor(0), Money.zero);
      expect(reference(6200, 12000).estimateFor(-1), Money.zero);
    });
  });

  group('costPerBaseUnit', () {
    test('answers per kilo, per litre and per unit', () {
      // 2 kg for R$ 40,00 -> 2000 cents a kilo.
      expect(reference(4000, 2000).costPerBaseUnit(BaseUnit.gram), 2000);
      // 12 units for R$ 24,00 -> 200 cents each, and a unit is its own
      // smallest unit.
      expect(reference(2400, 12).costPerBaseUnit(BaseUnit.unit), 200);
    });
  });

  test('refuses a reference with no quantity', () {
    // The schema refuses it too (`quantity_in_base_unit > 0`), so a zero here
    // is corrupt data or a bug of ours — an Error, never a silent zero.
    expect(
      () => reference(6200, 0),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => reference(6200, -1), throwsA(isA<ArgumentError>()));
  });

  test('equality covers every field, so Riverpod can filter an update', () {
    expect(reference(6200, 12000), reference(6200, 12000));
    expect(reference(6200, 12000).hashCode, reference(6200, 12000).hashCode);

    expect(reference(6200, 12000), isNot(reference(6201, 12000)));
    expect(reference(6200, 12000), isNot(reference(6200, 12001)));
    expect(
      reference(6200, 12000),
      isNot(
        PriceReference(
          paid: const Money(6200),
          quantityInBaseUnit: 12000,
          purchasedOn: DateTime(2026, 8, 17),
        ),
      ),
    );
    expect(reference(6200, 12000).toString(), contains('6200'));
  });
}
