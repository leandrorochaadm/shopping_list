import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';

/// Fixed instants everywhere: `DateTime.now()` in a test is a test that fails
/// once a year, at midnight.
final _category = Category(id: 'cat-1', name: 'Bebidas');

ProductType _type({
  String name = 'Leite',
  BaseUnit baseUnit = BaseUnit.liter,
}) => ProductType(
  id: 'type-1',
  name: name,
  categoryId: 'cat-1',
  baseUnit: baseUnit,
);

final _brand = Brand(id: 'brand-1', name: 'Italac');

const _leaf = Product(
  id: 'prod-1',
  productRegistrationId: 'reg-1',
  packaging: null,
);

Product _packagedLeaf() => Product(
  id: 'prod-1',
  productRegistrationId: 'reg-1',
  packaging: Packaging(
    pieceCount: 1,
    pieceSize: 1000,
    // Typed in litres, so the shelf name reads '1 L' and not '1000 ml' —
    // the packaging keeps the unit it was typed in.
    pieceSizeUnit: MeasureUnit.liter,
  ),
);

ShoppingListItem _item({
  String? id = 'item-1',
  ProductType? type,
  Brand? brand,
  Product? product,
  int? quantity = 6000,
  DateTime? enteredOn,
  bool picked = false,
  bool notFound = false,
}) => ShoppingListItem(
  id: id,
  type: type ?? _type(),
  category: _category,
  preferredBrand: brand,
  preferredProduct: product,
  quantity: quantity,
  enteredOn: enteredOn ?? DateTime(2026, 8, 28),
  picked: picked,
  notFound: notFound,
);

void main() {
  group('the checkbox', () {
    test('flips two states and never touches "não encontrei"', () {
      // The test that fails if anyone "simplifies" the box into three states.
      final item = _item(notFound: true);

      final picked = item.togglePicked();
      expect(picked.picked, isTrue);
      expect(picked.notFound, isTrue);

      final unpicked = picked.togglePicked();
      expect(unpicked.picked, isFalse);
      expect(unpicked.notFound, isTrue);
    });

    test('"não encontrei" never touches the box', () {
      final item = _item(picked: true);

      expect(item.markedNotFound().notFound, isTrue);
      expect(item.markedNotFound().picked, isTrue);
      expect(item.markedNotFound().clearedNotFound().notFound, isFalse);
      expect(item.markedNotFound().clearedNotFound().picked, isTrue);
    });
  });

  group('canBeClearedBy', () {
    final item = _item(enteredOn: DateTime(2026, 8, 28));

    test('a purchase from the day before does NOT clear it', () {
      // Decision 25: the purchase registered late must not erase what the
      // other person has just asked for.
      expect(item.canBeClearedBy(DateTime(2026, 8, 27)), isFalse);
    });

    test('a purchase from the SAME day clears it', () {
      expect(item.canBeClearedBy(DateTime(2026, 8, 28)), isTrue);
      // Same day, with an hour on it: the rounding is what makes it true.
      expect(item.canBeClearedBy(DateTime(2026, 8, 28, 23, 59)), isTrue);
    });

    test('a purchase from the next day clears it', () {
      expect(item.canBeClearedBy(DateTime(2026, 8, 29)), isTrue);
    });
  });

  group('what the line reads', () {
    test('writes the quantity in the base unit of the type', () {
      expect(
        _item(type: _type(baseUnit: BaseUnit.kilogram)).quantityLabel,
        '6 kg',
      );
      expect(_item(quantity: 2500).quantityLabel, '2,5 L');
      expect(
        _item(type: _type(baseUnit: BaseUnit.unit), quantity: 3).quantityLabel,
        '3 un',
      );
    });

    test('has no quantity label when there is no quantity', () {
      final item = _item(quantity: null);

      expect(item.quantityLabel, isNull);
      expect(item.hasQuantity, isFalse);
      expect(_item().hasQuantity, isTrue);
    });

    test('composes type, brand and packaging, in this order', () {
      expect(_item().label, 'Leite');
      expect(_item(brand: _brand).label, 'Leite Italac');
      expect(_item(product: _packagedLeaf()).label, 'Leite 1 L');
      expect(
        _item(brand: _brand, product: _packagedLeaf()).label,
        'Leite Italac 1 L',
      );
    });

    test('a leaf sold by weight adds nothing to the label', () {
      expect(_item(product: _leaf).label, 'Leite');
    });

    test('names itself in a log line', () {
      expect(_item().toString(), contains('Leite'));
      expect(_item(quantity: null).toString(), contains('sem quantidade'));
    });
  });

  group('the quantity rule', () {
    test('refuses zero and negatives — but not null', () {
      expect(() => _item(quantity: 0), throwsA(isA<InvalidQuantity>()));
      expect(() => _item(quantity: -1), throwsA(isA<InvalidQuantity>()));
      expect(_item(quantity: null).quantity, isNull);
    });

    test('says what to do, in pt-BR', () {
      expect(
        const InvalidQuantity().message,
        'Informe uma quantidade maior que zero.',
      );
      expect(const InvalidQuantity().toString(), contains('quantidade'));
    });
  });

  group('json', () {
    Map<String, dynamic> embed({
      Object? quantity = 6000,
      Map<String, dynamic>? brand,
      Map<String, dynamic>? product,
    }) => {
      'id': 'item-1',
      'quantity': quantity,
      'entered_on': '2026-08-28',
      'picked': true,
      'not_found': false,
      'product_type': {
        'id': 'type-1',
        'name': 'Leite',
        'category_id': 'cat-1',
        'base_unit': 'liter',
        'active': true,
        'category': {'id': 'cat-1', 'name': 'Bebidas', 'active': true},
      },
      'preferred_brand': brand,
      'preferred_product': product,
    };

    test('reads the whole embed PostgREST returns', () {
      final item = ShoppingListItem.fromJson(
        embed(
          brand: {'id': 'brand-1', 'name': 'Italac', 'active': true},
          product: {
            'id': 'prod-1',
            'product_registration_id': 'reg-1',
            'piece_count': 1,
            'piece_size': 1000,
            'piece_size_unit': 'liter',
            'total_content': 1000,
            'active': true,
          },
        ),
      );

      expect(item.id, 'item-1');
      expect(item.type.name, 'Leite');
      expect(item.category.name, 'Bebidas');
      expect(item.preferredBrand!.name, 'Italac');
      expect(item.preferredProduct!.packaging!.label, '1 L');
      expect(item.quantity, 6000);
      expect(item.enteredOn, DateTime(2026, 8, 28));
      expect(item.picked, isTrue);
      expect(item.notFound, isFalse);
    });

    test('reads the three nulls the migration allows', () {
      final item = ShoppingListItem.fromJson(embed(quantity: null));

      expect(item.quantity, isNull);
      expect(item.preferredBrand, isNull);
      expect(item.preferredProduct, isNull);
      expect(item.label, 'Leite');
    });

    test('writes ONLY the table columns, with the ids extracted', () {
      final json = _item(brand: _brand, product: _packagedLeaf()).toJson();

      expect(json, {
        'id': 'item-1',
        'product_type_id': 'type-1',
        'preferred_brand_id': 'brand-1',
        'preferred_product_id': 'prod-1',
        'quantity': 6000,
        'entered_on': '2026-08-28',
        'picked': false,
        'not_found': false,
      });
      // The embedded entities never travel back — they are not columns.
      expect(json.containsKey('product_type'), isFalse);
    });

    test('leaves the id out before the row exists', () {
      expect(_item(id: null).toJson().containsKey('id'), isFalse);
    });
  });

  group('equality', () {
    test('differs on every one of the nine fields', () {
      final item = _item();

      expect(item, _item());
      expect(item.hashCode, _item().hashCode);

      expect(item, isNot(_item(id: 'other')));
      expect(item, isNot(_item(type: _type(name: 'Suco'))));
      expect(
        item,
        isNot(
          item.copyWith(category: Category(id: 'cat-2', name: 'Limpeza')),
        ),
      );
      expect(item, isNot(_item(brand: _brand)));
      expect(item, isNot(_item(product: _packagedLeaf())));
      expect(item, isNot(_item(quantity: 1000)));
      expect(item, isNot(_item(enteredOn: DateTime(2026, 8, 27))));
      expect(item, isNot(_item(picked: true)));
      expect(item, isNot(_item(notFound: true)));
    });

    test('copyWith clears a preference when asked to', () {
      // `copyWith` alone cannot tell "keep it" from "set it to null", and
      // "Qualquer uma" in the dialog is exactly the second one.
      final item = _item(brand: _brand, product: _packagedLeaf());

      expect(item.copyWith(clearBrand: true).preferredBrand, isNull);
      expect(item.copyWith(clearProduct: true).preferredProduct, isNull);
      expect(item.copyWith(clearQuantity: true).quantity, isNull);
      // And it keeps them when it is not asked to.
      expect(item.copyWith(picked: true).preferredBrand, _brand);
    });

    test('rounds the entered day, so a repaint is never free', () {
      final withHour = _item(enteredOn: DateTime(2026, 8, 28, 22, 15));

      expect(withHour.enteredOn, DateTime(2026, 8, 28));
      expect(withHour, _item());
    });
  });
}
