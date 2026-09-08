import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';

void main() {
  ProductRegistration cocaCola({
    String? id,
    String? brandId = 'b1',
    String description = '',
    SellingMode sellingMode = SellingMode.byPiece,
    bool active = true,
  }) => ProductRegistration(
    id: id,
    productTypeId: 't1',
    brandId: brandId,
    description: description,
    sellingMode: sellingMode,
    active: active,
  );

  Packaging bottle(String size, BaseUnit unit) =>
      Packaging.typed(pieceCount: '1', pieceSize: size, baseUnit: unit);

  group('identity — tipo + marca + descrição', () {
    test('is the same registration however the description was written', () {
      expect(
        cocaCola(
          description: 'Zero',
        ).hasSameIdentityAs(cocaCola(description: ' zero ')),
        isTrue,
      );
    });

    test('treats an empty description as a value, not as missing', () {
      // It is what tells "Coca-Cola" from "Coca-Cola zero".
      expect(
        cocaCola().hasSameIdentityAs(cocaCola(description: 'Zero')),
        isFalse,
      );
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
      final other = ProductRegistration(
        productTypeId: 't2',
        brandId: 'b1',
        sellingMode: SellingMode.byPiece,
      );

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

  group('selling mode — the two rules, and they are opposites', () {
    test('refuses a by-piece registration with no packaging', () {
      // Without one there is no way to convert what the receipt says into the
      // base unit.
      expect(
        () => cocaCola().checkPackagings(const IListConst([])),
        throwsA(isA<MissingPackaging>()),
      );
    });

    test('accepts a by-piece registration with one packaging', () {
      expect(
        () => cocaCola().checkPackagings(
          IList([bottle('350', BaseUnit.milliliter)]),
        ),
        returnsNormally,
      );
    });

    test('refuses a by-weight registration that carries packaging', () {
      // The list disappears from the screen when "a peso" is chosen, so a row
      // arriving here means state was kept that should have been dropped.
      expect(
        () => cocaCola(
          sellingMode: SellingMode.byWeight,
        ).checkPackagings(IList([bottle('350', BaseUnit.milliliter)])),
        throwsA(isA<UnexpectedPackaging>()),
      );
    });

    test('accepts a by-weight registration with no packaging', () {
      expect(
        () => cocaCola(
          sellingMode: SellingMode.byWeight,
        ).checkPackagings(const IListConst([])),
        returnsNormally,
      );
    });

    test('says what to do, in pt-BR', () {
      expect(
        const MissingPackaging().message,
        'Informe ao menos uma embalagem para este produto.',
      );
      expect(
        const UnexpectedPackaging().message,
        'Produto vendido solto não tem embalagem.',
      );
      expect(const MissingPackaging().toString(), contains('embalagem'));
      expect(const UnexpectedPackaging().toString(), contains('solto'));
    });

    test('survives the round trip through JSON, both modes', () {
      for (final mode in SellingMode.values) {
        final registration = cocaCola(id: '1', sellingMode: mode);
        expect(
          ProductRegistration.fromJson(registration.toJson()),
          registration,
        );
      }
      expect(
        () => SellingMode.fromJson('by_kilo'),
        throwsA(isA<ArgumentError>()),
      );
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
      expect(cocaCola(id: '1'), cocaCola(id: '1'));
      expect(cocaCola(id: '1').hashCode, cocaCola(id: '1').hashCode);
      expect(cocaCola(id: '1'), isNot(cocaCola(id: '2')));
      expect(cocaCola(id: '1'), isNot(cocaCola(id: '1').deactivated()));
      expect(cocaCola().toString(), contains('by_piece'));
    });
  });

  group('Product — the leaf', () {
    test('exists for a weight-sold product, with no packaging — B1', () {
      // The purchase always has one kind of target.
      const leaf = Product(productRegistrationId: 'r1');

      expect(leaf.isSoldByWeight, isTrue);
      expect(leaf.packaging, isNull);
      expect(leaf.toString(), contains('a peso'));
    });

    test('carries the packaging of a by-piece product', () {
      final leaf = Product(
        productRegistrationId: 'r1',
        packaging: bottle('350', BaseUnit.milliliter),
      );

      expect(leaf.isSoldByWeight, isFalse);
      expect(leaf.packaging!.totalContent, 350);
    });

    test('recognises the same packaging written two ways', () {
      final asLiters = Product(
        productRegistrationId: 'r1',
        packaging: Packaging.typed(
          pieceCount: '2',
          pieceSize: '175',
          baseUnit: BaseUnit.milliliter,
        ),
      );
      final asMilliliters = Product(
        productRegistrationId: 'r1',
        packaging: bottle('350', BaseUnit.milliliter),
      );

      expect(asLiters.hasSameContentAs(asMilliliters), isTrue);
    });

    test('never confuses two leaves of different registrations', () {
      final mine = Product(
        productRegistrationId: 'r1',
        packaging: bottle('350', BaseUnit.milliliter),
      );
      final theirs = Product(
        productRegistrationId: 'r2',
        packaging: bottle('350', BaseUnit.milliliter),
      );

      expect(mine.hasSameContentAs(theirs), isFalse);
    });

    test('allows a registration only one weight-sold leaf', () {
      const one = Product(productRegistrationId: 'r1');
      const another = Product(productRegistrationId: 'r1');

      expect(one.hasSameContentAs(another), isTrue);
      expect(
        one.hasSameContentAs(
          Product(
            productRegistrationId: 'r1',
            packaging: bottle('350', BaseUnit.milliliter),
          ),
        ),
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

    test(
      'survives the round trip through JSON, with and without packaging',
      () {
        final withPackaging = Product(
          id: 'p1',
          productRegistrationId: 'r1',
          packaging: bottle('350', BaseUnit.milliliter),
        );
        const withoutPackaging = Product(id: 'p2', productRegistrationId: 'r1');

        expect(Product.fromJson(withPackaging.toJson()), withPackaging);
        expect(Product.fromJson(withoutPackaging.toJson()), withoutPackaging);
        expect(withoutPackaging.toJson()['total_content'], isNull);
      },
    );

    test('compares by every field it has', () {
      const leaf = Product(id: 'p1', productRegistrationId: 'r1');

      expect(leaf, const Product(id: 'p1', productRegistrationId: 'r1'));
      expect(
        leaf.hashCode,
        const Product(id: 'p1', productRegistrationId: 'r1').hashCode,
      );
      expect(leaf, isNot(leaf.deactivated()));
      expect(
        leaf,
        isNot(leaf.copyWith(packaging: bottle('1', BaseUnit.unit))),
      );
    });
  });
}
