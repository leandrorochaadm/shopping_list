import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';

void main() {
  ProductRegistration cocaCola({String? id, String? brandId = 'b1', String description = '', bool active = true}) =>
      ProductRegistration(id: id, productTypeId: 't1', brandId: brandId, description: description, active: active);

  Packaging bottle(String size, BaseUnit unit) => Packaging.typed(pieceCount: '1', pieceSize: size, baseUnit: unit);

  group('identity — tipo + marca + descrição', () {
    test('is the same registration however the description was written', () {
      expect(cocaCola(description: 'Zero').hasSameIdentityAs(cocaCola(description: ' zero ')), isTrue);
    });

    test('treats an empty description as a value, not as missing', () {
      // It is what tells "Coca-Cola" from "Coca-Cola zero".
      expect(cocaCola().hasSameIdentityAs(cocaCola(description: 'Zero')), isFalse);
      expect(cocaCola().description, '');
      expect(cocaCola(description: '   ').description, '');
    });

    test('treats a missing brand as a value — decision B2', () {
      // Two "acém moído with no brand" are the same registration. In Postgres
      // that takes NULLS NOT DISTINCT; here it is plain equality, and it is
      // the app that has to answer the user.
      final withoutBrand = cocaCola(brandId: null);

      expect(withoutBrand.hasSameIdentityAs(cocaCola(brandId: null)), isTrue);
      expect(withoutBrand.hasSameIdentityAs(cocaCola()), isFalse);
    });

    test('is a different registration under a different type', () {
      final other = ProductRegistration(productTypeId: 't2', brandId: 'b1');

      expect(cocaCola().hasSameIdentityAs(other), isFalse);
    });

    test('finds the conflict among the DEACTIVATED ones too — B3', () {
      // The screen then offers to reactivate, not to create a second one.
      final existing = [cocaCola(id: '1', active: false)];

      final conflict = cocaCola().conflictIn(existing);

      expect(conflict?.id, '1');
      expect(conflict!.active, isFalse);
      expect(conflict.reactivated().active, isTrue);
    });

    test('finds nothing when nothing matches', () {
      expect(cocaCola().conflictIn([cocaCola(description: 'Zero')]), isNull);
      expect(cocaCola().conflictIn(const []), isNull);
    });
  });

  group('messages and JSON', () {
    test('says what is wrong, in pt-BR', () {
      expect(const UnexpectedScaleCode().toString(), contains(const UnexpectedScaleCode().message));
    });

    test('says what to do, in pt-BR', () {
      expect(const MissingPackaging().message, 'Informe ao menos uma embalagem para este produto.');
      expect(const MissingPackaging().toString(), contains('embalagem'));
    });

    test('survives the round trip through JSON', () {
      for (final registration in [
        cocaCola(id: '1'),
        cocaCola(id: '2', brandId: null, description: 'zero', active: false),
      ]) {
        expect(ProductRegistration.fromJson(registration.toJson()), registration);
      }
    });

    test('does not write selling_mode', () {
      final json = cocaCola(id: '1').toJson();

      expect(json.containsKey('selling_mode'), isFalse);
      expect(json.keys.toSet(), {'id', 'product_type_id', 'brand_id', 'description', 'active'});
    });
  });

  group('transitions and equality', () {
    test('is deactivated and reactivated, never deleted', () {
      expect(cocaCola().deactivated().active, isFalse);
      expect(cocaCola(active: false).reactivated().active, isTrue);
    });

    test('clears the brand with an empty string, since null means "keep"', () {
      // `??` cannot clear a nullable field, and "Sem marca" is a real answer.
      expect(cocaCola().copyWith(brandId: '').brandId, isNull);
      expect(cocaCola().copyWith().brandId, 'b1');
      expect(cocaCola().copyWith(brandId: 'b2').brandId, 'b2');
    });

    test('compares by every field it has', () {
      final base = cocaCola(id: '1', description: 'zero');
      final same = cocaCola(id: '1', description: 'zero');

      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(base.copyWith(id: '2')));
      expect(base, isNot(base.copyWith(productTypeId: 't2')));
      expect(base, isNot(base.copyWith(brandId: 'b2')));
      expect(base, isNot(base.copyWith(brandId: '')));
      expect(base, isNot(base.copyWith(description: 'diet')));
      expect(base, isNot(base.deactivated()));
      expect(base.toString(), contains('active: true'));
      expect(base.toString(), isNot(contains('by_piece')));
    });
  });

  group('Product — the leaf', () {
    test('exists for a weight-sold product, with no packaging — B1', () {
      // The purchase always has one kind of target.
      const leaf = Product(productRegistrationId: 'r1');

      expect(leaf.isLoose, isTrue);
      expect(leaf.packaging, isNull);
      expect(leaf.toString(), contains('a granel'));
    });

    test('carries the packaging of a by-piece product', () {
      final leaf = Product(productRegistrationId: 'r1', packaging: bottle('350', BaseUnit.milliliter));

      expect(leaf.isLoose, isFalse);
      expect(leaf.packaging!.totalContent, 350);
    });

    test('recognises the same packaging written two ways', () {
      final asLiters = Product(
        productRegistrationId: 'r1',
        packaging: Packaging.typed(pieceCount: '2', pieceSize: '175', baseUnit: BaseUnit.milliliter),
      );
      final asMilliliters = Product(productRegistrationId: 'r1', packaging: bottle('350', BaseUnit.milliliter));

      expect(asLiters.hasSameContentAs(asMilliliters), isTrue);
    });

    test('never confuses two leaves of different registrations', () {
      final mine = Product(productRegistrationId: 'r1', packaging: bottle('350', BaseUnit.milliliter));
      final theirs = Product(productRegistrationId: 'r2', packaging: bottle('350', BaseUnit.milliliter));

      expect(mine.hasSameContentAs(theirs), isFalse);
    });

    test('allows a registration only one weight-sold leaf', () {
      const one = Product(productRegistrationId: 'r1');
      const another = Product(productRegistrationId: 'r1');

      expect(one.hasSameContentAs(another), isTrue);
      expect(
        one.hasSameContentAs(Product(productRegistrationId: 'r1', packaging: bottle('350', BaseUnit.milliliter))),
        isFalse,
      );
    });

    test('is deactivated on its own, without touching the registration', () {
      // Decision 23: this is what "deactivate the packaging" reaches.
      const leaf = Product(id: 'p1', productRegistrationId: 'r1');

      expect(leaf.deactivated().active, isFalse);
      expect(leaf.deactivated().productRegistrationId, 'r1');
      expect(leaf.deactivated().reactivated().active, isTrue);
    });

    test('survives the round trip through JSON, with and without packaging', () {
      final withPackaging = Product(
        id: 'p1',
        productRegistrationId: 'r1',
        packaging: bottle('350', BaseUnit.milliliter),
      );
      const withoutPackaging = Product(id: 'p2', productRegistrationId: 'r1');

      expect(Product.fromJson(withPackaging.toJson()), withPackaging);
      expect(Product.fromJson(withoutPackaging.toJson()), withoutPackaging);
      expect(withoutPackaging.toJson()['total_content'], isNull);
    });

    test('compares by every field it has', () {
      const leaf = Product(id: 'p1', productRegistrationId: 'r1');

      expect(leaf, const Product(id: 'p1', productRegistrationId: 'r1'));
      expect(leaf.hashCode, const Product(id: 'p1', productRegistrationId: 'r1').hashCode);
      expect(leaf, isNot(leaf.deactivated()));
      expect(leaf, isNot(leaf.copyWith(packaging: bottle('1', BaseUnit.unit))));
    });
  });

  group('labelWith — what the item dialog and the list line write (M-a)', () {
    final coke = Brand(id: 'b1', name: 'Coca-Cola');

    test('brand and description, in this order', () {
      expect(cocaCola(description: 'zero').labelWith(coke), 'Coca-Cola zero');
    });

    test('only the brand when there is no description', () {
      expect(cocaCola().labelWith(coke), 'Coca-Cola');
    });

    test('only the description when there is no brand', () {
      expect(cocaCola(brandId: null, description: 'integral').labelWith(null), 'integral');
    });

    test('"Sem marca" when there is neither, never a blank line', () {
      expect(cocaCola(brandId: null).labelWith(null), 'Sem marca');
    });
  });

  group('changesIdentityOf — raw, not normalized', () {
    final original = cocaCola(id: 'r1', description: 'acem');

    test('is false when nothing changed', () {
      expect(cocaCola(id: 'r1', description: 'acem').changesIdentityOf(original), isFalse);
    });

    test('is true when only the type changed', () {
      expect(original.copyWith(productTypeId: 't2').changesIdentityOf(original), isTrue);
    });

    test('is true when only the brand changed', () {
      expect(original.copyWith(brandId: 'b2').changesIdentityOf(original), isTrue);
    });

    test('is true when the brand was cleared', () {
      final cleared = original.copyWith(brandId: '');
      expect(cleared.brandId, isNull);
      expect(cleared.changesIdentityOf(original), isTrue);
    });

    test('is true when only the description changed', () {
      expect(original.copyWith(description: 'moído').changesIdentityOf(original), isTrue);
    });

    test('an accent fixed is an edit, though the same identity', () {
      final fixed = original.copyWith(description: 'acém');
      expect(fixed.changesIdentityOf(original), isTrue);
      expect(fixed.hasSameIdentityAs(original), isTrue);
    });

    test('ignores active — it is not identity', () {
      expect(original.deactivated().changesIdentityOf(original), isFalse);
    });
  });

  group('registrationConflictMessage', () {
    test('says it exists when the one in the way is active', () {
      expect(registrationConflictMessage(cocaCola()), 'Já existe esse produto cadastrado.');
    });

    test('says it is deactivated when it is', () {
      expect(registrationConflictMessage(cocaCola(active: false)), 'Esse produto já existe, mas está desativado.');
    });
  });

  group('selling_mode column dropped', () {
    final expected = ProductRegistration(id: 'reg1', productTypeId: 'type-1', brandId: 'brand-1', description: 'zero');

    test('ignores selling_mode from old rows', () {
      final raw = {'id': 'reg1', 'product_type_id': 'type-1', 'brand_id': 'brand-1', 'description': 'zero'};

      expect(ProductRegistration.fromJson(raw), expected);
      expect(ProductRegistration.fromJson({...raw, 'selling_mode': null}), expected);
      expect(ProductRegistration.fromJson({...raw, 'selling_mode': 'by_weight'}), expected);
      expect(ProductRegistration.fromJson({...raw, 'selling_mode': 'by_kilo'}), expected);
    });

    test('reads a row that still carries selling_mode', () {
      final raw = {
        'id': 'reg1',
        'product_type_id': 'type-1',
        'brand_id': 'brand-1',
        'description': 'zero',
        'selling_mode': 'by_piece',
      };

      expect(ProductRegistration.fromJson(raw), expected);
    });
  });
}
