import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/catalog_entry.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/store.dart';

void main() {
  group('findNameConflict', () {
    test('finds the name however it was written', () {
      final existing = [Category(id: '1', name: 'Limpeza')];

      expect(findNameConflict(existing, 'limpeza')?.id, '1');
      expect(findNameConflict(existing, '  LIMPEZA '), isNotNull);
      expect(findNameConflict(existing, 'Carnes'), isNull);
    });

    test('ignores the accent, like the database does', () {
      final existing = [Store(id: '1', name: 'Açaí Center')];

      expect(findNameConflict(existing, 'acai center'), isNotNull);
    });

    test('FINDS the deactivated one too — decision B3', () {
      // The whole point: a deactivated "Limpeza" blocks a new one, and the
      // screen offers to reactivate it. Letting a second one be born is what
      // splits the history in two the day the first comes back.
      final existing = [Category(id: '1', name: 'Limpeza', active: false)];

      final conflict = findNameConflict(existing, 'Limpeza');

      expect(conflict, isNotNull);
      expect(conflict!.active, isFalse);
      expect(conflict.reactivated().active, isTrue);
    });

    test('IGNORES the row being renamed — D8', () {
      // Without `ignoringId`, correcting "Carrefur" to "Carrefour" (or just
      // an accent, on the very same row) would report a conflict with itself
      // and renaming would be impossible.
      final existing = [
        Store(id: '1', name: 'Carrefour'),
        Store(id: '2', name: 'Feira do Zé'),
      ];

      expect(findNameConflict(existing, 'Carrefour', ignoringId: '1'), isNull);
      // Another row with that name is still a conflict.
      expect(
        findNameConflict(existing, 'Carrefour', ignoringId: '2')?.id,
        '1',
      );
      // And creating passes nothing, so every row counts.
      expect(findNameConflict(existing, 'carrefour')?.id, '1');
    });

    test('an ignoringId that matches nobody changes nothing', () {
      final existing = [Store(id: '1', name: 'Carrefour')];
      expect(findNameConflict(existing, 'Carrefour', ignoringId: 'x')?.id, '1');
    });

    test('finds nothing for a blank candidate', () {
      // A blank name is refused by the entity, not by the guard — answering
      // "already exists" here would be the wrong sentence.
      expect(findNameConflict([Category(name: 'Limpeza')], '   '), isNull);
    });

    test('works the same for every catalog', () {
      expect(findNameConflict([Brand(name: 'Nestlé')], 'nestle'), isNotNull);
      expect(
        findNameConflict([Store(name: 'Carrefour')], 'CARREFOUR'),
        isNotNull,
      );
      expect(
        findNameConflict([
          ProductType(name: 'Leite', categoryId: 'c', baseUnit: BaseUnit.liter),
        ], ' leite '),
        isNotNull,
      );
    });
  });

  group('Category', () {
    test('trims the name and refuses a blank one', () {
      expect(Category(name: '  Limpeza ').name, 'Limpeza');
      expect(() => Category(name: '   '), throwsA(isA<BlankName>()));
      expect(const BlankName().message, 'Informe um nome.');
      expect(const BlankName().toString(), contains('Informe um nome'));
    });

    test('is deactivated and reactivated, never deleted', () {
      final category = Category(id: '1', name: 'Limpeza');

      expect(category.active, isTrue);
      expect(category.deactivated().active, isFalse);
      expect(category.deactivated().reactivated().active, isTrue);
      // The id survives the round trip: it is the same row.
      expect(category.deactivated().id, '1');
    });

    test('survives the round trip through JSON', () {
      final category = Category(id: '1', name: 'Limpeza', active: false);

      expect(Category.fromJson(category.toJson()), category);
      expect(Category(name: 'Limpeza').toJson().containsKey('id'), isFalse);
    });

    test('compares by every field it has', () {
      final category = Category(id: '1', name: 'Limpeza');

      expect(category, Category(id: '1', name: 'Limpeza'));
      expect(category.hashCode, Category(id: '1', name: 'Limpeza').hashCode);
      expect(category, isNot(category.deactivated()));
      expect(category, isNot(category.copyWith(name: 'Carnes')));
      expect(category.toString(), 'Category(Limpeza, active: true)');
    });
  });

  group('Brand', () {
    test('behaves like every other named catalog', () {
      expect(Brand(name: ' Nestlé ').name, 'Nestlé');
      expect(() => Brand(name: ''), throwsA(isA<BlankName>()));
      expect(Brand(name: 'Nestlé').deactivated().active, isFalse);
      expect(Brand(name: 'Nestlé').deactivated().reactivated().active, isTrue);
      expect(
        Brand.fromJson(Brand(id: '1', name: 'Nestlé').toJson()),
        Brand(id: '1', name: 'Nestlé'),
      );
      expect(Brand(name: 'Nestlé'), isNot(Brand(name: 'Italac')));
      expect(Brand(name: 'Nestlé').hashCode, Brand(name: 'Nestlé').hashCode);
      expect(Brand(name: 'Nestlé').toString(), 'Brand(Nestlé, active: true)');
    });
  });

  group('Store', () {
    test('behaves like every other named catalog', () {
      expect(Store(name: ' Carrefour ').name, 'Carrefour');
      expect(() => Store(name: ' '), throwsA(isA<BlankName>()));
      expect(Store(name: 'Carrefour').deactivated().active, isFalse);
      expect(Store(name: 'Feira').deactivated().reactivated().active, isTrue);
      expect(
        Store.fromJson(Store(id: '1', name: 'Feira').toJson()),
        Store(id: '1', name: 'Feira'),
      );
      expect(Store(name: 'Feira'), isNot(Store(name: 'Açougue')));
      expect(Store(name: 'Feira').hashCode, Store(name: 'Feira').hashCode);
      expect(Store(name: 'Feira').toString(), 'Store(Feira, active: true)');
    });
  });

  group('ProductType', () {
    ProductType leite({bool active = true}) => ProductType(
      id: '1',
      name: 'Leite',
      categoryId: 'c1',
      baseUnit: BaseUnit.liter,
      active: active,
    );

    test('carries the base unit, because it is the level that sums', () {
      expect(leite().baseUnit, BaseUnit.liter);
      expect(leite().measures, [MeasureUnit.milliliter, MeasureUnit.liter]);
    });

    test('points at the category by key, never by a copied name', () {
      // Renaming a category has to hold for the whole history.
      expect(leite().categoryId, 'c1');
      expect(leite().toJson()['category_id'], 'c1');
    });

    test('trims the name and refuses a blank one', () {
      expect(
        ProductType(
          name: '  Leite ',
          categoryId: 'c1',
          baseUnit: BaseUnit.liter,
        ).name,
        'Leite',
      );
      expect(
        () =>
            ProductType(name: ' ', categoryId: 'c1', baseUnit: BaseUnit.liter),
        throwsA(isA<BlankName>()),
      );
    });

    test('is deactivated and reactivated, never deleted', () {
      expect(leite().deactivated().active, isFalse);
      expect(leite(active: false).reactivated().active, isTrue);
    });

    test('survives the round trip through JSON', () {
      expect(ProductType.fromJson(leite().toJson()), leite());
    });

    test('compares by every field it has', () {
      expect(leite(), leite());
      expect(leite().hashCode, leite().hashCode);
      expect(leite(), isNot(leite().copyWith(baseUnit: BaseUnit.unit)));
      expect(leite(), isNot(leite().copyWith(categoryId: 'c2')));
      expect(leite().toString(), 'ProductType(Leite, liter, active: true)');
    });
  });
}
