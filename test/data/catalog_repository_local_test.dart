import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/scale_label.dart';

void main() {
  late CatalogRepositoryLocal repository;

  final milk = Barcode.typed('7894900011517');
  final soda = Barcode.typed('7891000100103');
  final juice = Barcode.typed('7891910000197');

  Matcher conflict() =>
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409));

  PackagingWithBarcodes card(int size, [List<Barcode> codes = const []]) =>
      PackagingWithBarcodes(
        packaging: Packaging(
          pieceCount: 1,
          pieceSize: size,
          baseUnit: BaseUnit.milliliter,
        ),
        barcodes: codes.lock,
      );

  ProductRegistration newRegistration([String description = 'novo']) =>
      ProductRegistration(
        productTypeId: 'type-1',
        brandId: 'brand-1',
        description: description,
        sellingMode: SellingMode.byPiece,
      );

  setUp(() => repository = CatalogRepositoryLocal(latency: Duration.zero));

  group('addBarcode', () {
    test('refuses the same code on another leaf', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);

      expect(
        repository.addBarcode(productId: 'prod-2', code: milk),
        conflict(),
      );
    });
  });

  group('addScaleCode', () {
    test('accepts the same item code in two stores, refuses in one', () async {
      const first = ScaleCode(storeId: 'store-1', itemCode: '2822521');
      const second = ScaleCode(storeId: 'store-2', itemCode: '2822521');

      await repository.addScaleCode(productId: 'prod-5', code: first);
      await repository.addScaleCode(productId: 'prod-5', code: second);

      expect(
        repository.addScaleCode(productId: 'prod-6', code: first),
        conflict(),
      );
    });
  });

  group('saveRegistrationWithProducts', () {
    test('writes nothing when a code is already taken', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);
      final registrations = (await repository.fetchRegistrations()).length;
      final products = (await repository.fetchProducts()).length;

      await expectLater(
        repository.saveRegistrationWithProducts(
          registration: newRegistration(),
          packagings: [
            card(500, [milk]),
          ].lock,
        ),
        conflict(),
      );

      expect((await repository.fetchRegistrations()).length, registrations);
      expect((await repository.fetchProducts()).length, products);
    });

    test('writes nothing when two cards repeat a code', () async {
      final registrations = (await repository.fetchRegistrations()).length;
      final products = (await repository.fetchProducts()).length;

      await expectLater(
        repository.saveRegistrationWithProducts(
          registration: newRegistration(),
          packagings: [
            card(500, [juice]),
            card(750, [juice]),
          ].lock,
        ),
        conflict(),
      );

      expect((await repository.fetchRegistrations()).length, registrations);
      expect((await repository.fetchProducts()).length, products);
    });

    test('puts the scale codes on the by-weight leaf', () async {
      const code = ScaleCode(storeId: 'store-1', itemCode: '2822521');

      final saved = await repository.saveRegistrationWithProducts(
        registration: ProductRegistration(
          productTypeId: 'type-2',
          description: 'novo',
          sellingMode: SellingMode.byWeight,
        ),
        packagings: const IList.empty(),
        scaleCodes: [code].lock,
      );

      expect(saved.products.single.scaleCodes, [code]);
    });
  });

  group('fetchProductsOf', () {
    test('returns each leaf with its own codes', () async {
      final saved = await repository.saveRegistrationWithProducts(
        registration: newRegistration(),
        packagings: [
          card(500, [milk]),
          card(750, [soda]),
        ].lock,
      );

      final leaves = await repository.fetchProductsOf(saved.registration.id!);

      expect(leaves, hasLength(2));
      expect(leaves[0].barcodes, [milk]);
      expect(leaves[1].barcodes, [soda]);
    });
  });

  group('removeBarcode', () {
    test('frees the code for another leaf', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);

      await repository.removeBarcode(productId: 'prod-1', code: milk);

      await repository.addBarcode(productId: 'prod-2', code: milk);
      expect(
        (await repository.findOwners([milk].lock))[milk]!.product.id,
        'prod-2',
      );
    });

    test('does not remove a code another leaf holds', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);

      await repository.removeBarcode(productId: 'prod-2', code: milk);

      expect(
        repository.addBarcode(productId: 'prod-3', code: milk),
        conflict(),
      );
    });
  });

  group('removeScaleCode', () {
    test('removes only for the owner', () async {
      const code = ScaleCode(storeId: 'store-1', itemCode: '2822521');
      await repository.addScaleCode(productId: 'prod-5', code: code);

      await repository.removeScaleCode(productId: 'prod-6', code: code);
      expect(
        repository.addScaleCode(productId: 'prod-6', code: code),
        conflict(),
      );

      await repository.removeScaleCode(productId: 'prod-5', code: code);
      await repository.addScaleCode(productId: 'prod-6', code: code);
    });
  });

  group('findOwners', () {
    test(
      'brings active and deactivated owners, leaves out a free code',
      () async {
        await repository.addBarcode(productId: 'prod-1', code: milk);
        await repository.addBarcode(productId: 'prod-2', code: soda);
        final leaf = (await repository.fetchProducts()).firstWhere(
          (p) => p.id == 'prod-2',
        );
        await repository.updateProduct(leaf.deactivated());

        final owners = await repository.findOwners([milk, soda, juice].lock);

        expect(owners.keys, [milk, soda]);
        expect(owners[milk]!.isActive, isTrue);
        expect(owners[soda]!.isActive, isFalse);
        expect(owners[milk]!.label, 'Refrigerante Coca-Cola original 350 ml');
      },
    );
  });

  group('updateProduct', () {
    test('returns the leaf with its codes', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);
      final leaf = (await repository.fetchProducts()).firstWhere(
        (p) => p.id == 'prod-1',
      );

      final updated = await repository.updateProduct(leaf);

      expect(updated.barcodes, [milk]);
    });

    test('does not keep a copy of the codes the leaf came with', () async {
      await repository.addBarcode(productId: 'prod-1', code: milk);
      final leaf = (await repository.fetchProducts()).firstWhere(
        (p) => p.id == 'prod-1',
      );
      await repository.updateProduct(leaf);

      await repository.removeBarcode(productId: 'prod-1', code: milk);

      final leaves = await repository.fetchLeavesOfType('type-1');
      expect(
        leaves.firstWhere((l) => l.product.id == 'prod-1').product.barcodes,
        isEmpty,
      );
      expect(await repository.findOwners([milk].lock), isEmpty);
    });
  });

  group('addPackagings', () {
    test('with an empty list creates no leaf', () async {
      final before = (await repository.fetchProductsOf('reg-1')).length;

      final created = await repository.addPackagings(
        registrationId: 'reg-1',
        packagings: const IList.empty(),
      );

      expect(created, isEmpty);
      expect((await repository.fetchProductsOf('reg-1')).length, before);
    });

    test('puts the codes on the new leaf and refuses a taken one', () async {
      final created = await repository.addPackagings(
        registrationId: 'reg-1',
        packagings: [
          card(500, [milk]),
        ].lock,
      );

      expect(created.single.barcodes, [milk]);
      await expectLater(
        repository.addPackagings(
          registrationId: 'reg-1',
          packagings: [
            card(750, [milk]),
          ].lock,
        ),
        conflict(),
      );
    });
  });
}
