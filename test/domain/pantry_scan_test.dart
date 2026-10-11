import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/monthly_average.dart';
import 'package:shopping_list/domain/models/pantry_scan.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';

final _category = Category(id: 'cat-1', name: 'Mercearia');

ProductType _type(String? id) => ProductType(
  id: id,
  name: 'Café',
  categoryId: 'cat-1',
  baseUnit: BaseUnit.gram,
);

MonthlyAverage _line(String id) => MonthlyAverage(
  type: _type(id),
  category: _category,
  average: 1000,
  consumedInMonth: 0,
);

ShoppingListItem _item(
  String typeId, {
  bool notFound = false,
  DateTime? fulfilledOn,
}) => ShoppingListItem(
  id: 'item-$typeId',
  type: _type(typeId),
  category: _category,
  enteredOn: DateTime(2026, 10, 1),
  notFound: notFound,
  fulfilledOn: fulfilledOn,
);

void main() {
  group('pantryScanOf', () {
    final pantry = [_line('type-1'), _line('type-2')].lock;
    const noItems = IList<ShoppingListItem>.empty();

    test('a type in the pantry and off the list is ticked', () {
      expect(
        pantryScanOf(pantry, noItems, _type('type-1')),
        const TickLine('type-1'),
      );
    });

    test('a type with an open line is already on the list', () {
      expect(
        pantryScanOf(pantry, [_item('type-1')].lock, _type('type-1')),
        const LineAlreadyOnList('type-1'),
      );
    });

    test('a line marked "não encontrei" is still on the list', () {
      expect(
        pantryScanOf(
          pantry,
          [_item('type-1', notFound: true)].lock,
          _type('type-1'),
        ),
        const LineAlreadyOnList('type-1'),
      );
    });

    test('a line already bought does not lock the type', () {
      expect(
        pantryScanOf(
          pantry,
          [_item('type-1', fulfilledOn: DateTime(2026, 10, 2))].lock,
          _type('type-1'),
        ),
        const TickLine('type-1'),
      );
    });

    test('a type the pantry does not show is offered to the list', () {
      expect(
        pantryScanOf(pantry, noItems, _type('type-9')),
        const TypeNotInPantry(),
      );
    });

    test('outside the pantry wins over an open line of the type', () {
      expect(
        pantryScanOf(pantry, [_item('type-9')].lock, _type('type-9')),
        const TypeNotInPantry(),
      );
    });

    test('an empty pantry shows no type', () {
      expect(
        pantryScanOf(
          const IList<MonthlyAverage>.empty(),
          noItems,
          _type('type-1'),
        ),
        const TypeNotInPantry(),
      );
    });

    test('a type with no id is not in the pantry', () {
      expect(
        pantryScanOf(pantry, noItems, _type(null)),
        const TypeNotInPantry(),
      );
    });
  });

  group('equality', () {
    test('TickLine compares by the type id', () {
      expect(const TickLine('a'), const TickLine('a'));
      expect(const TickLine('a').hashCode, const TickLine('a').hashCode);
      expect(const TickLine('a'), isNot(const TickLine('b')));
    });

    test('LineAlreadyOnList compares by the type id', () {
      expect(const LineAlreadyOnList('a'), const LineAlreadyOnList('a'));
      expect(
        const LineAlreadyOnList('a').hashCode,
        const LineAlreadyOnList('a').hashCode,
      );
      expect(const LineAlreadyOnList('a'), isNot(const LineAlreadyOnList('b')));
    });

    test('the three outcomes differ from each other', () {
      expect(const TickLine('a'), isNot(const LineAlreadyOnList('a')));
      expect(const TypeNotInPantry(), const TypeNotInPantry());
      expect(
        const TypeNotInPantry().hashCode,
        const TypeNotInPantry().hashCode,
      );
    });
  });
}
