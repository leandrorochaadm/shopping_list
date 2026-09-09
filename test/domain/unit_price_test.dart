import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/unit_price.dart';

void main() {
  group('pricePerLargeUnitOf', () {
    test('turns what was paid into the price of one kilo', () {
      expect(
        pricePerLargeUnitOf(
          paid: const Money(1995),
          quantityInBaseUnit: 500,
          unit: BaseUnit.gram,
        ),
        const Money(3990),
      );
    });

    test('prices the litre, the metre and the unit by the same rule', () {
      expect(
        pricePerLargeUnitOf(
          paid: const Money(699),
          quantityInBaseUnit: 2000,
          unit: BaseUnit.milliliter,
        ),
        const Money(350),
      );
      expect(
        pricePerLargeUnitOf(
          paid: const Money(1200),
          quantityInBaseUnit: 300,
          unit: BaseUnit.centimeter,
        ),
        const Money(400),
      );
      // The count has no large unit: the price of one unit is the division.
      expect(
        pricePerLargeUnitOf(
          paid: const Money(900),
          quantityInBaseUnit: 3,
          unit: BaseUnit.unit,
        ),
        const Money(300),
      );
    });

    test('rounds half up, and never through a double', () {
      // R$ 62,00 for 4200 ml is R$ 14,7619… a litre.
      expect(
        pricePerLargeUnitOf(
          paid: const Money(6200),
          quantityInBaseUnit: 4200,
          unit: BaseUnit.milliliter,
        ),
        const Money(1476),
      );
      // Exactly half a cent goes up: R$ 0,015 a kilo.
      expect(
        pricePerLargeUnitOf(
          paid: const Money(3),
          quantityInBaseUnit: 2000,
          unit: BaseUnit.gram,
        ),
        const Money(2),
      );
    });

    test('is null when there is nothing to divide', () {
      expect(
        pricePerLargeUnitOf(
          paid: const Money(1000),
          quantityInBaseUnit: 0,
          unit: BaseUnit.gram,
        ),
        isNull,
      );
      expect(
        pricePerLargeUnitOf(
          paid: Money.zero,
          quantityInBaseUnit: 500,
          unit: BaseUnit.gram,
        ),
        isNull,
      );
    });
  });

  group('paidAtPricePerLargeUnit', () {
    test('turns the price of one kilo into what the amount costs', () {
      expect(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: const Money(3990),
          quantityInBaseUnit: 500,
          unit: BaseUnit.gram,
        ),
        const Money(1995),
      );
    });

    test('rounds half up', () {
      // R$ 14,76 a litre over 4200 ml is R$ 61,992.
      expect(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: const Money(1476),
          quantityInBaseUnit: 4200,
          unit: BaseUnit.milliliter,
        ),
        const Money(6199),
      );
    });

    test('is null when there is nothing to multiply', () {
      expect(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: const Money(3990),
          quantityInBaseUnit: 0,
          unit: BaseUnit.gram,
        ),
        isNull,
      );
      expect(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: Money.zero,
          quantityInBaseUnit: 500,
          unit: BaseUnit.gram,
        ),
        isNull,
      );
    });

    test('goes back to the same money when the division was exact', () {
      const paid = Money(1995);
      final perKilo = pricePerLargeUnitOf(
        paid: paid,
        quantityInBaseUnit: 500,
        unit: BaseUnit.gram,
      )!;
      expect(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: perKilo,
          quantityInBaseUnit: 500,
          unit: BaseUnit.gram,
        ),
        paid,
      );
    });
  });
}
