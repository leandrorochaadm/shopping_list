import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/catalog_maintenance.dart';
import 'package:shopping_list/domain/models/product_type.dart';

/// The rules of H10 — the ones that keep the maintenance screen from quietly
/// ruining the history it exists to protect.
void main() {
  ProductType type({
    required String id,
    required String name,
    BaseUnit unit = BaseUnit.liter,
    bool active = true,
  }) => ProductType(
    id: id,
    name: name,
    categoryId: 'cat-1',
    baseUnit: unit,
    active: active,
  );

  final milk = type(id: 'type-1', name: 'Leite');
  final juice = type(id: 'type-2', name: 'Suco');
  final beef = type(id: 'type-3', name: 'Acém', unit: BaseUnit.kilogram);
  final oldMilk = type(id: 'type-4', name: 'Leite antigo', active: false);

  IList<ProductType> compatible(BaseUnit unit, {String? excluding}) =>
      typesCompatibleWith(
        [milk, juice, beef, oldMilk].lock,
        unit,
        excludingId: excluding,
      );

  group('typesCompatibleWith', () {
    test('offers the types of the SAME base unit', () {
      expect(compatible(BaseUnit.liter), [milk, juice]);
    });

    test('leaves out another base unit — the total would add volume to weight', () {
      expect(compatible(BaseUnit.kilogram), [beef]);
      expect(compatible(BaseUnit.kilogram), isNot(contains(milk)));
    });

    test('leaves out the type being moved from', () {
      expect(compatible(BaseUnit.liter, excluding: 'type-1'), [juice]);
    });

    test('leaves out the deactivated ones', () {
      // `oldMilk` is a litre type and is still not offered: moving a product
      // under a deactivated type is writing what nobody will see.
      expect(compatible(BaseUnit.liter), isNot(contains(oldMilk)));
    });

    test('answers with nothing when no type shares the unit', () {
      expect(compatible(BaseUnit.unit), isEmpty);
    });
  });

  group('canChangeBaseUnit', () {
    test('allows it on a type with no product and no purchase', () {
      expect(canChangeBaseUnit(productCount: 0, purchaseCount: 0), isTrue);
    });

    test('refuses it once a product exists', () {
      expect(canChangeBaseUnit(productCount: 1, purchaseCount: 0), isFalse);
    });

    test('refuses it once a purchase exists', () {
      expect(canChangeBaseUnit(productCount: 0, purchaseCount: 1), isFalse);
    });

    test('refuses it with both', () {
      expect(canChangeBaseUnit(productCount: 3, purchaseCount: 7), isFalse);
    });
  });

  group('the rule exceptions', () {
    test('IncompatibleBaseUnit spells the two units out', () {
      const failure = IncompatibleBaseUnit(
        productLabel: 'Azeite 500 ml',
        typeName: 'Acém moído',
        from: BaseUnit.liter,
        to: BaseUnit.kilogram,
      );

      expect(
        failure.message,
        'A medida não bate: "Azeite 500 ml" é medido em litros e '
        '"Acém moído" em quilos. Corrija a unidade base do tipo antes de '
        'mover.',
      );
      expect(failure.toString(), contains('IncompatibleBaseUnit'));
    });

    test('IncompatibleBaseUnit knows the third unit too', () {
      const failure = IncompatibleBaseUnit(
        productLabel: 'Papel',
        typeName: 'Leite',
        from: BaseUnit.unit,
        to: BaseUnit.liter,
      );
      expect(failure.message, contains('unidades'));
    });

    test('BaseUnitLocked says why, not just no', () {
      const failure = BaseUnitLocked();
      expect(
        failure.message,
        'Este tipo já tem produtos ou compras. A unidade base não pode mais '
        'mudar.',
      );
      expect(failure.toString(), contains('BaseUnitLocked'));
    });

    test('TypeInUseOnList derives the singular from the count', () {
      const failure = TypeInUseOnList(name: 'Achocolatado', itemCount: 1);
      expect(
        failure.message,
        'Achocolatado está em 1 item da lista — ele será removido.',
      );
    });

    test('TypeInUseOnList derives the plural from the count', () {
      const failure = TypeInUseOnList(name: 'Achocolatado', itemCount: 3);
      expect(
        failure.message,
        'Achocolatado está em 3 itens da lista — eles serão removidos.',
      );
      expect(failure.toString(), contains('TypeInUseOnList'));
    });
  });
}
