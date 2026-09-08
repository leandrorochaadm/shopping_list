import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/product_type_group.dart';

/// The grouping the `#1a` panel draws. It lived inside the widget until
/// 29/08/2026, where no test could reach it — rule 1 moved it here.
void main() {
  final drinks = Category(id: 'cat-1', name: 'Bebidas');
  final acids = Category(id: 'cat-2', name: 'Ácido');
  final empty = Category(id: 'cat-3', name: 'Limpeza');

  ProductType type(String id, String name, {String category = 'cat-1'}) =>
      ProductType(
        id: id,
        name: name,
        categoryId: category,
        baseUnit: BaseUnit.milliliter,
      );

  group('groupTypesByCategory', () {
    test('a type whose category did not come back falls in Sem categoria', () {
      // `categoryId` is required, so "no category" is never a null: it is a
      // category that was not in the read — soft-deleted, or simply not
      // fetched. Dropping the type would take it off the panel with nothing
      // on screen saying why.
      final groups = groupTypesByCategory(
        [type('t1', 'Refrigerante', category: 'cat-99')].lock,
        [drinks].lock,
      );

      expect(groups.single.name, 'Sem categoria');
      expect(groups.single.types.single.id, 't1');
    });

    test('the groups are ordered by the NORMALIZED name', () {
      // 'Á' after 'B' is what a raw code-unit sort answers, and it is what
      // puts an accented category at the end of the panel.
      final groups = groupTypesByCategory(
        [
          type('t1', 'Refrigerante', category: 'cat-1'),
          type('t2', 'Vinagre', category: 'cat-2'),
        ].lock,
        [drinks, acids].lock,
      );

      expect(groups.map((group) => group.name), ['Ácido', 'Bebidas']);
    });

    test('a category with no type of its own does not appear', () {
      final groups = groupTypesByCategory(
        [type('t1', 'Refrigerante', category: 'cat-1')].lock,
        [drinks, empty].lock,
      );

      expect(groups.map((group) => group.name), ['Bebidas']);
    });
  });

  group('ProductTypeGroup', () {
    ProductTypeGroup made({String name = 'Bebidas', String typeId = 't1'}) =>
        ProductTypeGroup(
          name: name,
          types: [type(typeId, 'Refrigerante', category: 'cat-1')].lock,
        );

    test('equality covers every field', () {
      expect(made(), made());
      expect(made().hashCode, made().hashCode);
      expect(made(), isNot(made(name: 'Carnes')));
      expect(made(), isNot(made(typeId: 't2')));
    });
  });
}
