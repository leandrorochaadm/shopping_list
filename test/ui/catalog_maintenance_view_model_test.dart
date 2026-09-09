import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_maintenance_view_model.dart';

/// The `_local` fakes with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  Object? failNextCall;
  int updateCategoryCalls = 0;
  int updateBrandCalls = 0;
  int updateTypeCalls = 0;
  int updateRegistrationCalls = 0;
  int updateProductCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IList<Category>> fetchCategories() async {
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchCategories();
  }

  @override
  Future<Category> updateCategory(Category category) async {
    updateCategoryCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateCategory(category);
  }

  @override
  Future<Brand> updateBrand(Brand brand) async {
    updateBrandCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateBrand(brand);
  }

  @override
  Future<ProductType> updateType(ProductType type) async {
    updateTypeCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateType(type);
  }

  @override
  Future<ProductRegistration> updateRegistration(
    ProductRegistration registration,
  ) async {
    updateRegistrationCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateRegistration(registration);
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updateProductCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateProduct(product);
  }
}

class _SpyList extends ShoppingListRepositoryLocal {
  _SpyList() : super(latency: Duration.zero);

  Object? failNextCall;
  int countCalls = 0;
  int removeCalls = 0;
  final List<DateTime> removedDays = [];

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<int> countOpenItemsOfType(String productTypeId) async {
    countCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.countOpenItemsOfType(productTypeId);
  }

  @override
  Future<IList<String>> removeOpenItemsOfType(
    String productTypeId,
    DateTime day,
  ) async {
    removeCalls++;
    removedDays.add(day);
    final failure = _take();
    if (failure != null) throw failure;
    return super.removeOpenItemsOfType(productTypeId, day);
  }
}

class _SpyStore extends StoreRepositoryLocal {
  _SpyStore() : super(latency: Duration.zero);

  int updateCalls = 0;

  @override
  Future<Store> update(Store store) async {
    updateCalls++;
    return super.update(store);
  }
}

void main() {
  late _SpyCatalog catalog;
  late _SpyList lists;
  late _SpyStore stores;

  setUp(() {
    catalog = _SpyCatalog();
    lists = _SpyList();
    stores = _SpyStore();
  });

  ProviderContainer container() => ProviderContainer.test(
    overrides: <Override>[
      catalogRepositoryProvider.overrideWith((ref) => catalog),
      shoppingListRepositoryProvider.overrideWith((ref) => lists),
      storeRepositoryProvider.overrideWith((ref) => stores),
    ],
  );

  CatalogMaintenanceViewModel notifierOf(ProviderContainer c) =>
      c.read(catalogMaintenanceViewModelProvider.notifier);

  CatalogMaintenanceState valueOf(ProviderContainer c) =>
      c.read(catalogMaintenanceViewModelProvider).value!;

  // ── The load ───────────────────────────────────────────────────────────

  test('loads the six catalogs at once', () async {
    final c = container();
    final state = await c.read(catalogMaintenanceViewModelProvider.future);

    expect(state.categories, hasLength(4));
    // Five since H17: H11 added "Sabão em pó" and "Tixan" so the report could
    // tell the written story of requirement 4, and H17 added "Café" under
    // "Mercearia" so the suggestion could tell the one of requirement 8. What
    // this case protects is that the load brings the SIX catalogs at once, not
    // how many rows each of them holds.
    expect(state.types, hasLength(6));
    expect(state.brands, hasLength(4));
    expect(state.registrations, hasLength(3));
    expect(state.products, hasLength(6));
    expect(state.stores, hasLength(3));
  });

  test('a failing load occupies the screen', () async {
    catalog.failNextCall = ApiException(500, 'boom');
    final c = container();

    await expectLater(
      c.read(catalogMaintenanceViewModelProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(c.read(catalogMaintenanceViewModelProvider).hasError, isTrue);
  });

  test('refresh that works puts the six lists back', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(await notifierOf(c).refresh(), isNull);
    expect(valueOf(c).categories, hasLength(4));
  });

  test('a failing refresh keeps the lists and returns the sentence', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    catalog.failNextCall = NetworkException('offline');
    final message = await notifierOf(c).refresh();

    expect(message, isNotNull);
    expect(message, isNot(contains('NetworkException')));
    // The lists stay on screen: the failure was of an action, not of the load.
    expect(valueOf(c).categories, hasLength(4));
  });

  // ── Renaming, the four named catalogs ──────────────────────────────────

  test('renames a category', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    final error = await notifierOf(
      c,
    ).renameNamed(CatalogKind.category, 'cat-1', 'Bebidas e sucos');

    expect(error, isNull);
    expect(catalog.updateCategoryCalls, 1);
    expect(
      valueOf(c).categories.where((e) => e.id == 'cat-1').single.name,
      'Bebidas e sucos',
    );
  });

  test('renaming to a name another row already has is refused', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(
        c,
      ).renameNamed(CatalogKind.category, 'cat-1', '  limpeza '),
      'Já existe a categoria Limpeza.',
    );
    expect(catalog.updateCategoryCalls, 0);
  });

  test(
    'renaming a row to its own name, accent corrected, is allowed',
    () async {
      final c = container();
      await c.read(catalogMaintenanceViewModelProvider.future);

      // "Bebidas" normalizes to itself: without `ignoringId` the guard would
      // report the very line being renamed (D8).
      expect(
        await notifierOf(
          c,
        ).renameNamed(CatalogKind.category, 'cat-1', 'Bebidas'),
        isNull,
      );
      expect(catalog.updateCategoryCalls, 1);
    },
  );

  test('the conflict with a DEACTIVATED row offers to reactivate', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    // 'Guaraná Antarctica' is the deactivated brand of the fake.
    expect(
      await notifierOf(
        c,
      ).renameNamed(CatalogKind.brand, 'brand-1', 'guarana antarctica'),
      'O cadastro Guaraná Antarctica existe, mas está desativado.',
    );
  });

  test('no conflict sentence sends anyone to another screen', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    final message = await notifierOf(
      c,
    ).renameNamed(CatalogKind.brand, 'brand-1', 'guarana antarctica');

    expect(message, isNot(contains('manutenção do cadastro')));
  });

  test('a name made of blanks never reaches the repository', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(c).renameNamed(CatalogKind.brand, 'brand-1', '   '),
      'Informe um nome.',
    );
    expect(catalog.updateBrandCalls, 0);
  });

  test('renames a type and a store', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(
        c,
      ).renameNamed(CatalogKind.productType, 'type-1', 'Refrigerantes'),
      isNull,
    );
    expect(
      await notifierOf(
        c,
      ).renameNamed(CatalogKind.store, 'store-1', 'Carrefour Bairro'),
      isNull,
    );
    expect(stores.updateCalls, 1);
    expect(
      valueOf(c).stores.where((e) => e.id == 'store-1').single.name,
      'Carrefour Bairro',
    );
  });

  test('the two nameless catalogs are refused by name', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(
        c,
      ).renameNamed(CatalogKind.registration, 'reg-1', 'qualquer'),
      'Este cadastro não é editado por nome.',
    );
    expect(
      await notifierOf(c).renameNamed(CatalogKind.packaging, 'prod-1', 'x'),
      'Este cadastro não é editado por nome.',
    );
  });

  test('a row that went away answers with "atualize a lista"', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(c).renameNamed(CatalogKind.category, 'cat-404', 'X'),
      'Não encontrei a categoria. Atualize a lista.',
    );
  });

  test('a failing rename returns the translated sentence', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    catalog.failNextCall = ApiException(500, 'boom');
    final message = await notifierOf(
      c,
    ).renameNamed(CatalogKind.category, 'cat-1', 'Bebidas geladas');

    expect(message, isNotNull);
    expect(message, isNot(contains('ApiException')));
  });

  test('the double tap fires one request', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    final first = notifierOf(
      c,
    ).renameNamed(CatalogKind.category, 'cat-1', 'Bebidas geladas');
    final second = notifierOf(
      c,
    ).renameNamed(CatalogKind.category, 'cat-1', 'Bebidas geladas');

    expect(await Future.wait([first, second]), [isNull, isNull]);
    expect(catalog.updateCategoryCalls, 1);
  });

  // ── Reclassifying and the base unit ────────────────────────────────────

  test('reclassifies a type into another active category', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(await notifierOf(c).reclassifyType('type-1', 'cat-3'), isNull);
    expect(
      valueOf(c).types.where((e) => e.id == 'type-1').single.categoryId,
      'cat-3',
    );
  });

  test('reclassifying into a deactivated category is refused', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);
    await notifierOf(c).setActive(CatalogKind.category, 'cat-3', false);

    expect(
      await notifierOf(c).reclassifyType('type-1', 'cat-3'),
      'Escolha uma categoria ativa.',
    );
  });

  test(
    'the base unit changes while the type has no product and no purchase',
    () async {
      final c = container();
      await c.read(catalogMaintenanceViewModelProvider.future);

      // 'type-3' has no registration in the fake, so no leaf either.
      expect(
        await notifierOf(
          c,
        ).changeBaseUnit('type-3', BaseUnit.gram, purchaseCount: 0),
        isNull,
      );
      expect(
        valueOf(c).types.where((e) => e.id == 'type-3').single.baseUnit,
        BaseUnit.gram,
      );
    },
  );

  test('the base unit is locked once the type has a product', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(
        c,
      ).changeBaseUnit('type-1', BaseUnit.gram, purchaseCount: 0),
      'Este tipo já tem produtos ou compras. A unidade base não pode mais '
      'mudar.',
    );
  });

  test('the base unit is locked once the type has a purchase', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(
        c,
      ).changeBaseUnit('type-3', BaseUnit.gram, purchaseCount: 7),
      contains('não pode mais mudar'),
    );
  });

  // ── The product's two halves ───────────────────────────────────────────

  test('edits a registration description', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(c).editRegistration('reg-1', description: 'zero'),
      isNull,
    );
    expect(
      valueOf(c).registrations.where((e) => e.id == 'reg-1').single.description,
      'zero',
    );
  });

  test('the registration guard is the triple identity, not a name', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    // A second registration with the same type, brand and description as
    // 'reg-1' — editing it into that identity has to be refused.
    await catalog.saveRegistrationWithProducts(
      registration: ProductRegistration(
        productTypeId: 'type-1',
        brandId: 'brand-1',
        description: 'zero',
        sellingMode: SellingMode.byPiece,
      ),
      packagings: const IList<Packaging>.empty(),
    );
    await notifierOf(c).refresh();

    final twin = valueOf(
      c,
    ).registrations.where((e) => e.description == 'zero').single;

    expect(
      await notifierOf(c).editRegistration(twin.id!, description: 'ORIGINAL'),
      'Já existe esse produto cadastrado.',
    );
  });

  test('a registration edited into its own identity is allowed', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    // Same triple, only the accents of the description differ: the guard has
    // to ignore the row being edited.
    expect(
      await notifierOf(c).editRegistration('reg-1', description: 'original'),
      isNull,
    );
  });

  test(
    'moving a registration to a type of another base unit is refused',
    () async {
      final c = container();
      await c.read(catalogMaintenanceViewModelProvider.future);

      final message = await notifierOf(
        c,
      ).editRegistration('reg-1', typeId: 'type-2');

      expect(message, contains('A medida não bate'));
      expect(catalog.updateRegistrationCalls, 0);
    },
  );

  test(
    'moving a registration between types of the same base unit works',
    () async {
      final c = container();
      await c.read(catalogMaintenanceViewModelProvider.future);

      await catalog.createType(
        ProductType(
          name: 'Suco',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.milliliter,
        ),
      );
      await notifierOf(c).refresh();
      final juice = valueOf(c).types.where((t) => t.name == 'Suco').single;

      expect(
        await notifierOf(c).editRegistration('reg-1', typeId: juice.id),
        isNull,
      );
      expect(
        valueOf(
          c,
        ).registrations.where((e) => e.id == 'reg-1').single.productTypeId,
        juice.id,
      );
    },
  );

  test('corrects a packaging typed wrong', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(c).correctPackaging(
        'prod-1',
        Packaging(pieceCount: 1, pieceSize: 355, baseUnit: BaseUnit.milliliter),
      ),
      isNull,
    );
    expect(
      valueOf(c).products.where((e) => e.id == 'prod-1').single.packaging,
      Packaging(pieceCount: 1, pieceSize: 355, baseUnit: BaseUnit.milliliter),
    );
  });

  test(
    'a corrected packaging that collides with another leaf is refused',
    () async {
      final c = container();
      await c.read(catalogMaintenanceViewModelProvider.future);

      // 'prod-2' is 269 ml of the same registration; making 'prod-1' 269 ml
      // would be the same shelf twice.
      expect(
        await notifierOf(c).correctPackaging(
          'prod-1',
          Packaging(
            pieceCount: 1,
            pieceSize: 269,
            baseUnit: BaseUnit.milliliter,
          ),
        ),
        'Este cadastro já tem uma embalagem com esse conteúdo.',
      );
      expect(catalog.updateProductCalls, 0);
    },
  );

  // ── Deactivating and reactivating ──────────────────────────────────────

  test('deactivates and reactivates each of the six', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    expect(
      await notifierOf(c).setActive(CatalogKind.category, 'cat-1', false),
      isNull,
    );
    expect(
      valueOf(c).categories.where((e) => e.id == 'cat-1').single.active,
      isFalse,
    );

    expect(
      await notifierOf(c).setActive(CatalogKind.brand, 'brand-3', true),
      isNull,
    );
    expect(
      valueOf(c).brands.where((e) => e.id == 'brand-3').single.active,
      isTrue,
    );

    expect(
      await notifierOf(c).setActive(CatalogKind.productType, 'type-3', false),
      isNull,
    );
    expect(
      valueOf(c).types.where((e) => e.id == 'type-3').single.active,
      isFalse,
    );

    expect(
      await notifierOf(c).setActive(CatalogKind.store, 'store-3', true),
      isNull,
    );
    expect(
      valueOf(c).stores.where((e) => e.id == 'store-3').single.active,
      isTrue,
    );

    expect(
      await notifierOf(c).setActive(CatalogKind.registration, 'reg-1', false),
      isNull,
    );
    expect(
      valueOf(c).registrations.where((e) => e.id == 'reg-1').single.active,
      isFalse,
    );

    expect(
      await notifierOf(c).setActive(CatalogKind.packaging, 'prod-1', false),
      isNull,
    );
    expect(
      valueOf(c).products.where((e) => e.id == 'prod-1').single.active,
      isFalse,
    );
  });

  test('counts the open list items of a type', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    // The list fake has two open items of 'type-3'.
    expect(await notifierOf(c).countListItemsOfType('type-3'), 2);
    expect(lists.countCalls, 1);
  });

  test('a count that failed answers null, never a quiet zero', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    lists.failNextCall = NetworkException('offline');

    // Zero would deactivate the type WITHOUT asking, removing items nobody
    // ever saw. `null` is "não deu para conferir".
    expect(await notifierOf(c).countListItemsOfType('type-3'), isNull);
  });

  test('deactivating a type takes its open items off the list', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    final error = await notifierOf(
      c,
    ).deactivateTypeAndRemoveItems('type-3', today: DateTime(2026, 8, 30));

    expect(error, isNull);
    expect(
      valueOf(c).types.where((e) => e.id == 'type-3').single.active,
      isFalse,
    );
    expect(lists.removeCalls, 1);
    expect(lists.removedDays.single, DateTime(2026, 8, 30));
    expect(await lists.countOpenItemsOfType('type-3'), 0);
  });

  test('reactivating the type does NOT bring the item back', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    await notifierOf(
      c,
    ).deactivateTypeAndRemoveItems('type-3', today: DateTime(2026, 8, 30));
    await notifierOf(c).setActive(CatalogKind.productType, 'type-3', true);

    // Deliberately irreversible: the removal is a human gesture, and the
    // reactivation of a type is not the undo of it.
    expect(await lists.countOpenItemsOfType('type-3'), 0);
  });

  test('a failing deactivation returns the translated sentence', () async {
    final c = container();
    await c.read(catalogMaintenanceViewModelProvider.future);

    lists.failNextCall = ApiException(500, 'boom');
    final message = await notifierOf(c).deactivateTypeAndRemoveItems('type-3');

    expect(message, isNotNull);
    expect(message, isNot(contains('ApiException')));
  });

  // ── The state, field by field ──────────────────────────────────────────

  group('CatalogMaintenanceState', () {
    CatalogMaintenanceState build({
      IList<Category>? categories,
      IList<ProductType>? types,
      IList<Brand>? brands,
      IList<ProductRegistration>? registrations,
      IList<Product>? products,
      IList<Store>? stores,
    }) => CatalogMaintenanceState(
      categories: categories ?? IList([Category(id: 'c', name: 'Bebidas')]),
      types:
          types ??
          IList([
            ProductType(
              id: 't',
              name: 'Refrigerante',
              categoryId: 'c',
              baseUnit: BaseUnit.milliliter,
            ),
          ]),
      brands: brands ?? IList([Brand(id: 'b', name: 'Coca-Cola')]),
      registrations:
          registrations ??
          IList([
            ProductRegistration(
              id: 'r',
              productTypeId: 't',
              description: '',
              sellingMode: SellingMode.byPiece,
            ),
          ]),
      products:
          products ??
          const IList<Product>.empty().add(
            const Product(id: 'p', productRegistrationId: 'r'),
          ),
      stores: stores ?? IList([Store(id: 's', name: 'Carrefour')]),
    );

    test('two states of equal fields are equal and hash the same', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('one field apart is enough to differ', () {
      expect(build(categories: const IList<Category>.empty()), isNot(build()));
      expect(build(types: const IList<ProductType>.empty()), isNot(build()));
      expect(build(brands: const IList<Brand>.empty()), isNot(build()));
      expect(
        build(registrations: const IList<ProductRegistration>.empty()),
        isNot(build()),
      );
      expect(build(products: const IList<Product>.empty()), isNot(build()));
      expect(build(stores: const IList<Store>.empty()), isNot(build()));
    });

    test('copyWith keeps what it was not given', () {
      final state = build();
      expect(state.copyWith(), state);
      expect(
        state.copyWith(stores: const IList<Store>.empty()).categories,
        state.categories,
      );
    });

    test('counts the leaves of a type in memory', () {
      final state = build();
      expect(state.productCountOfType('t'), 1);
      expect(state.productCountOfType('other'), 0);
    });

    test('finds the registration a leaf belongs to', () {
      final state = build();
      expect(
        state
            .registrationOf(const Product(id: 'p', productRegistrationId: 'r'))!
            .id,
        'r',
      );
      expect(
        state.registrationOf(
          const Product(id: 'p', productRegistrationId: 'nope'),
        ),
        isNull,
      );
    });
  });

  group('CatalogKind', () {
    test('names the six catalogs in the order the selector shows', () {
      expect(CatalogKind.values.map((k) => k.label), [
        'Categorias',
        'Tipos de produto',
        'Marcas',
        'Cadastros de produto',
        'Embalagens',
        'Mercados',
      ]);
    });

    test('carries the article the conflict sentence needs', () {
      expect(CatalogKind.category.noun, 'a categoria');
      expect(CatalogKind.store.noun, 'o mercado');
    });

    test('every catalog names its create action in its own gender', () {
      expect(CatalogKind.category.createLabel, 'Nova categoria');
      expect(CatalogKind.productType.createLabel, 'Novo tipo');
      expect(CatalogKind.brand.createLabel, 'Nova marca');
      expect(CatalogKind.registration.createLabel, 'Novo cadastro de produto');
      expect(CatalogKind.packaging.createLabel, 'Nova embalagem');
      expect(CatalogKind.store.createLabel, 'Novo mercado');
    });
  });
}
