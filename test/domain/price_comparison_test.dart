import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/price_comparison.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/domain/models/store.dart';

import '../helpers/price.dart';

void main() {
  // The written story of the wireframe: one crate in three stores, plus the
  // single can that turns the type view of the Carrefour inside out.
  IList<PriceQuote> theWireframe() => [
    quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
    quote(
      store: streetMarket,
      quantity: 4200,
      cents: 5670,
      on: DateTime(2026, 8, 12),
    ),
    quote(store: grocery, quantity: 4200, cents: 6200, on: DateTime(2026, 8, 18)),
    quote(option: cokeCan, quantity: 350, cents: 525, on: DateTime(2026, 8, 20)),
  ].lock;

  group('buildComparison — Este produto', () {
    test('one line per store, cheapest first, with the day beside it', () {
      final lines = buildComparison(
        quotes: theWireframe(),
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.map((line) => line.store.name).toList(), [
        'Carrefour',
        'Feira do Bairro',
        'Mercearia do Zé',
      ]);
      expect(lines.map((line) => line.costPerBaseUnit).toList(), [
        1143,
        1350,
        1476,
      ]);
      // The date INFORMS: the cheapest is the OLDEST of the three, and the
      // list is still ordered by price.
      expect(lines.first.purchasedOn, DateTime(2026, 7, 3));
      expect(lines.first.baseUnit, BaseUnit.liter);
    });

    test('the can of the same type is NOT in it — brand with brand', () {
      final lines = buildComparison(
        quotes: theWireframe(),
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      // The can was bought at the Carrefour on 20/08, later than the crate,
      // and the Carrefour line still shows the CRATE's price.
      expect(lines.first.costPerBaseUnit, 1143);
      expect(lines, hasLength(3));
    });

    test('the MOST RECENT purchase of each store is the one that speaks', () {
      final lines = buildComparison(
        quotes: [
          quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
          quote(quantity: 4200, cents: 7000, on: DateTime(2026, 8, 25)),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines, hasLength(1));
      // R$ 70,00 for 4200 ml — never the average of the two.
      expect(lines.single.costPerBaseUnit, 1667);
      expect(lines.single.purchasedOn, DateTime(2026, 8, 25));
    });

    test('a store with no purchase of the product does not appear', () {
      final lines = buildComparison(
        quotes: [
          quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
          // Another leaf entirely, in another store.
          meatQuote(
            store: streetMarket,
            quantity: 1500,
            cents: 4500,
            on: DateTime(2026, 8, 10),
          ),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.map((line) => line.store.name).toList(), ['Carrefour']);
    });

    test('a quote from outside the window does not get in either', () {
      // The `select` already filtered by the window; this fixes that a quote
      // arriving from anywhere else is compared like every other one, and
      // that the most recent of the store is what wins.
      final lines = buildComparison(
        quotes: [
          quote(quantity: 4200, cents: 2000, on: DateTime(2025, 12, 20)),
          quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.single.costPerBaseUnit, 1143);
    });

    test('a leaf never bought in the window shows nothing at all', () {
      expect(
        buildComparison(
          quotes: theWireframe(),
          selected: groundBeef,
          scope: ComparisonScope.thisProduct,
        ),
        isEmpty,
      );
    });

    test('a leaf with no brand STAYS on the leaf (decision D-v)', () {
      // Unlike H15: here climbing to the type is one tap away, and it is the
      // user who takes it.
      final quotes = [
        meatQuote(quantity: 1500, cents: 4500, on: DateTime(2026, 8, 10)),
        // Another leaf of the SAME type, and cheaper — it must not show up.
        meatQuote(
          option: otherBeefLeaf,
          store: streetMarket,
          quantity: 2000,
          cents: 5000,
          on: DateTime(2026, 8, 12),
        ),
      ].lock;

      final lines = buildComparison(
        quotes: quotes,
        selected: groundBeef,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.map((line) => line.store.name).toList(), ['Carrefour']);
      expect(lines.single.costPerBaseUnit, 3000);
    });

    test('a leaf that was never written has nothing to compare', () {
      expect(
        buildComparison(
          quotes: theWireframe(),
          selected: unsavedLeaf,
          scope: ComparisonScope.thisProduct,
        ),
        isEmpty,
      );
    });
  });

  group('buildComparison — Tipo inteiro', () {
    test('it ignores brand and packaging and turns the Carrefour around', () {
      // The most recent Refrigerante at the Carrefour is the single CAN of
      // 20/08, at R$ 15,00 a litre: the cheapest store becomes the dearest.
      final lines = buildComparison(
        quotes: theWireframe(),
        selected: cokeCrate,
        scope: ComparisonScope.wholeType,
      );

      expect(lines.map((line) => line.store.name).toList(), [
        'Feira do Bairro',
        'Mercearia do Zé',
        'Carrefour',
      ]);
      expect(lines.last.costPerBaseUnit, 1500);
      expect(lines.last.purchasedOn, DateTime(2026, 8, 20));
    });

    test('one line per STORE, never one per store × product (D-o)', () {
      final lines = buildComparison(
        quotes: theWireframe(),
        selected: cokeCrate,
        scope: ComparisonScope.wholeType,
      );

      expect(lines, hasLength(3));
      expect(
        lines.map((line) => line.store.id).toSet(),
        {'store-1', 'store-2', 'store-3'},
      );
    });

    test('the leaf with no brand DOES climb when the user asks it to', () {
      final quotes = [
        meatQuote(quantity: 1500, cents: 4500, on: DateTime(2026, 8, 10)),
        meatQuote(
          option: otherBeefLeaf,
          store: streetMarket,
          quantity: 2000,
          cents: 5000,
          on: DateTime(2026, 8, 12),
        ),
      ].lock;

      final lines = buildComparison(
        quotes: quotes,
        selected: groundBeef,
        scope: ComparisonScope.wholeType,
      );

      // R$ 25,00 a kilo at the street market against R$ 30,00 at the
      // Carrefour.
      expect(lines.map((line) => line.store.name).toList(), [
        'Feira do Bairro',
        'Carrefour',
      ]);
    });

    test('two purchases of the same DAY in one store: the cheaper stays', () {
      // Possible here and only here: the crate and the can may have come in
      // the same purchase, and the answer must not be whatever order the
      // `select` happened to return.
      final dearerFirst = buildComparison(
        quotes: [
          quote(option: cokeCan, quantity: 350, cents: 525, on: DateTime(2026, 8, 20)),
          quote(quantity: 4200, cents: 6200, on: DateTime(2026, 8, 20)),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.wholeType,
      );
      final cheaperFirst = buildComparison(
        quotes: [
          quote(quantity: 4200, cents: 6200, on: DateTime(2026, 8, 20)),
          quote(option: cokeCan, quantity: 350, cents: 525, on: DateTime(2026, 8, 20)),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.wholeType,
      );

      // Both orders answer the crate's R$ 14,76/L, and never the can's
      // R$ 15,00/L: the answer is the screen's promise, not the order the
      // `select` happened to return.
      expect(dearerFirst.single.costPerBaseUnit, 1476);
      expect(cheaperFirst.single.costPerBaseUnit, 1476);
    });

    test('a type never bought in the window shows nothing', () {
      expect(
        buildComparison(
          quotes: theWireframe(),
          selected: groundBeef,
          scope: ComparisonScope.wholeType,
        ),
        isEmpty,
      );
    });
  });

  group('the ordering', () {
    ComparisonLine lineOf(IList<ComparisonLine> lines, String store) =>
        lines.firstWhere((line) => line.store.name == store);

    test('a tie on the price goes to the most RECENT purchase', () {
      final lines = buildComparison(
        quotes: [
          quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
          quote(
            store: streetMarket,
            quantity: 4200,
            cents: 4800,
            on: DateTime(2026, 8, 12),
          ),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.first.store.name, 'Feira do Bairro');
      expect(lineOf(lines, 'Carrefour').costPerBaseUnit, 1143);
    });

    test('a tie on price and day goes to the normalized NAME', () {
      // Normalized, or 'Água' would land after 'Bebidas' — Dart compares code
      // units.
      final lines = buildComparison(
        quotes: [
          quote(
            store: Store(id: 'store-9', name: 'Bebidas Center'),
            quantity: 4200,
            cents: 4800,
            on: DateTime(2026, 7, 3),
          ),
          quote(
            store: Store(id: 'store-8', name: 'Água & Cia'),
            quantity: 4200,
            cents: 4800,
            on: DateTime(2026, 7, 3),
          ),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.map((line) => line.store.name).toList(), [
        'Água & Cia',
        'Bebidas Center',
      ]);
    });

    test('a tie on everything goes to the id, so the order is STABLE', () {
      final lines = buildComparison(
        quotes: [
          quote(
            store: Store(id: 'store-9', name: 'Mercado'),
            quantity: 4200,
            cents: 4800,
            on: DateTime(2026, 7, 3),
          ),
          quote(
            store: Store(id: 'store-2', name: 'Mercado'),
            quantity: 4200,
            cents: 4800,
            on: DateTime(2026, 7, 3),
          ),
        ].lock,
        selected: cokeCrate,
        scope: ComparisonScope.thisProduct,
      );

      expect(lines.map((line) => line.store.id).toList(), [
        'store-2',
        'store-9',
      ]);
    });
  });

  group('ComparisonLine', () {
    ComparisonLine line({Store? store, int cents = 1143, DateTime? on}) =>
        ComparisonLine(
          store: store ?? carrefour,
          costPerBaseUnit: cents,
          baseUnit: BaseUnit.liter,
          purchasedOn: on ?? DateTime(2026, 7, 3),
        );

    test('== covers every field', () {
      expect(line(), line());
      expect(line().hashCode, line().hashCode);
      expect(line(), isNot(line(cents: 1144)));
      expect(line(), isNot(line(store: streetMarket)));
      expect(line(), isNot(line(on: DateTime(2026, 7, 4))));
      expect(
        line(),
        isNot(
          ComparisonLine(
            store: carrefour,
            costPerBaseUnit: 1143,
            baseUnit: BaseUnit.kilogram,
            purchasedOn: DateTime(2026, 7, 3),
          ),
        ),
      );
    });

    test('toString names the store, the price and the day', () {
      expect(line().toString(), contains('Carrefour'));
      expect(line().toString(), contains('1143'));
    });
  });

  group('ComparisonScope', () {
    test('the labels are the two the wireframe draws, in pt-BR', () {
      expect(ComparisonScope.thisProduct.label, 'Este produto');
      expect(ComparisonScope.wholeType.label, 'Tipo inteiro');
    });
  });

  group('distinctOptionsOf', () {
    test('a leaf bought in three stores appears ONCE', () {
      final options = distinctOptionsOf(theWireframe());

      expect(options.map((option) => option.id).toList(), [
        'prod-4',
        'prod-1',
      ]);
    });

    test('an empty window offers nothing to pick', () {
      expect(distinctOptionsOf(const IList.empty()), isEmpty);
    });
  });

  group('categoryNamesOf', () {
    test('it answers one name per category, whatever the repetition', () {
      final names = categoryNamesOf([
        ...theWireframe(),
        meatQuote(quantity: 1500, cents: 4500, on: DateTime(2026, 8, 10)),
      ].lock);

      expect(names.unlock, {'cat-1': 'Bebidas', 'cat-2': 'Carnes'});
    });
  });

  group('buildComparisonGroups', () {
    test('groups by CATEGORY, alphabetical inside and between', () {
      final quotes = [
        ...theWireframe(),
        meatQuote(quantity: 1500, cents: 4500, on: DateTime(2026, 8, 10)),
      ].lock;

      final groups = buildComparisonGroups(
        options: distinctOptionsOf(quotes),
        categoryNames: categoryNamesOf(quotes),
      );

      expect(groups.map((group) => group.header).toList(), [
        'Bebidas',
        'Carnes',
      ]);
      // Alphabetical INSIDE the group, unlike screen 3, which is by what gets
      // bought most (C1): here the question is "find it in a growing list".
      expect(
        groups.first.options.map((option) => option.label).toList(),
        ['Coca-Cola 12 × 350 ml', 'Coca-Cola 350 ml'],
      );
      expect(groups.last.options.single.label, 'Acém moído (peso)');
    });

    test('an empty selection groups into nothing', () {
      expect(
        buildComparisonGroups(
          options: const IList.empty(),
          categoryNames: const IMap.empty(),
        ),
        isEmpty,
      );
    });
  });
}
