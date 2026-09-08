import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';

/// The leaf. `hasSameContentAs` and the JSON round trip are exercised from
/// `packaging_test.dart` and `product_registration_test.dart`; what is here is
/// the leaf's own rules, and the one H10 adds.
void main() {
  ProductRegistration registration({bool active = true}) =>
      ProductRegistration(
        id: 'reg-1',
        productTypeId: 'type-1',
        sellingMode: SellingMode.byPiece,
        active: active,
      );

  Product leaf({bool active = true}) => Product(
    id: 'prod-1',
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 350,
      baseUnit: BaseUnit.milliliter,
    ),
    active: active,
  );

  group('isEffectivelyActiveIn', () {
    test('an active leaf under an active registration is on the shelf', () {
      expect(leaf().isEffectivelyActiveIn(registration()), isTrue);
    });

    test('a deactivated leaf is off it', () {
      expect(leaf(active: false).isEffectivelyActiveIn(registration()), isFalse);
    });

    test('a deactivated REGISTRATION takes its leaves with it', () {
      // `handoff §H10`: "desativar o produto desativa o cadastro e, com ele,
      // todas as folhas". On the read, a `&&`, and not a second write that
      // would have to walk the leaves one by one (D7).
      expect(
        leaf().isEffectivelyActiveIn(registration(active: false)),
        isFalse,
      );
    });

    test('both deactivated is still off', () {
      expect(
        leaf(active: false).isEffectivelyActiveIn(registration(active: false)),
        isFalse,
      );
    });
  });

  group('the transitions', () {
    test('deactivating and reactivating are the entity\'s own (rule 7)', () {
      expect(leaf().deactivated().active, isFalse);
      expect(leaf(active: false).reactivated().active, isTrue);
      // Nothing else moves.
      expect(leaf().deactivated().id, 'prod-1');
      expect(leaf().deactivated().packaging, leaf().packaging);
    });
  });

  group('sold by weight', () {
    test('the leaf exists with no packaging at all (decision B1)', () {
      const weighed = Product(id: 'prod-5', productRegistrationId: 'reg-2');
      expect(weighed.isSoldByWeight, isTrue);
      expect(weighed.packaging, isNull);
      expect(weighed.toString(), contains('a peso'));
    });

    test('two weight-sold leaves of the same registration are the same', () {
      const a = Product(id: 'a', productRegistrationId: 'reg-2');
      const b = Product(id: 'b', productRegistrationId: 'reg-2');
      expect(a.hasSameContentAs(b), isTrue);
    });

    test('a weighed leaf and a packaged one are not', () {
      const weighed = Product(id: 'a', productRegistrationId: 'reg-1');
      expect(weighed.hasSameContentAs(leaf()), isFalse);
      expect(leaf().hasSameContentAs(weighed), isFalse);
    });

    test('leaves of DIFFERENT registrations never collide', () {
      const other = Product(id: 'b', productRegistrationId: 'reg-9');
      expect(leaf().hasSameContentAs(other), isFalse);
    });
  });

  group('== and hashCode cover every field (rule 8)', () {
    test('two leaves with the same fields are equal', () {
      expect(leaf(), leaf());
      expect(leaf().hashCode, leaf().hashCode);
    });

    test('one field at a time breaks it', () {
      expect(leaf(), isNot(leaf().copyWith(id: 'prod-2')));
      expect(
        leaf(),
        isNot(leaf().copyWith(productRegistrationId: 'reg-9')),
      );
      expect(
        leaf(),
        isNot(
          leaf().copyWith(
            packaging: Packaging(
              pieceCount: 2,
              pieceSize: 350,
              baseUnit: BaseUnit.milliliter,
            ),
          ),
        ),
      );
      expect(leaf(), isNot(leaf(active: false)));
    });
  });
}
