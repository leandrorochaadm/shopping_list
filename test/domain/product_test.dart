import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/scale_label.dart';

/// The leaf. `hasSameContentAs` and the JSON round trip are exercised from
/// `packaging_test.dart` and `product_registration_test.dart`; what is here is
/// the leaf's own rules, and the one H10 adds.
void main() {
  ProductRegistration registration({bool active = true}) => ProductRegistration(
    id: 'reg-1',
    productTypeId: 'type-1',
    sellingMode: SellingMode.byPiece,
    active: active,
  );

  Product leaf({
    bool active = true,
    IList<Barcode> barcodes = const IList.empty(),
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) => Product(
    id: 'prod-1',
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 350,
      baseUnit: BaseUnit.milliliter,
    ),
    active: active,
    barcodes: barcodes,
    scaleCodes: scaleCodes,
  );

  group('isEffectivelyActiveIn', () {
    test('an active leaf under an active registration is on the shelf', () {
      expect(leaf().isEffectivelyActiveIn(registration()), isTrue);
    });

    test('a deactivated leaf is off it', () {
      expect(
        leaf(active: false).isEffectivelyActiveIn(registration()),
        isFalse,
      );
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
      expect(leaf(), isNot(leaf().copyWith(productRegistrationId: 'reg-9')));
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
      expect(
        leaf(),
        isNot(leaf(barcodes: [Barcode.typed('7894900011517')].lock)),
      );
      expect(
        leaf(),
        isNot(
          leaf(
            scaleCodes: [
              const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
            ].lock,
          ),
        ),
      );
    });
  });

  group('the codes', () {
    final row = {
      'id': 'prod-1',
      'product_registration_id': 'reg-1',
      'active': true,
    };

    test('fromJson splits the embed rows by store_id', () {
      final product = Product.fromJson({
        ...row,
        Product.barcodesKey: [
          {'code': '07894900011517', 'store_id': null},
          {'code': '2822521', 'store_id': 'store-1'},
        ],
      });

      expect(product.barcodes, [Barcode.typed('7894900011517')].lock);
      expect(
        product.scaleCodes,
        [const ScaleCode(storeId: 'store-1', itemCode: '2822521')].lock,
      );
    });

    test('fromJson without the embed gives empty lists', () {
      expect(Product.fromJson(row).barcodes, isEmpty);
      expect(Product.fromJson(row).scaleCodes, isEmpty);

      final empty = Product.fromJson({...row, Product.barcodesKey: []});
      expect(empty.barcodes, isEmpty);
      expect(empty.scaleCodes, isEmpty);
    });

    test('toJson leaves the codes out', () {
      final product = leaf(
        barcodes: [Barcode.typed('7894900011517')].lock,
        scaleCodes: [
          const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
        ].lock,
      );

      expect(product.toJson().containsKey(Product.barcodesKey), isFalse);
      final back = Product.fromJson(product.toJson());
      expect(back.barcodes, isEmpty);
      expect(back.scaleCodes, isEmpty);
    });

    test('the transitions keep the codes', () {
      final product = leaf(
        barcodes: [Barcode.typed('7894900011517')].lock,
        scaleCodes: [
          const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
        ].lock,
      );

      for (final moved in [product.deactivated(), product.reactivated()]) {
        expect(moved.barcodes, product.barcodes);
        expect(moved.scaleCodes, product.scaleCodes);
      }
    });
  });

  group('barcodes of a leaf', () {
    final milk = Barcode.typed('7894900011517');
    final soda = Barcode.typed('7891000100103');

    test('withBarcode adds the code', () {
      expect(leaf().withBarcode(milk).barcodes, [milk].lock);
    });

    test('withBarcode refuses a code the leaf already has', () {
      expect(
        () => leaf(barcodes: [milk].lock).withBarcode(milk),
        throwsA(isA<BarcodeAlreadyOnPackaging>()),
      );
    });

    test('withBarcode sees the same number in UPC-A and EAN-13', () {
      final upc = Barcode.typed('012345678905');
      final ean = Barcode.typed('0012345678905');
      expect(
        () => leaf(barcodes: [upc].lock).withBarcode(ean),
        throwsA(isA<BarcodeAlreadyOnPackaging>()),
      );
    });

    test('withoutBarcode removes only that code', () {
      final product = leaf(barcodes: [milk, soda].lock);
      expect(product.withoutBarcode(milk).barcodes, [soda].lock);
    });

    test('the exception carries its sentence', () {
      expect(
        const BarcodeAlreadyOnPackaging().toString(),
        contains('Esse código já está nesta embalagem.'),
      );
    });
  });

  group('packagingCodesWith', () {
    test('adds the code to the list', () {
      const empty = IList<Barcode>.empty();
      expect(
        packagingCodesWith(empty, '7894900011517'),
        [Barcode.typed('7894900011517')].lock,
      );
      expect(empty, isEmpty);
    });

    test('refuses the same code twice, however written', () {
      final codes = packagingCodesWith(const IList.empty(), '012345678905');
      expect(
        () => packagingCodesWith(codes, '0012345678905'),
        throwsA(isA<BarcodeAlreadyOnPackaging>()),
      );
    });

    test('calls a scale label a scale code', () {
      for (final raw in ['02822521001605261107', '2822521001605']) {
        expect(
          () => packagingCodesWith(const IList.empty(), raw),
          throwsA(isA<InStoreBarcode>()),
        );
      }
    });

    test('refuses an invalid code', () {
      expect(
        () => packagingCodesWith(const IList.empty(), '7894900011518'),
        throwsA(isA<InvalidBarcode>()),
      );
    });
  });

  group('packagingCodeOf', () {
    test('reads a packaging code', () {
      expect(packagingCodeOf('7894900011517'), Barcode.typed('7894900011517'));
    });

    test('calls a scale label a scale code', () {
      for (final raw in ['02822521001605261107', '2822521001605']) {
        expect(() => packagingCodeOf(raw), throwsA(isA<InStoreBarcode>()));
      }
    });

    test('refuses an invalid code', () {
      expect(
        () => packagingCodeOf('7894900011518'),
        throwsA(isA<InvalidBarcode>()),
      );
    });
  });

  group('acceptsBarcodes', () {
    test('a leaf with a packaging takes barcodes', () {
      expect(leaf().acceptsBarcodes, isTrue);
    });

    test('a loose leaf takes none', () {
      expect(
        const Product(
          id: 'prod-5',
          productRegistrationId: 'reg-2',
        ).acceptsBarcodes,
        isFalse,
      );
    });
  });

  group('fromJson — what the CHECKs refused', () {
    Map<String, dynamic> row({
      Object? total = 2100,
      List<Map<String, dynamic>>? codes,
    }) => {
      'id': 'prod-1',
      'product_registration_id': 'reg-1',
      'piece_count': total == 2100 ? 6 : 0,
      'piece_size': total == 2100 ? 350 : 0,
      'piece_size_unit': total == 2100 ? 'milliliter' : '',
      'total_content': total,
      'active': true,
      'product_barcode': ?codes,
    };

    test('reads two codes without a store as two barcodes — case 1', () {
      final product = Product.fromJson(
        row(
          codes: [
            {'code': '07894900011517', 'store_id': null},
            {'code': '7891000100103', 'store_id': null},
          ],
        ),
      );

      expect(product.barcodes.length, 2);
      expect(product.scaleCodes, isEmpty);
    });

    test('reads an empty store_id as a packaging code', () {
      final product = Product.fromJson(
        row(
          codes: [
            {'code': '07894900011517', 'store_id': ''},
          ],
        ),
      );

      expect(product.barcodes.length, 1);
      expect(product.scaleCodes, isEmpty);
    });

    test('reads a weight-sold leaf from PocketBase empties — case 5', () {
      final product = Product.fromJson(row(total: 0));

      expect(product.packaging, isNull);
      expect(product.acceptsBarcodes, isFalse);
      expect(product.barcodes, isEmpty);
      expect(product.scaleCodes, isEmpty);
    });

    test('reads a leaf with no embed key as no codes — case 8', () {
      final product = Product.fromJson(row());

      expect(product.barcodes, isEmpty);
      expect(product.scaleCodes, isEmpty);
    });

    test('refuses a leaf with half a packaging', () {
      final json = row()..['piece_size_unit'] = '';

      expect(() => Product.fromJson(json), throwsArgumentError);
    });

    test('refuses a leaf whose embed breaks a CHECK', () {
      expect(
        () => Product.fromJson(
          row(
            codes: [
              {'code': '2822521', 'store_id': null},
            ],
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
