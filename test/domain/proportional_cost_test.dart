import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/proportional_cost.dart';

import '../helpers/purchase.dart';

/// The cheese of the third written story: the counter one is sold by weight,
/// the sliced one comes in a 200 g package, and both add up in kilos.
final cheeseType = ProductType(
  id: 'type-9',
  name: 'Mussarela',
  categoryId: 'cat-3',
  baseUnit: BaseUnit.kilogram,
);

/// A leaf sold by piece with NO packaging — not representable in the schema
/// (decision B1), and the only reason it is built here is to prove the
/// arithmetic does not lie if one day it is.
final unpackaged = ProductOption(
  product: const Product(id: 'ghost', productRegistrationId: 'reg-ghost'),
  registration: ProductRegistration(
    id: 'reg-ghost',
    productTypeId: 'type-1',
    sellingMode: SellingMode.byPiece,
  ),
  type: softDrinkType,
);

/// Two leaves of one kilo each, so the two prices ARE the two costs per kilo
/// and the tie threshold can be walked across a cent at a time.
ProductOption kiloLeaf(String id) => optionByPiece(
  id: id,
  type: powderType,
  description: id,
  pieceSize: 1000,
  unit: MeasureUnit.gram,
);

CostRanking rank(
  IList<ProductOption> options,
  Map<String, int> cents, {
  Set<String>? selected,
  BaseUnit baseUnit = BaseUnit.liter,
  Map<String, int?> contents = const {},
}) => rankCosts(
  options: options,
  prices: {
    for (final entry in cents.entries) entry.key: Money(entry.value),
  }.lock,
  contents: contents.lock,
  selected: (selected ?? cents.keys.toSet()).lock,
  baseUnit: baseUnit,
);

void main() {
  group('contentPricedOf', () {
    test('sold by piece it is the content of the packaging', () {
      final crate = optionByPiece(id: 'prod-4', pieceCount: 12);
      expect(contentPricedOf(crate), 4200);
    });

    test('sold by weight it is the base unit itself', () {
      expect(contentPricedOf(optionByWeight(id: 'beef')), 1000);
      expect(
        contentPricedOf(optionByWeight(id: 'juice', type: softDrinkType)),
        1000,
      );
      expect(
        contentPricedOf(optionByWeight(id: 'egg', type: paperType)),
        1,
      );
    });

    test('sold by piece with no packaging falls back to the base unit', () {
      expect(contentPricedOf(unpackaged), 1000);
    });

    test('the weighed leaf uses the typed content', () {
      expect(
        contentPricedOf(optionByWeight(id: 'tray'), typedContent: 800),
        800,
      );
    });

    test('the packaged leaf ignores the typed content', () {
      final pack = optionByPiece(id: 'prod-1', pieceSize: 350);
      expect(contentPricedOf(pack, typedContent: 800), 350);
    });

    test('with no typed content the weighed leaf is still one base unit', () {
      expect(contentPricedOf(optionByWeight(id: 'tray')), 1000);
    });

    test('a typed content of zero or less divides nothing', () {
      expect(
        contentPricedOf(optionByWeight(id: 'tray'), typedContent: 0),
        1000,
      );
      expect(
        contentPricedOf(optionByWeight(id: 'tray'), typedContent: -5),
        1000,
      );
    });
  });

  group('acceptsTypedContentOf', () {
    test('the weighed leaf accepts it', () {
      expect(acceptsTypedContentOf(optionByWeight(id: 'tray')), isTrue);
    });

    test('the packaged leaf does not', () {
      expect(acceptsTypedContentOf(optionByPiece(id: 'prod-1')), isFalse);
    });

    test('the line answers the same thing — it is what the View asks', () {
      expect(
        CostLine(
          option: optionByWeight(id: 'tray'),
          selected: true,
        ).acceptsTypedContent,
        isTrue,
      );
      expect(
        CostLine(
          option: optionByPiece(id: 'prod-1'),
          selected: true,
        ).acceptsTypedContent,
        isFalse,
      );
    });
  });

  group('openingPriceOf', () {
    test('with no reference there is nothing to open with', () {
      expect(openingPriceOf(optionByPiece(id: 'prod-2')), isNull);
    });

    test('sold by piece it is what ONE package cost', () {
      // Three packs of Omo 500 g bought together for R$ 30,00 open the line
      // at R$ 10,00 — never at R$ 30,00.
      final pack = optionByPiece(
        id: 'omo-500',
        type: powderType,
        brand: omoBrand,
        pieceSize: 500,
        unit: MeasureUnit.gram,
        priceReference: reference(cents: 3000, quantityInBaseUnit: 1500),
      );
      expect(openingPriceOf(pack), const Money(1000));
    });

    test('the crate comes back at exactly what was paid', () {
      // The round trip a rounded price per litre would answer R$ 62,04 for.
      final crate = optionByPiece(
        id: 'prod-4',
        pieceCount: 12,
        priceReference: reference(cents: 6200, quantityInBaseUnit: 4200),
      );
      expect(openingPriceOf(crate), const Money(6200));
    });

    test('sold by weight it is already the price of the base unit', () {
      final beef = optionByWeight(
        id: 'prod-5',
        priceReference: reference(cents: 4500, quantityInBaseUnit: 1500),
      );
      expect(openingPriceOf(beef), const Money(3000));
    });
  });

  group('costCandidatesOf', () {
    CostCandidates candidatesOf(
      IList<ProductOption> options, {
      String? typeId = 'type-1',
      ProductOption? launching,
    }) => costCandidatesOf(
      options: options,
      typeId: typeId,
      launching: launching,
    );

    test('keeps only the leaves of the type', () {
      final options = optionsOfSoftDrinkType().add(optionByWeight(id: 'beef'));
      final candidates = candidatesOf(options);

      expect(candidates.all, hasLength(4));
      expect(candidates.all.any((option) => option.id == 'beef'), isFalse);
    });

    test('a leaf with no id stays out — it has nowhere to be typed into', () {
      final options = optionsOfSoftDrinkType().add(
        optionByPiece(id: 'x', pieceSize: 600),
      ).map((option) => option.id == 'x' ? _withoutId(option) : option).toIList();

      expect(candidatesOf(options).all, hasLength(4));
    });

    test('it does NOT re-filter active — the source is what filters', () {
      // `handoff §H19`: "um produto desativado fica de fora" — and this
      // function is not where that is decided. The panel opens over the list
      // `PurchaseRepository.fetchProductOptions` returned, and THAT query
      // filters `active` on the leaf and on the registration, in SQL
      // (`purchase_repository_remote_test.dart`, "the deactivated leaf is
      // left out"). Filtering again here would be a second place to keep in
      // step, over a flag the cut never sees changed.
      //
      // This test is the sign on the door: it fails the day somebody hands
      // the panel a list from another source, and it says where to look.
      final options = optionsOfSoftDrinkType().add(
        _deactivated(
          optionByPiece(
            id: 'prod-9',
            description: 'descontinuada',
            pieceSize: 600,
          ),
        ),
      );

      expect(candidatesOf(options).all, hasLength(5));
    });

    test('with no type chosen there is nothing to compare', () {
      final candidates = candidatesOf(
        optionsOfSoftDrinkType(),
        typeId: null,
      );

      expect(candidates.all, isEmpty);
      expect(candidates.shown, isEmpty);
      expect(candidates.canCompare, isFalse);
    });

    test('a single option does NOT show the button', () {
      final candidates = candidatesOf([optionByPiece(id: 'prod-1')].lock);
      expect(candidates.canCompare, isFalse);
    });

    test('two options do', () {
      final candidates = candidatesOf(
        [optionByPiece(id: 'prod-1'), optionByPiece(id: 'prod-3')].lock,
      );
      expect(candidates.canCompare, isTrue);
    });

    test('a lone weighed product does not habilitate it', () {
      final candidates = candidatesOf(
        [optionByWeight(id: 'beef')].lock,
        typeId: 'type-2',
      );
      expect(candidates.canCompare, isFalse);
    });

    test('two weighed products of the same type do', () {
      final candidates = candidatesOf(
        [optionByWeight(id: 'beef-1'), optionByWeight(id: 'beef-2')].lock,
        typeId: 'type-2',
      );
      expect(candidates.canCompare, isTrue);
    });

    test('the short cut is what the rolling window bought', () {
      final candidates = candidatesOf(
        optionsOfSoftDrinkType(
          can: reference(cents: 400, quantityInBaseUnit: 350),
          bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
        ),
      );

      // The picker order, and it is alphabetical here: both were bought once
      // on the same day, so '2 L' comes before '350 ml'.
      expect(
        candidates.shown.map((option) => option.id),
        ['prod-3', 'prod-1'],
      );
      expect(candidates.hasMore, isTrue);
    });

    test('with fewer than two bought, it opens WHOLE', () {
      // "Só comprei o Omo 500 g nos últimos 3 meses": cutting to one line is
      // opening a calculator with nothing to compare.
      final candidates = candidatesOf(
        optionsOfSoftDrinkType(
          bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
        ),
      );

      expect(candidates.shown, candidates.all);
      expect(candidates.hasMore, isFalse);
    });

    test('F-j: the leaf being registered is shown even with no price', () {
      // The "big one I never take" of requirement 17 — and the product
      // registered on screen 4 a minute ago (F-i).
      final options = optionsOfSoftDrinkType(
        can: reference(cents: 400, quantityInBaseUnit: 350),
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
      );
      final crate = options.firstWhere((option) => option.id == 'prod-4');
      final candidates = candidatesOf(options, launching: crate);

      expect(candidates.shown.contains(crate), isTrue);
      expect(candidates.shown, hasLength(3));
    });

    test('F-j: it comes in on the picker order, not pushed to the end', () {
      final options = optionsOfSoftDrinkType(
        can: reference(cents: 400, quantityInBaseUnit: 350),
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
      );
      final tiny = options.firstWhere((option) => option.id == 'prod-2');
      final candidates = candidatesOf(options, launching: tiny);

      // Bought twice inside the window first, then the never-bought one.
      expect(
        candidates.shown.map((option) => option.id),
        ['prod-3', 'prod-1', 'prod-2'],
      );
    });

    test('F-j: already in the cut, it is not duplicated', () {
      final options = optionsOfSoftDrinkType(
        can: reference(cents: 400, quantityInBaseUnit: 350),
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
      );
      final can = options.firstWhere((option) => option.id == 'prod-1');
      final candidates = candidatesOf(options, launching: can);

      expect(candidates.shown, hasLength(2));
    });

    test('F-j: a leaf of another type never sneaks into the cut', () {
      final options = optionsOfSoftDrinkType(
        can: reference(cents: 400, quantityInBaseUnit: 350),
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
      );
      final beef = optionByWeight(id: 'beef');
      final candidates = candidatesOf(options, launching: beef);

      expect(candidates.shown.contains(beef), isFalse);
      expect(candidates.shown, hasLength(2));
    });

    test('with no leaf being registered the cut is just the window', () {
      final candidates = candidatesOf(
        optionsOfSoftDrinkType(
          can: reference(cents: 400, quantityInBaseUnit: 350),
          bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
        ),
      );
      expect(candidates.shown, hasLength(2));
    });

    test('the order inside is the picker order (C1)', () {
      // Most bought first, and the two never bought alphabetically after.
      final candidates = candidatesOf(
        optionsOfSoftDrinkType(
          bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
        ),
      );

      expect(candidates.all.first.id, 'prod-3');
    });
  });

  group('rankCosts — the three written stories', () {
    test('Omo: 500 g at R\$ 10,00 loses to 2,3 kg at R\$ 33,00 by 28%', () {
      final small = optionByPiece(
        id: 'omo-500',
        type: powderType,
        brand: omoBrand,
        pieceSize: 500,
        unit: MeasureUnit.gram,
      );
      final big = optionByPiece(
        id: 'omo-2300',
        type: powderType,
        brand: omoBrand,
        pieceSize: 2300,
        unit: MeasureUnit.kilogram,
      );

      final ranking = rank(
        [small, big].lock,
        {'omo-500': 1000, 'omo-2300': 3300},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.lines.map((line) => line.option.id), [
        'omo-2300',
        'omo-500',
      ]);
      expect(ranking.lines[0].costPerBaseUnit, 1435);
      expect(ranking.lines[1].costPerBaseUnit, 2000);
      expect(ranking.lines[0].isBest, isTrue);
      expect(ranking.lines[0].savingPercent, isNull);
      expect(ranking.lines[1].savingPercent, 28);
      expect(ranking.best, big);
      expect(ranking.headline, 'Omo 2,3 kg — 28% mais barato o kg');
    });

    test('soft drink: the 2 L bottle wins the litre', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(options, {
        'prod-1': 400,
        'prod-3': 1000,
        'prod-4': 4200,
      });

      expect(ranking.lines.take(3).map((line) => line.option.id), [
        'prod-3',
        'prod-4',
        'prod-1',
      ]);
      expect(ranking.lines[0].costPerBaseUnit, 500);
      expect(ranking.lines[1].costPerBaseUnit, 1000);
      expect(ranking.lines[2].costPerBaseUnit, 1143);
      expect(ranking.lines[1].savingPercent, 50);
      expect(ranking.lines[2].savingPercent, 56);
      expect(ranking.best?.id, 'prod-3');
      // The footer repeats the BIGGEST difference, which is against the can.
      expect(
        ranking.headline,
        'Coca-Cola original 2 L — 56% mais barato o litro',
      );
    });

    test('weighed against packaged: the typed price is already the kilo', () {
      final counter = optionByWeight(id: 'counter', type: cheeseType);
      final sliced = optionByPiece(
        id: 'sliced',
        type: cheeseType,
        pieceSize: 200,
        unit: MeasureUnit.gram,
      );

      final ranking = rank(
        [counter, sliced].lock,
        {'counter': 4800, 'sliced': 1100},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.lines[0].option.id, 'counter');
      expect(ranking.lines[0].costPerBaseUnit, 4800);
      expect(ranking.lines[1].costPerBaseUnit, 5500);
      expect(ranking.lines[1].savingPercent, 13);
    });
  });

  group('rankCosts — the states', () {
    test('counted by unit: the sentence says "a unidade"', () {
      final small = optionByPiece(
        id: 'paper-4',
        type: paperType,
        description: 'folha dupla',
        pieceSize: 4,
        unit: MeasureUnit.unit,
      );
      final big = optionByPiece(
        id: 'paper-12',
        type: paperType,
        description: 'folha dupla',
        pieceSize: 12,
        unit: MeasureUnit.unit,
      );

      final ranking = rank(
        [small, big].lock,
        {'paper-4': 800, 'paper-12': 1800},
        baseUnit: BaseUnit.unit,
      );

      expect(ranking.lines[0].costPerBaseUnit, 150);
      expect(ranking.lines[1].costPerBaseUnit, 200);
      expect(
        ranking.headline,
        'folha dupla 12 un — 25% mais barato a unidade',
      );
    });
    test('with no price at all the footer asks for prices', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(options, const {}, selected: {'prod-4'});

      expect(ranking.best, isNull);
      expect(ranking.usable, isNull);
      expect(ranking.headline, 'Digite os preços que você está vendo.');
    });

    test('with a single price the button is locked', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(options, {'prod-4': 4200});

      expect(ranking.usable, isNull);
      expect(ranking.headline, 'Preencha o preço de duas opções.');
    });

    test('a ticked line with no price waits and does not count', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(
        options,
        {'prod-4': 4200},
        selected: {'prod-4', 'prod-3'},
      );

      final waiting = ranking.lines.firstWhere(
        (line) => line.option.id == 'prod-3',
      );
      expect(waiting.selected, isTrue);
      expect(waiting.costPerBaseUnit, isNull);
      expect(ranking.usable, isNull);
    });

    test('two ticked prices are enough, even with five lines on screen', () {
      final options = optionsOfSoftDrinkType().add(
        optionByPiece(id: 'prod-9', pieceSize: 600),
      );
      final ranking = rank(
        options,
        {'prod-1': 400, 'prod-3': 1000},
        selected: {'prod-1', 'prod-3'},
      );

      expect(ranking.lines, hasLength(5));
      expect(ranking.best?.id, 'prod-3');
    });

    test('an unticked line with a price does not compete', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(
        options,
        {'prod-1': 400, 'prod-3': 1000, 'prod-2': 100},
        selected: {'prod-1', 'prod-3'},
      );

      final aside = ranking.lines.firstWhere(
        (line) => line.option.id == 'prod-2',
      );
      // The price shows in the field; the cost and the difference do not.
      expect(aside.price, const Money(100));
      expect(aside.costPerBaseUnit, isNull);
      expect(aside.savingPercent, isNull);
      // And it cannot win, cheap as it is.
      expect(ranking.best?.id, 'prod-3');
    });

    test('below 1% nobody is crowned, and [ Usar ] survives it (F-h)', () {
      final cheap = kiloLeaf('kilo-a');
      final dear = kiloLeaf('kilo-b');
      final ranking = rank(
        [cheap, dear].lock,
        {'kilo-a': 1000, 'kilo-b': 1005},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.best, isNull);
      expect(ranking.lines.every((line) => !line.isBest), isTrue);
      expect(ranking.usable, cheap);
      expect(ranking.headline, 'Custo praticamente igual.');
    });

    test('exactly 1% DOES elect a winner', () {
      final ranking = rank(
        [kiloLeaf('kilo-a'), kiloLeaf('kilo-b')].lock,
        {'kilo-a': 9900, 'kilo-b': 10000},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.best?.id, 'kilo-a');
      expect(ranking.lines[1].savingPercent, 1);
    });

    test('0,99% does not', () {
      final ranking = rank(
        [kiloLeaf('kilo-a'), kiloLeaf('kilo-b')].lock,
        {'kilo-a': 9901, 'kilo-b': 10000},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.best, isNull);
      expect(ranking.lines[1].savingPercent, isNull);
    });

    test('F-d: a tie at the top does not erase the third line percentage', () {
      final ranking = rank(
        [kiloLeaf('kilo-a'), kiloLeaf('kilo-b'), kiloLeaf('kilo-c')].lock,
        {'kilo-a': 10000, 'kilo-b': 10050, 'kilo-c': 16667},
        baseUnit: BaseUnit.kilogram,
      );

      expect(ranking.best, isNull);
      // The tied runner-up says nothing...
      expect(ranking.lines[1].savingPercent, isNull);
      // ...and the line 40% dearer keeps saying so.
      expect(ranking.lines[2].savingPercent, 40);
      expect(ranking.headline, 'Custo praticamente igual.');
    });

    test('a zero price is the same as no price', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(options, {'prod-1': 0, 'prod-3': 1000});

      expect(ranking.usable, isNull);
      final zero = ranking.lines.firstWhere(
        (line) => line.option.id == 'prod-1',
      );
      expect(zero.costPerBaseUnit, isNull);
    });

    test('the 800 g tray typed in loses to the 1 kg pack', () {
      // The case that asks for the field: the two trays are the SAME leaf
      // sold by weight, and without the typed content the panel would take
      // R$ 12,00 for the kilo.
      final tray = optionByWeight(id: 'tray', type: beefType);
      final packed = optionByPiece(
        id: 'packed',
        type: beefType,
        description: 'congelado',
        pieceSize: 1000,
        unit: MeasureUnit.gram,
      );

      final ranking = rank(
        [tray, packed].lock,
        {'tray': 1200, 'packed': 1450},
        baseUnit: BaseUnit.kilogram,
        contents: {'tray': 800},
      );

      expect(ranking.lines[0].option.id, 'packed');
      expect(ranking.lines[0].costPerBaseUnit, 1450);
      expect(ranking.lines[1].costPerBaseUnit, 1500);
      expect(ranking.lines[1].savingPercent, 3);
      expect(ranking.best, packed);
    });

    test('a cleared quantity field leaves the line waiting', () {
      final tray = optionByWeight(id: 'tray', type: beefType);
      final packed = optionByPiece(
        id: 'packed',
        type: beefType,
        pieceSize: 1000,
        unit: MeasureUnit.gram,
      );

      final ranking = rank(
        [tray, packed].lock,
        {'tray': 1200, 'packed': 1450},
        baseUnit: BaseUnit.kilogram,
        contents: {'tray': null},
      );

      // It does NOT fall back to one kilo: a plausible and wrong cost is the
      // worst outcome a calculator has.
      final waiting = ranking.lines.firstWhere(
        (line) => line.option.id == 'tray',
      );
      expect(waiting.costPerBaseUnit, isNull);
      expect(waiting.savingPercent, isNull);
      expect(ranking.best, isNull);
      expect(ranking.usable, isNull);
      expect(ranking.headline, 'Preencha o preço de duas opções.');
    });

    test('the packaged line waits for no content at all', () {
      final tray = optionByWeight(id: 'tray', type: beefType);
      final packed = optionByPiece(
        id: 'packed',
        type: beefType,
        pieceSize: 1000,
        unit: MeasureUnit.gram,
      );

      final ranking = rank(
        [tray, packed].lock,
        {'tray': 1200, 'packed': 1450},
        baseUnit: BaseUnit.kilogram,
        contents: {'packed': null},
      );

      // The map does not rule the packaged line: it goes on competing.
      expect(ranking.lines[0].option.id, 'tray');
      expect(ranking.lines[0].costPerBaseUnit, 1200);
      expect(ranking.lines[1].costPerBaseUnit, 1450);
      expect(ranking.best, tray);
    });
  });

  group('rankCosts — the order (F-c)', () {
    test('competing first, then waiting, then aside', () {
      final options = optionsOfSoftDrinkType();
      final ranking = rank(
        options,
        {'prod-4': 4200, 'prod-1': 400},
        selected: {'prod-4', 'prod-1', 'prod-3'},
      );

      expect(ranking.lines.map((line) => line.option.id), [
        // Competing, cheapest per litre first: the crate at R$ 10,00/L, then
        // the can at R$ 11,43/L.
        'prod-4',
        'prod-1',
        // Ticked and waiting.
        'prod-3',
        // Unticked, in the picker's order.
        'prod-2',
      ]);
    });

    test('an exact cost tie falls back to the picker order, and is stable', () {
      // Two 1 kg leaves at the same price: the cost cannot decide, and the
      // description is what compareForPicker reads next.
      final options = [kiloLeaf('kilo-b'), kiloLeaf('kilo-a')].lock;
      final prices = {'kilo-a': 1000, 'kilo-b': 1000};

      final first = rank(options, prices, baseUnit: BaseUnit.kilogram);
      final second = rank(options, prices, baseUnit: BaseUnit.kilogram);

      expect(first.lines.map((line) => line.option.id), ['kilo-a', 'kilo-b']);
      expect(first.lines, second.lines);
    });
  });

  group('costHeaderFor', () {
    test('names the unit the computation is in', () {
      expect(costHeaderFor(BaseUnit.kilogram), 'custo por kg');
      expect(costHeaderFor(BaseUnit.liter), 'custo por litro');
      expect(costHeaderFor(BaseUnit.unit), 'custo por unidade');
    });
  });

  group('equality (rule 8)', () {
    final option = optionByPiece(id: 'prod-1');
    final other = optionByPiece(id: 'prod-3', pieceSize: 2000);

    CostLine line({
      ProductOption? option_,
      bool selected = true,
      Money? price = const Money(400),
      int? costPerBaseUnit = 1143,
      int? savingPercent = 56,
      bool isBest = false,
    }) => CostLine(
      option: option_ ?? option,
      selected: selected,
      price: price,
      costPerBaseUnit: costPerBaseUnit,
      savingPercent: savingPercent,
      isBest: isBest,
    );

    test('CostLine: same fields, same value', () {
      expect(line(), line());
      expect(line().hashCode, line().hashCode);
    });

    test('CostLine: one field at a time breaks it', () {
      expect(line(option_: other), isNot(line()));
      expect(line(selected: false), isNot(line()));
      expect(line(price: const Money(1)), isNot(line()));
      expect(line(costPerBaseUnit: 1), isNot(line()));
      expect(line(savingPercent: 1), isNot(line()));
      expect(line(isBest: true), isNot(line()));
    });

    CostRanking ranking({
      IList<CostLine>? lines,
      String headline = 'Custo praticamente igual.',
      ProductOption? best,
      ProductOption? usable,
    }) => CostRanking(
      lines: lines ?? [line()].lock,
      headline: headline,
      best: best ?? option,
      usable: usable ?? option,
    );

    test('CostRanking: same fields, same value', () {
      expect(ranking(), ranking());
      expect(ranking().hashCode, ranking().hashCode);
    });

    test('CostRanking: one field at a time breaks it', () {
      expect(ranking(lines: const IList.empty()), isNot(ranking()));
      expect(ranking(headline: 'outra'), isNot(ranking()));
      expect(ranking(best: other), isNot(ranking()));
      expect(ranking(usable: other), isNot(ranking()));
    });

    CostCandidates candidates({
      IList<ProductOption>? all,
      IList<ProductOption>? shown,
    }) => CostCandidates(
      all: all ?? [option, other].lock,
      shown: shown ?? [option].lock,
    );

    test('CostCandidates: same fields, same value', () {
      expect(candidates(), candidates());
      expect(candidates().hashCode, candidates().hashCode);
    });

    test('CostCandidates: one field at a time breaks it', () {
      expect(candidates(all: [option].lock), isNot(candidates()));
      expect(candidates(shown: const IList.empty()), isNot(candidates()));
    });

    test('the three toStrings say what a failed test needs to read', () {
      expect(candidates().toString(), 'CostCandidates(1 of 2)');
      expect(
        line(isBest: true).toString(),
        'CostLine(350 ml, 1143, best: true)',
      );
      expect(ranking().toString(), 'CostRanking(1 lines, best: prod-1)');
    });
  });
}

/// The same leaf without its id — a product that has not been written yet.
ProductOption _withoutId(ProductOption option) => ProductOption(
  product: Product(
    productRegistrationId: option.registration.id!,
    packaging: option.product.packaging,
  ),
  registration: option.registration,
  type: option.type,
  brand: option.brand,
);

/// The same leaf with its own `active` off — "desativar a embalagem", which
/// is the flag `fetchProductOptions` filters in SQL and this file's cut does
/// not.
ProductOption _deactivated(ProductOption option) => ProductOption(
  product: option.product.deactivated(),
  registration: option.registration,
  type: option.type,
  brand: option.brand,
);
