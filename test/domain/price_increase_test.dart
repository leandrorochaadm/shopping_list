import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_increase.dart';

/// One line of the window, as `PurchaseHistoryEntry` hands it over.
final class _Line implements PurchaseBaselineLine {
  const _Line({
    required this.productId,
    required this.productTypeId,
    required this.quantityInBaseUnit,
    required this.paid,
  });

  @override
  final String productId;
  @override
  final String productTypeId;
  @override
  final int quantityInBaseUnit;
  @override
  final Money paid;
}

void main() {
  // 12 × 350 ml for R$ 62,00 — R$ 14,7619 a litre. Every case below compares
  // against this one.
  PriceBaseline crate() =>
      PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 4200);

  group('PriceBaseline', () {
    test('refuses a non-positive quantity, like every other average', () {
      expect(
        () => PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 0),
        throwsArgumentError,
      );
      expect(
        () => PriceBaseline(paid: const Money(6200), quantityInBaseUnit: -1),
        throwsArgumentError,
      );
    });

    test('the average is WEIGHTED — requirement 4, word for word', () {
      // 5 kg at R$ 30 a kilo plus 1 kg at R$ 42 a kilo is R$ 32,00 a kilo,
      // and NOT the R$ 36 an average of averages gives.
      final average = PriceBaseline(
        paid: const Money(15000),
        quantityInBaseUnit: 5000,
      ).plus(const Money(4200), 1000);

      expect(average.paid, const Money(19200));
      expect(average.quantityInBaseUnit, 6000);
      expect(average.costPerBaseUnit(BaseUnit.gram), 3200);
    });

    test('cents per base unit round half-up, in both units', () {
      // 4200 ml for 6200 cents is 1476,19 cents a litre.
      expect(crate().costPerBaseUnit(BaseUnit.milliliter), 1476);
      // 1500 g for 4500 cents is exactly 3000 cents a kilo.
      expect(
        PriceBaseline(
          paid: const Money(4500),
          quantityInBaseUnit: 1500,
        ).costPerBaseUnit(BaseUnit.gram),
        3000,
      );
    });

    test('== covers both fields, and hashCode goes with it', () {
      expect(crate(), crate());
      expect(crate().hashCode, crate().hashCode);
      expect(
        crate(),
        isNot(PriceBaseline(paid: const Money(6300), quantityInBaseUnit: 4200)),
      );
      expect(
        crate(),
        isNot(PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 4300)),
      );
    });

    test('toString says the pair, never a rounded unit price', () {
      expect(crate().toString(), 'PriceBaseline(6200 for 4200)');
    });
  });

  group('evaluatePriceIncrease', () {
    PriceIncrease? rise(int cents, {int quantity = 4200}) =>
        evaluatePriceIncrease(
          baseline: crate(),
          paid: Money(cents),
          quantityInBaseUnit: quantity,
        );

    test('exactly at the threshold DOES alert', () {
      // 6200 + 10% is 6820 — the boundary case, and it is inclusive.
      final increase = rise(6820);

      expect(increase, isNotNull);
      expect(increase!.percentage, priceIncreaseThreshold);
      expect(increase.baseline, crate());
    });

    test('just under the threshold stays quiet, even rounding to ten', () {
      // 6819 cents is +9,98%, which rounds to 10 — and does NOT alert
      // (decision D-s): the cut is over the full value.
      expect(rise(6819), isNull);
      // +9,6%, the case the decision is written about.
      expect(rise(6795), isNull);
    });

    test('the percentage is rounded half-up over the full value', () {
      // 7000 over 6200 is +12,90%, which shows as 13.
      expect(rise(7000)!.percentage, 13);
      // 7362,5 does not exist in cents; 7363 is +18,758%, which shows as 19.
      expect(rise(7363)!.percentage, 19);
      // The story of the fake: R$ 70,00 against an average of R$ 14,51/L.
      expect(
        evaluatePriceIncrease(
          baseline: PriceBaseline(
            paid: const Money(12190),
            quantityInBaseUnit: 8400,
          ),
          paid: const Money(7000),
          quantityInBaseUnit: 4200,
        )!.percentage,
        15,
      );
    });

    test('a fall never alerts — the alert is one-sided', () {
      expect(rise(5000), isNull);
      expect(rise(6199), isNull);
      expect(rise(6200), isNull);
    });

    test('with no baseline the system stays QUIET', () {
      // The written criterion: a product never bought in the window is not
      // compared with a similar one.
      expect(
        evaluatePriceIncrease(
          baseline: null,
          paid: const Money(9900),
          quantityInBaseUnit: 4200,
        ),
        isNull,
      );
    });

    test('a quantity not typed yet stays quiet', () {
      expect(rise(9900, quantity: 0), isNull);
      expect(rise(9900, quantity: -1), isNull);
    });

    test('a value not typed yet stays quiet', () {
      expect(rise(0), isNull);
    });

    test('a bigger package at the same unit price does not alert', () {
      // Two crates for R$ 124,00 is the very same price per litre.
      expect(rise(12400, quantity: 8400), isNull);
    });

    test('the integers hold a big purchase without overflowing in dart2js', () {
      // 30 kg accumulated against a R$ 600,00 purchase: excess × 100 × 2 is
      // still five orders of magnitude below 2^53.
      final increase = evaluatePriceIncrease(
        baseline: PriceBaseline(
          paid: const Money(60000),
          quantityInBaseUnit: 30000,
        ),
        paid: const Money(60000),
        quantityInBaseUnit: 20000,
      );

      expect(increase!.percentage, 50);
    });
  });

  group('PriceIncrease', () {
    test('message and toString read the percentage it carries', () {
      final increase = evaluatePriceIncrease(
        baseline: crate(),
        paid: const Money(7000),
        quantityInBaseUnit: 4200,
      )!;

      expect(increase.message, 'Subiu 13% sobre a média');
      expect(increase.toString(), 'PriceIncrease(13%)');
    });

    test('== covers both fields', () {
      final one = PriceIncrease(percentage: 13, baseline: crate());
      final same = PriceIncrease(percentage: 13, baseline: crate());
      final other = PriceIncrease(percentage: 14, baseline: crate());
      final another = PriceIncrease(
        percentage: 13,
        baseline: PriceBaseline(paid: const Money(6300), quantityInBaseUnit: 4200),
      );

      expect(one, same);
      expect(one.hashCode, same.hashCode);
      expect(one, isNot(other));
      expect(one, isNot(another));
    });
  });

  group('buildPriceBaselines', () {
    _Line line({
      String product = 'prod-4',
      String type = 'type-1',
      required int quantity,
      required int cents,
    }) => _Line(
      productId: product,
      productTypeId: type,
      quantityInBaseUnit: quantity,
      paid: Money(cents),
    );

    test('two purchases of the same leaf make ONE weighted average', () {
      final baselines = buildPriceBaselines([
        line(quantity: 4200, cents: 6200),
        line(quantity: 4200, cents: 5990),
      ]);

      expect(baselines.byProduct['prod-4']!.paid, const Money(12190));
      expect(baselines.byProduct['prod-4']!.quantityInBaseUnit, 8400);
      // R$ 14,51 a litre — the average the fake's story alerts against.
      expect(baselines.byProduct['prod-4']!.costPerBaseUnit(BaseUnit.milliliter), 1451);
    });

    test('two leaves of the same TYPE add up at the type level only', () {
      final baselines = buildPriceBaselines([
        line(product: 'prod-4', quantity: 4200, cents: 6200),
        line(product: 'prod-1', quantity: 350, cents: 525),
      ]);

      expect(baselines.byProduct['prod-4']!.quantityInBaseUnit, 4200);
      expect(baselines.byProduct['prod-1']!.quantityInBaseUnit, 350);
      expect(baselines.byType['type-1']!.quantityInBaseUnit, 4550);
      expect(baselines.byType['type-1']!.paid, const Money(6725));
    });

    test('two types never mix', () {
      final baselines = buildPriceBaselines([
        line(product: 'prod-4', type: 'type-1', quantity: 4200, cents: 6200),
        line(product: 'prod-5', type: 'type-2', quantity: 1500, cents: 4500),
      ]);

      expect(baselines.byType['type-1']!.quantityInBaseUnit, 4200);
      expect(baselines.byType['type-2']!.quantityInBaseUnit, 1500);
    });

    test('a corrupt line with no quantity is skipped, never thrown over', () {
      // The factory would throw; a report must not go down because of one
      // impossible row.
      final baselines = buildPriceBaselines([
        line(quantity: 0, cents: 6200),
        line(quantity: 4200, cents: 6200),
      ]);

      expect(baselines.byProduct['prod-4']!.quantityInBaseUnit, 4200);
    });

    test('an empty window builds the empty pair', () {
      final baselines = buildPriceBaselines(const []);

      expect(baselines.byProduct, isEmpty);
      expect(baselines.byType, isEmpty);
      expect(baselines, PriceBaselines.empty);
    });
  });

  group('PriceBaselines.forLeaf', () {
    final baselines = PriceBaselines(
      byProduct: {
        'prod-4': PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 4200),
      }.lock,
      byType: {
        'type-1': PriceBaseline(paid: const Money(6725), quantityInBaseUnit: 4550),
        'type-2': PriceBaseline(paid: const Money(4500), quantityInBaseUnit: 1500),
      }.lock,
    );

    test('a leaf WITH a brand compares against itself', () {
      expect(
        baselines.forLeaf(
          productId: 'prod-4',
          productTypeId: 'type-1',
          hasBrand: true,
        ),
        PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 4200),
      );
    });

    test('a leaf with NO brand climbs to the type', () {
      // Ground beef has nobody to compare itself with, and without this the
      // most bought product of the house would have no alert.
      expect(
        baselines.forLeaf(
          productId: 'prod-5',
          productTypeId: 'type-2',
          hasBrand: false,
        ),
        PriceBaseline(paid: const Money(4500), quantityInBaseUnit: 1500),
      );
    });

    test('a leaf with a brand and no history of its own stays quiet', () {
      // It does NOT fall back to the type: the brand is what decides.
      expect(
        baselines.forLeaf(
          productId: 'prod-1',
          productTypeId: 'type-1',
          hasBrand: true,
        ),
        isNull,
      );
    });

    test('a leaf that was never written has no history', () {
      expect(
        baselines.forLeaf(
          productId: null,
          productTypeId: 'type-1',
          hasBrand: true,
        ),
        isNull,
      );
      expect(
        baselines.forLeaf(productId: 'prod-4', productTypeId: null, hasBrand: false),
        isNull,
      );
    });

    test('toString says how many of each level it holds', () {
      expect(baselines.toString(), 'PriceBaselines(1 leaves, 2 types)');
    });

    test('== covers both maps', () {
      final same = PriceBaselines(
        byProduct: baselines.byProduct,
        byType: baselines.byType,
      );

      expect(baselines, same);
      expect(baselines.hashCode, same.hashCode);
      expect(baselines, isNot(PriceBaselines.empty));
      expect(
        baselines,
        isNot(PriceBaselines(byProduct: baselines.byProduct, byType: const IMap.empty())),
      );
    });
  });
}
