import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/price_reference.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';

void main() {
  final softDrink = ProductType(
    id: 'type-1',
    name: 'Refrigerante',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.liter,
  );
  final beef = ProductType(
    id: 'type-2',
    name: 'Acém moído',
    categoryId: 'cat-2',
    baseUnit: BaseUnit.kilogram,
  );
  final paper = ProductType(
    id: 'type-3',
    name: 'Papel higiênico',
    categoryId: 'cat-3',
    baseUnit: BaseUnit.unit,
  );
  final coke = Brand(id: 'brand-1', name: 'Coca-Cola');

  ProductOption byPiece({
    required String id,
    ProductType? type,
    Brand? brand,
    String description = '',
    int pieceCount = 1,
    int pieceSize = 350,
    MeasureUnit unit = MeasureUnit.milliliter,
    int purchaseCount = 0,
    DateTime? lastPurchasedOn,
  }) => ProductOption(
    product: Product(
      id: id,
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: pieceCount,
        pieceSize: pieceSize,
        pieceSizeUnit: unit,
      ),
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: (type ?? softDrink).id!,
      brandId: brand?.id,
      description: description,
      sellingMode: SellingMode.byPiece,
    ),
    type: type ?? softDrink,
    brand: brand,
    purchaseCount: purchaseCount,
    lastPurchasedOn: lastPurchasedOn,
  );

  final groundBeef = ProductOption(
    product: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
    registration: ProductRegistration(
      id: 'reg-2',
      productTypeId: 'type-2',
      sellingMode: SellingMode.byWeight,
    ),
    type: beef,
  );

  group('label', () {
    test('joins brand, description and packaging, skipping what is absent', () {
      expect(
        byPiece(id: 'p1', brand: coke, pieceCount: 12).label,
        'Coca-Cola 12 × 350 ml',
      );
      expect(
        byPiece(
          id: 'p2',
          brand: coke,
          description: 'zero',
          pieceSize: 2000,
          unit: MeasureUnit.liter,
        ).label,
        'Coca-Cola zero 2 L',
      );
      // No brand and no description: the packaging alone. The type is the
      // group header, so it is not repeated on every line.
      expect(byPiece(id: 'p3').label, '350 ml');
    });

    test('falls back to the type name when nothing else is left', () {
      // The weight-sold product with no brand and no description — there the
      // type name IS the name of the thing on the shelf.
      expect(groundBeef.label, 'Acém moído (a peso)');
    });
  });

  group('matches', () {
    final option = byPiece(
      id: 'p1',
      brand: coke,
      description: 'zero',
      pieceCount: 12,
    );

    test('matches a stretch, ignoring case, blanks and accents', () {
      for (final query in ['coca', 'COCA', 'cocá', '  Coca ', 'ca-co']) {
        expect(option.matches(query), isTrue, reason: query);
      }
      // A stretch, not a scattering of letters: the search is `contains`,
      // and 'ccl' would turn every query into a guessing game.
      expect(option.matches('ccl'), isFalse);
    });

    test('finds it by the type, by the brand and by the packaging', () {
      expect(option.matches('refri'), isTrue, reason: 'by type');
      expect(option.matches('zero'), isTrue, reason: 'by description');
      expect(option.matches('350'), isTrue, reason: 'by packaging');
      expect(option.matches('12 ×'), isTrue, reason: 'by packaging');
    });

    test('an empty query matches everything', () {
      // The picker with an empty field shows the whole list, in the C1 order.
      expect(option.matches(''), isTrue);
      expect(option.matches('   '), isTrue);
    });

    test('says no to what is not there', () {
      expect(option.matches('leite'), isFalse);
    });
  });

  group('toBaseUnit', () {
    test('the two ways to the same crate close at the same content', () {
      // The acceptance criterion, literally: "Coca 12 × 350 ml" × 1 and
      // "Coca 350 ml" × 12 are the same 4200 ml.
      final crate = byPiece(id: 'p1', pieceCount: 12);
      final bottle = byPiece(id: 'p2');

      expect(crate.toBaseUnit(1), 4200);
      expect(bottle.toBaseUnit(12), 4200);
    });

    test('sold by weight does not multiply by any packaging', () {
      // 1,5 kg was already parsed into 1500 g by the screen; it passes
      // straight through.
      expect(groundBeef.toBaseUnit(1500), 1500);
    });
  });

  group('quantityLabel', () {
    test('sold by piece asks only for a quantity', () {
      // The packaging name right above already says what is being counted.
      expect(byPiece(id: 'p1', pieceCount: 12).quantityLabel, 'Quantidade');
    });

    test('sold by weight carries the unit of its base', () {
      expect(groundBeef.quantityLabel, 'Peso (kg)');

      final bulkOil = ProductOption(
        product: const Product(id: 'p9', productRegistrationId: 'reg-9'),
        registration: ProductRegistration(
          id: 'reg-9',
          productTypeId: 'type-1',
          sellingMode: SellingMode.byWeight,
        ),
        type: softDrink,
      );
      expect(bulkOil.quantityLabel, 'Volume (L)');

      final looseRolls = ProductOption(
        product: const Product(id: 'p8', productRegistrationId: 'reg-8'),
        registration: ProductRegistration(
          id: 'reg-8',
          productTypeId: 'type-3',
          sellingMode: SellingMode.byWeight,
        ),
        type: paper,
      );
      expect(looseRolls.quantityLabel, 'Quantidade (un)');
    });
  });

  group('compareForPicker', () {
    test('the most bought in three months comes first', () {
      final often = byPiece(id: 'p1', purchaseCount: 9);
      final rarely = byPiece(id: 'p2', pieceSize: 269, purchaseCount: 2);

      expect(compareForPicker(often, rarely), lessThan(0));
      expect(compareForPicker(rarely, often), greaterThan(0));
    });

    test('a tie in count goes to the most recently bought', () {
      final recent = byPiece(
        id: 'p1',
        purchaseCount: 3,
        lastPurchasedOn: DateTime(2026, 8, 20),
      );
      final older = byPiece(
        id: 'p2',
        pieceSize: 269,
        purchaseCount: 3,
        lastPurchasedOn: DateTime(2026, 7, 1),
      );

      expect(compareForPicker(recent, older), lessThan(0));
    });

    test('one never bought comes after one that was', () {
      final bought = byPiece(
        id: 'p1',
        lastPurchasedOn: DateTime(2026, 7, 1),
      );
      final never = byPiece(id: 'p2', pieceSize: 269);

      expect(compareForPicker(bought, never), lessThan(0));
      expect(compareForPicker(never, bought), greaterThan(0));
    });

    test('two nobody ever bought are alphabetical, and stay put', () {
      // Without this the order flickers between fetches — which in the first
      // weeks is EVERY option in the catalog.
      final zero = byPiece(id: 'p1', description: 'zero');
      final original = byPiece(id: 'p2', description: 'original');

      expect(compareForPicker(original, zero), lessThan(0));

      // Same label, different leaf: the id is what keeps it stable.
      final first = byPiece(id: 'p1');
      final second = byPiece(id: 'p2');
      expect(compareForPicker(first, second), lessThan(0));
    });
  });

  group('groupForPicker', () {
    test('groups by type and opens on the most bought type', () {
      final options = [
        byPiece(id: 'p1', purchaseCount: 1),
        groundBeef.withHistory(purchaseCount: 7),
        byPiece(id: 'p2', pieceSize: 269, purchaseCount: 4),
      ].lock;

      final groups = groupForPicker(options);

      expect(groups.length, 2);
      expect(groups.first.type, beef, reason: 'bought 7 times');
      expect(groups.last.type, softDrink);
      // Inside the group, the most bought first — and NOT interleaved with
      // the beef, which a flat sort would have done.
      expect(
        groups.last.options.map((option) => option.purchaseCount).toList(),
        [4, 1],
      );
    });

    test('an empty catalog groups into nothing', () {
      expect(groupForPicker(const IList.empty()), isEmpty);
    });
  });

  test('withHistory attaches the count and the reference, keeping the rest', () {
    final reference = PriceReference(
      paid: const Money(6200),
      quantityInBaseUnit: 12000,
      purchasedOn: DateTime(2026, 8, 18),
    );
    final ranked = byPiece(id: 'p1', brand: coke, pieceCount: 12).withHistory(
      purchaseCount: 4,
      lastPurchasedOn: DateTime(2026, 8, 18),
      priceReference: reference,
    );

    expect(ranked.purchaseCount, 4);
    expect(ranked.priceReference, reference);
    expect(ranked.label, 'Coca-Cola 12 × 350 ml');
    expect(ranked.baseUnit, BaseUnit.liter);
    expect(ranked.id, 'p1');
    expect(ranked.isSoldByWeight, isFalse);
  });

  test('reads the PostgREST embed, brand included and brand absent', () {
    final row = {
      'id': 'prod-4',
      'product_registration_id': 'reg-1',
      'piece_count': 12,
      'piece_size': 350,
      'piece_size_unit': 'milliliter',
      'total_content': 4200,
      'active': true,
      'product_registration': {
        'id': 'reg-1',
        'product_type_id': 'type-1',
        'brand_id': 'brand-1',
        'description': '',
        'selling_mode': 'by_piece',
        'active': true,
        'product_type': {
          'id': 'type-1',
          'name': 'Refrigerante',
          'category_id': 'cat-1',
          'base_unit': 'liter',
          'active': true,
        },
        'brand': {'id': 'brand-1', 'name': 'Coca-Cola', 'active': true},
      },
    };

    final option = ProductOption.fromJson(row);
    expect(option.label, 'Coca-Cola 12 × 350 ml');
    expect(option.type, softDrink);
    expect(option.toBaseUnit(1), 4200);

    // "Sem marca" is a real answer (decision B2), which is why the embed has
    // no `!inner` and the null has to survive the parsing.
    final noBrand = ProductOption.fromJson({
      ...row,
      'product_registration': {
        ...row['product_registration']! as Map<String, dynamic>,
        'brand_id': null,
        'brand': null,
      },
    });
    expect(noBrand.brand, isNull);
    expect(noBrand.label, '12 × 350 ml');
  });

  test('equality covers every field, so Riverpod can filter an update', () {
    final option = byPiece(id: 'p1', brand: coke);

    expect(option, byPiece(id: 'p1', brand: coke));
    expect(option.hashCode, byPiece(id: 'p1', brand: coke).hashCode);
    expect(option, isNot(byPiece(id: 'p2', brand: coke)));
    expect(option, isNot(byPiece(id: 'p1')));
    expect(option, isNot(option.withHistory(purchaseCount: 1)));
    expect(option.toString(), contains('Coca-Cola'));
  });

  group('ProductGroup', () {
    ProductGroup group({ProductType? type, String optionId = 'p1'}) =>
        ProductGroup(
          type: type ?? softDrink,
          options: [byPiece(id: optionId)].lock,
        );

    test('equality covers every field, so the picker does not rebuild', () {
      expect(group(), group());
      expect(group().hashCode, group().hashCode);
      expect(group(), isNot(group(type: beef)));
      expect(group(), isNot(group(optionId: 'p2')));
    });
  });
}
