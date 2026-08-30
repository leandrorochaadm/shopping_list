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
  int writtenOffQuantity = 0,
  int writeOffCount = 0,
  DateTime? fulfilledOn,
  DateTime? removedOn,
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
  writtenOffQuantity: writtenOffQuantity,
  writeOffCount: writeOffCount,
  fulfilledOn: fulfilledOn,
  removedOn: removedOn,
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
        // B6: both ways out of the list are columns of this table.
        'fulfilled_on': null,
        'removed_on': null,
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

  group('leaving the list — B6', () {
    // The two ways out, and they are DATES rather than a DELETE:
    // `list_write_off` has a foreign key here with no `on delete`, so a
    // deleted row would take the trail H9 undoes with it.
    test('a fresh line is open', () {
      final item = _item();

      expect(item.isOpen, isTrue);
      expect(item.fulfilledOn, isNull);
      expect(item.removedOn, isNull);
    });

    test('a line a purchase closed is not open', () {
      final item = _item(fulfilledOn: DateTime(2026, 8, 30));

      expect(item.isOpen, isFalse);
      expect(item.fulfilledOn, DateTime(2026, 8, 30));
    });

    test('a line removed by hand is not open either', () {
      // Two different acts, two different columns: H9 has to tell "a compra
      // fechou este item" from "alguém tirou este item da lista".
      final removed = _item().markedRemoved(DateTime(2026, 8, 30, 14, 22));

      expect(removed.isOpen, isFalse);
      expect(removed.removedOn, DateTime(2026, 8, 30));
      expect(removed.fulfilledOn, isNull);
    });
  });

  group('remainingQuantity', () {
    test('is what was asked for, minus the trail', () {
      // 'restam 4 de 6 L' — derived (P5), never stored: H9 undoes a purchase
      // by deleting its write-offs, and a stored balance would be a second
      // number to keep in step.
      expect(_item(quantity: 6000).remainingQuantity, 6000);
      expect(
        _item(quantity: 6000, writtenOffQuantity: 2000).remainingQuantity,
        4000,
      );
    });

    test('never goes negative', () {
      // Buying more than what was asked for closes the line; it does not owe
      // the list anything back.
      expect(
        _item(quantity: 6000, writtenOffQuantity: 9000).remainingQuantity,
        0,
      );
    });

    test('is null when the line never asked for a quantity', () {
      expect(_item(quantity: null).remainingQuantity, isNull);
    });
  });

  group('json — B6', () {
    test('sums the write-off embed instead of reading a balance column', () {
      final item = ShoppingListItem.fromJson({
        'id': 'item-1',
        'quantity': 6000,
        'entered_on': '2026-08-26',
        'picked': false,
        'not_found': false,
        'fulfilled_on': null,
        'removed_on': null,
        'product_type': {
          'id': 'type-1',
          'name': 'Leite',
          'category_id': 'cat-1',
          'base_unit': 'liter',
          'active': true,
          'category': {'id': 'cat-1', 'name': 'Bebidas', 'active': true},
        },
        'preferred_brand': null,
        'preferred_product': null,
        'list_write_off': [
          {'quantity_written_off': 2000},
          {'quantity_written_off': 1000},
        ],
      });

      expect(item.writtenOffQuantity, 3000);
      expect(item.remainingQuantity, 3000);
      expect(item.isOpen, isTrue);
    });

    test('an absent embed is no write-off, not a crash', () {
      // The list screen's own query does not ask for the embed; only the
      // write-off read does.
      final item = ShoppingListItem.fromJson({
        'id': 'item-1',
        'quantity': 6000,
        'entered_on': '2026-08-26',
        'picked': false,
        'not_found': false,
        'product_type': {
          'id': 'type-1',
          'name': 'Leite',
          'category_id': 'cat-1',
          'base_unit': 'liter',
          'active': true,
          'category': {'id': 'cat-1', 'name': 'Bebidas', 'active': true},
        },
      });

      expect(item.writtenOffQuantity, 0);
      expect(item.fulfilledOn, isNull);
      expect(item.removedOn, isNull);
    });

    test('reads the two dates and writes them back as columns', () {
      final json = _item(
        fulfilledOn: DateTime(2026, 8, 30),
        removedOn: DateTime(2026, 8, 31),
      ).toJson();

      expect(json['fulfilled_on'], '2026-08-30');
      expect(json['removed_on'], '2026-08-31');
      // The sum is another table's, and writing it back would invent a
      // column PostgREST would refuse.
      expect(json.containsKey('written_off_quantity'), isFalse);
    });

    test('an open line writes both dates as null', () {
      final json = _item().toJson();

      expect(json['fulfilled_on'], isNull);
      expect(json['removed_on'], isNull);
    });
  });

  group('equality — B6', () {
    test('covers the three new fields', () {
      // Without this, a line that has just been written off does not repaint:
      // Riverpod filters an update with `==`.
      expect(_item(), _item());
      expect(_item(), isNot(_item(writtenOffQuantity: 1)));
      // Without this case the new field could stay out of the `==` with
      // nothing to say so — and screen 1 would not repaint after a
      // correction that touched only the trail.
      expect(_item(), isNot(_item(writeOffCount: 1)));
      expect(_item(), isNot(_item(fulfilledOn: DateTime(2026, 8, 30))));
      expect(_item(), isNot(_item(removedOn: DateTime(2026, 8, 30))));
      expect(
        _item(fulfilledOn: DateTime(2026, 8, 30)).hashCode,
        _item(fulfilledOn: DateTime(2026, 8, 30)).hashCode,
      );
    });
  });

  group('the trail count — H9', () {
    test('reads the SIZE of the embed beside its sum', () {
      final item = ShoppingListItem.fromJson({
        'id': 'item-1',
        'quantity': 6000,
        'entered_on': '2026-08-28',
        'product_type': {
          'id': 'type-1',
          'name': 'Leite',
          'category_id': 'cat-1',
          'base_unit': 'liter',
          'category': {'id': 'cat-1', 'name': 'Bebidas'},
        },
        'list_write_off': [
          {'quantity_written_off': 2000},
          {'quantity_written_off': 0},
        ],
      });

      expect(item.writtenOffQuantity, 2000);
      // The zero row counts: it is what closes an item with no quantity, and
      // the count is the only thing that knows it is there (D6).
      expect(item.writeOffCount, 2);
    });

    test('no embed at all is zero of both', () {
      final item = ShoppingListItem.fromJson({
        'id': 'item-1',
        'quantity': 6000,
        'entered_on': '2026-08-28',
        'product_type': {
          'id': 'type-1',
          'name': 'Leite',
          'category_id': 'cat-1',
          'base_unit': 'liter',
          'category': {'id': 'cat-1', 'name': 'Bebidas'},
        },
      });

      expect(item.writtenOffQuantity, 0);
      expect(item.writeOffCount, 0);
    });
  });

  group('the transitions of H9 (rule 7)', () {
    test('a purchase closes the line on the RECEIPT\'s day', () {
      final closed = _item().fulfilledBy(DateTime(2026, 8, 18, 23, 59));

      // Rounded to the day, so an instant carrying an hour never breaks the
      // `==` of a line that did not change (rule 9).
      expect(closed.fulfilledOn, DateTime(2026, 8, 18));
      expect(closed.isOpen, isFalse);
    });

    test('the undo reopens it — and `copyWith` could not', () {
      final closed = _item(fulfilledOn: DateTime(2026, 8, 18));

      expect(closed.restoredToList().fulfilledOn, isNull);
      expect(closed.restoredToList().isOpen, isTrue);
      // `copyWith(fulfilledOn: null)` keeps what is there, which is exactly
      // why the transition is written against the factory.
      expect(closed.copyWith().fulfilledOn, DateTime(2026, 8, 18));
    });

    test('the undo does NOT resurrect a line removed by hand — D1', () {
      final both = _item(
        fulfilledOn: DateTime(2026, 8, 18),
        removedOn: DateTime(2026, 8, 20),
      );

      final back = both.restoredToList();
      expect(back.fulfilledOn, isNull);
      expect(back.removedOn, DateTime(2026, 8, 20));
      expect(back.isOpen, isFalse);
    });

    test('everything else survives the trip', () {
      final closed = _item(
        brand: _brand,
        product: _packagedLeaf(),
        picked: true,
        notFound: true,
        writtenOffQuantity: 2000,
        writeOffCount: 3,
        fulfilledOn: DateTime(2026, 8, 18),
      );

      final back = closed.restoredToList();
      expect(back.preferredBrand, _brand);
      expect(back.preferredProduct, _packagedLeaf());
      expect(back.picked, isTrue);
      expect(back.notFound, isTrue);
      expect(back.writtenOffQuantity, 2000);
      expect(back.writeOffCount, 3);
      expect(back.enteredOn, closed.enteredOn);
    });
  });

  group('the preference falls when the catalog row is deactivated — D7', () {
    test('an active brand and packaging are the effective ones', () {
      final item = _item(brand: _brand, product: _packagedLeaf());

      expect(item.effectivePreferredBrand, _brand);
      expect(item.effectivePreferredProduct, _packagedLeaf());
      expect(item.effectiveLabel, 'Leite Italac 1 L');
    });

    test('a deactivated brand falls SILENTLY, with no write at all', () {
      final item = _item(
        brand: Brand(id: 'brand-1', name: 'Italac', active: false),
        product: _packagedLeaf(),
      );

      expect(item.effectivePreferredBrand, isNull);
      // The stored preference is untouched — it comes back the day the brand
      // is reactivated, which is better than what the requirement asked for.
      expect(item.preferredBrand, isNotNull);
      expect(item.effectiveLabel, 'Leite 1 L');
    });

    test('a deactivated packaging falls the same way', () {
      final item = _item(
        brand: _brand,
        product: _packagedLeaf().deactivated(),
      );

      expect(item.effectivePreferredProduct, isNull);
      expect(item.effectiveLabel, 'Leite Italac');
    });

    test('with both gone the line is the type, and nothing else', () {
      final item = _item(
        brand: Brand(id: 'brand-1', name: 'Italac', active: false),
        product: _packagedLeaf().deactivated(),
      );

      expect(item.effectiveLabel, 'Leite');
      // The stored label still says everything: only the READ changed.
      expect(item.label, 'Leite Italac 1 L');
    });

    test('a line with no preference reads the same either way', () {
      expect(_item().effectiveLabel, 'Leite');
      expect(_item().effectivePreferredBrand, isNull);
      expect(_item().effectivePreferredProduct, isNull);
    });
  });
}

