import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';

ShoppingListItem _item({
  required String id,
  required String typeName,
  required String categoryId,
  required String categoryName,
}) => ShoppingListItem(
  id: id,
  type: ProductType(
    id: 'type-$id',
    name: typeName,
    categoryId: categoryId,
    baseUnit: BaseUnit.unit,
  ),
  category: Category(id: categoryId, name: categoryName),
  enteredOn: DateTime(2026, 8, 28),
);

void main() {
  group('groupByCategory', () {
    test('puts each category in its own group, alphabetically', () {
      final groups = groupByCategory(
        [
          _item(
            id: '1',
            typeName: 'Leite',
            categoryId: 'c2',
            categoryName: 'Bebidas',
          ),
          _item(
            id: '2',
            typeName: 'Sabão em pó',
            categoryId: 'c3',
            categoryName: 'Limpeza',
          ),
          _item(
            id: '3',
            typeName: 'Acém',
            categoryId: 'c1',
            categoryName: 'Açougue',
          ),
        ].lock,
      );

      expect(groups.length, 3);
      expect(
        groups.map((g) => g.category.name),
        ['Açougue', 'Bebidas', 'Limpeza'],
      );
    });

    test('"Açougue" comes BEFORE "Bebidas" — the accent is not a code unit', () {
      // The test that fails the day someone swaps normalizeName for a raw
      // compareTo: 'Á' is U+00C1 and would land after 'Z'.
      final groups = groupByCategory(
        [
          _item(
            id: '1',
            typeName: 'Leite',
            categoryId: 'c2',
            categoryName: 'Bebidas',
          ),
          _item(
            id: '2',
            typeName: 'Acém',
            categoryId: 'c1',
            categoryName: 'Açougue',
          ),
        ].lock,
      );

      expect(groups.first.category.name, 'Açougue');
    });

    test('orders the items inside a group by the type name', () {
      final groups = groupByCategory(
        [
          _item(
            id: '1',
            typeName: 'Refrigerante',
            categoryId: 'c1',
            categoryName: 'Bebidas',
          ),
          _item(
            id: '2',
            typeName: 'Água',
            categoryId: 'c1',
            categoryName: 'Bebidas',
          ),
          _item(
            id: '3',
            typeName: 'Leite',
            categoryId: 'c1',
            categoryName: 'Bebidas',
          ),
        ].lock,
      );

      expect(groups.length, 1);
      expect(
        groups.single.items.map((i) => i.type.name),
        ['Água', 'Leite', 'Refrigerante'],
      );
    });

    test('two items of the same type keep a stable order', () {
      // Two types with the same name do not exist — the unique index sees to
      // that — but two items of the SAME type on one list do, and without the
      // id as tiebreak their order would change on every fetch.
      final items = [
        _item(
          id: 'b',
          typeName: 'Leite',
          categoryId: 'c1',
          categoryName: 'Bebidas',
        ),
        _item(
          id: 'a',
          typeName: 'Leite',
          categoryId: 'c1',
          categoryName: 'Bebidas',
        ),
      ].lock;

      expect(
        groupByCategory(items).single.items.map((i) => i.id),
        groupByCategory(items).single.items.map((i) => i.id),
      );
      expect(groupByCategory(items).single.items.map((i) => i.id), ['a', 'b']);
    });

    test('an empty list has no groups', () {
      expect(groupByCategory(const IList<ShoppingListItem>.empty()), isEmpty);
    });

    test('the group compares by category and items', () {
      final category = Category(id: 'c1', name: 'Bebidas');
      final item = _item(
        id: '1',
        typeName: 'Leite',
        categoryId: 'c1',
        categoryName: 'Bebidas',
      );

      final group = ShoppingListGroup(category: category, items: [item].lock);

      expect(
        group,
        ShoppingListGroup(category: category, items: [item].lock),
      );
      expect(
        group.hashCode,
        ShoppingListGroup(category: category, items: [item].lock).hashCode,
      );
      expect(
        group,
        isNot(
          ShoppingListGroup(
            category: category,
            items: const IList<ShoppingListItem>.empty(),
          ),
        ),
      );
      expect(group.toString(), contains('Bebidas'));
    });
  });
}
