import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';

void main() {
  final milk = Barcode.typed('7894900011517');
  final soda = Barcode.typed('7891000100103');
  final juice = Barcode.typed('7891910000197');

  ProductType type({
    String name = 'Leite',
    BaseUnit unit = BaseUnit.milliliter,
  }) => ProductType(
    id: 'type-1',
    name: name,
    categoryId: 'cat-1',
    baseUnit: unit,
  );

  BarcodeOwner owner({
    String productId = 'prod-1',
    bool leafActive = true,
    bool registrationActive = true,
    String? name,
    Brand? brand,
    String description = '',
    Packaging? packaging,
  }) => BarcodeOwner(
    product: Product(
      id: productId,
      productRegistrationId: 'reg-1',
      packaging:
          packaging ??
          Packaging(
            pieceCount: 1,
            pieceSize: 1000,
            baseUnit: BaseUnit.milliliter,
          ),
      active: leafActive,
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: brand?.id,
      description: description,
      sellingMode: SellingMode.byPiece,
      active: registrationActive,
    ),
    type: type(name: name ?? 'Leite'),
    brand: brand,
  );

  final italac = Brand(id: 'brand-1', name: 'Italac');

  group('isActive', () {
    test('is true when the leaf and the registration are active', () {
      expect(owner().isActive, isTrue);
    });

    test('is false when the leaf is deactivated', () {
      expect(owner(leafActive: false).isActive, isFalse);
    });

    test('is false when the registration is deactivated', () {
      expect(owner(registrationActive: false).isActive, isFalse);
    });
  });

  group('label', () {
    test('is type + brand + packaging', () {
      expect(owner(brand: italac).label, 'Leite Italac 1 L');
    });

    test('includes the description', () {
      final coke = Brand(id: 'brand-2', name: 'Coca-Cola');
      expect(
        owner(
          name: 'Refrigerante',
          brand: coke,
          description: 'zero',
          packaging: Packaging(
            pieceCount: 1,
            pieceSize: 2000,
            baseUnit: BaseUnit.milliliter,
          ),
        ).label,
        'Refrigerante Coca-Cola zero 2 L',
      );
    });

    test('with no brand and no description is type + packaging', () {
      expect(
        owner(
          name: 'Papel-alumínio',
          packaging: Packaging(
            pieceCount: 1,
            pieceSize: 3000,
            baseUnit: BaseUnit.centimeter,
          ),
        ).label,
        'Papel-alumínio 30 m',
      );
    });

    test('of a by-weight leaf has no packaging', () {
      final byWeight = BarcodeOwner(
        product: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
        registration: ProductRegistration(
          id: 'reg-2',
          productTypeId: 'type-2',
          sellingMode: SellingMode.byWeight,
        ),
        type: type(name: 'Acém moído', unit: BaseUnit.gram),
      );
      expect(byWeight.label, 'Acém moído');
    });
  });

  group('fromJson', () {
    Map<String, dynamic> json({Map<String, dynamic>? brand}) => {
      'id': 'prod-1',
      'product_registration_id': 'reg-1',
      'total_content': 1000,
      'piece_count': 1,
      'piece_size': 1000,
      'piece_size_unit': 'milliliter',
      'active': true,
      'product_registration': {
        'id': 'reg-1',
        'product_type_id': 'type-1',
        'brand_id': brand?['id'],
        'description': '',
        'selling_mode': 'by_piece',
        'active': true,
        'product_type': {
          'id': 'type-1',
          'name': 'Leite',
          'category_id': 'cat-1',
          'base_unit': 'milliliter',
          'active': true,
        },
        'brand': brand,
      },
    };

    test('reads the nested embed', () {
      final read = BarcodeOwner.fromJson(
        json(brand: {'id': 'brand-1', 'name': 'Italac', 'active': true}),
      );

      expect(read.product.id, 'prod-1');
      expect(read.registration.id, 'reg-1');
      expect(read.type.name, 'Leite');
      expect(read.brand, italac);
    });

    test('has no brand when the embed says null', () {
      expect(BarcodeOwner.fromJson(json()).brand, isNull);
    });

    test('comes without the owner codes', () {
      final read = BarcodeOwner.fromJson(json());

      expect(read.product.barcodes, isEmpty);
      expect(read.product.scaleCodes, isEmpty);
    });
  });

  group('equality', () {
    BarcodeOwner build({
      String productId = 'prod-1',
      String registrationId = 'reg-1',
      String typeName = 'Leite',
      Brand? brand,
    }) => BarcodeOwner(
      product: Product(id: productId, productRegistrationId: 'reg-1'),
      registration: ProductRegistration(
        id: registrationId,
        productTypeId: 'type-1',
        sellingMode: SellingMode.byPiece,
      ),
      type: type(name: typeName),
      brand: brand,
    );

    test('covers every field', () {
      expect(build(brand: italac), build(brand: italac));
      expect(build(brand: italac).hashCode, build(brand: italac).hashCode);
      expect(
        build(brand: italac),
        isNot(build(productId: 'prod-2', brand: italac)),
      );
      expect(
        build(brand: italac),
        isNot(build(registrationId: 'reg-2', brand: italac)),
      );
      expect(
        build(brand: italac),
        isNot(build(typeName: 'Suco', brand: italac)),
      );
      expect(
        build(brand: italac),
        isNot(
          build(
            brand: Brand(id: 'brand-9', name: 'Piracanjuba'),
          ),
        ),
      );
      expect(build(brand: italac), isNot(build()));
      expect(build(), isNot(build(brand: italac)));
    });

    test('toString carries the label', () {
      expect(owner(brand: italac).toString(), contains('Leite Italac 1 L'));
    });
  });

  group('conflictOf', () {
    final active = owner();
    final inactive = owner(productId: 'prod-2', leafActive: false);

    test('is null when every code is free', () {
      expect(conflictOf([milk, soda].lock, const IMap.empty()), isNull);
    });

    test('is null for an empty list', () {
      expect(conflictOf(const IList.empty(), {milk: active}.lock), isNull);
    });

    test('flags the same code twice on the screen', () {
      expect(
        conflictOf([milk, milk].lock, const IMap.empty()),
        RepeatedOnScreen(milk),
      );
    });

    test('flags a UPC-A and an EAN-13 of the same number', () {
      expect(
        conflictOf(
          [Barcode.typed('012345678905'), Barcode.typed('0012345678905')].lock,
          const IMap.empty(),
        ),
        isA<RepeatedOnScreen>(),
      );
    });

    test('flags a code held by an active owner', () {
      expect(
        conflictOf([milk].lock, {milk: active}.lock),
        TakenByActive(code: milk, owner: active),
      );
    });

    test('answers with the first active owner in the order of the codes', () {
      final other = owner(productId: 'prod-3');
      final conflict = conflictOf(
        [soda, milk].lock,
        {milk: active, soda: other}.lock,
      );

      expect(conflict, TakenByActive(code: soda, owner: other));
    });

    test('lets a deactivated owner through', () {
      expect(conflictOf([milk].lock, {milk: inactive}.lock), isNull);
    });

    test('lets the own leaf through', () {
      expect(
        conflictOf([milk].lock, {milk: active}.lock, ownProductId: 'prod-1'),
        isNull,
      );
    });

    test('puts the repeat on the screen before the database', () {
      expect(
        conflictOf([milk, milk].lock, {milk: active}.lock),
        isA<RepeatedOnScreen>(),
      );
    });
  });

  group('inactiveHoldersOf', () {
    final active = owner();
    final inactive = owner(productId: 'prod-2', leafActive: false);

    test('brings only the deactivated owners', () {
      final holders = inactiveHoldersOf(
        [milk, soda].lock,
        {milk: active, soda: inactive}.lock,
      );

      expect(holders, {soda: inactive}.lock);
    });

    test('leaves out the own leaf', () {
      expect(
        inactiveHoldersOf(
          [soda].lock,
          {soda: inactive}.lock,
          ownProductId: 'prod-2',
        ),
        isEmpty,
      );
    });

    test('leaves out a code with no owner', () {
      expect(inactiveHoldersOf([juice].lock, {soda: inactive}.lock), isEmpty);
    });

    test('is empty when every owner is active', () {
      expect(inactiveHoldersOf([milk].lock, {milk: active}.lock), isEmpty);
    });
  });

  group('BarcodeConflict', () {
    final active = owner();

    test('RepeatedOnScreen equality covers its field', () {
      expect(RepeatedOnScreen(milk), RepeatedOnScreen(milk));
      expect(RepeatedOnScreen(milk).hashCode, RepeatedOnScreen(milk).hashCode);
      expect(RepeatedOnScreen(milk), isNot(RepeatedOnScreen(soda)));
    });

    test('TakenByActive equality covers every field', () {
      TakenByActive taken(Barcode code, BarcodeOwner who) =>
          TakenByActive(code: code, owner: who);

      expect(taken(milk, active), taken(milk, active));
      expect(taken(milk, active).hashCode, taken(milk, active).hashCode);
      expect(taken(milk, active), isNot(taken(soda, active)));
      expect(
        taken(milk, active),
        isNot(taken(milk, owner(productId: 'prod-2'))),
      );
    });

    test('toString carries the code', () {
      expect(RepeatedOnScreen(milk).toString(), contains(milk.code));
      expect(
        TakenByActive(code: milk, owner: active).toString(),
        contains(milk.code),
      );
    });
  });
}
