import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_view_model.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends CatalogRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int createCategoryCalls = 0;
  int createTypeCalls = 0;
  int createBrandCalls = 0;
  int saveCalls = 0;
  int addPackagingCalls = 0;
  int fetchCategoryCalls = 0;
  int updateTypeCalls = 0;
  int countCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IList<Category>> fetchCategories() async {
    fetchCategoryCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchCategories();
  }

  @override
  Future<Category> createCategory(Category category) async {
    createCategoryCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.createCategory(category);
  }

  @override
  Future<ProductType> createType(ProductType type) async {
    createTypeCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.createType(type);
  }

  @override
  Future<Brand> createBrand(Brand brand) async {
    createBrandCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.createBrand(brand);
  }

  @override
  Future<ProductType> updateType(ProductType type) async {
    updateTypeCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.updateType(type);
  }

  @override
  Future<IMap<String, int>> fetchPurchaseCountsByType() async {
    countCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return {'type-1': 7}.lock;
  }

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    final failure = _take();
    if (failure != null) throw failure;
    return super.findRegistration(
      productTypeId: productTypeId,
      brandId: brandId,
      description: description,
    );
  }

  @override
  Future<IList<String>> fetchDescriptions({
    required String productTypeId,
    String? brandId,
  }) async {
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchDescriptions(
      productTypeId: productTypeId,
      brandId: brandId,
    );
  }

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  }) async {
    saveCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.saveRegistrationWithProducts(
      registration: registration,
      packagings: packagings,
    );
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<Packaging> packagings,
  }) async {
    addPackagingCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.addPackagings(
      registrationId: registrationId,
      packagings: packagings,
    );
  }
}

void main() {
  ProviderContainer containerWith(CatalogRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          catalogRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  Packaging bottle(String size, MeasureUnit unit) =>
      Packaging.typed(pieceCount: '1', pieceSize: size, pieceSizeUnit: unit);

  group('loading the three lists', () {
    test('brings categories, types and brands together', () async {
      final container = containerWith(_SpyRepository());

      final options = await container.read(
        catalogViewModelProvider.future,
      );

      expect(options.categories, isNotEmpty);
      expect(options.types, isNotEmpty);
      expect(options.brands, isNotEmpty);
    });

    test('keeps the deactivated rows, because the guard needs them', () async {
      // Decision B3: hiding them in the query would let a second "Guaraná
      // Antarctica" be born the day the first one is deactivated.
      final container = containerWith(_SpyRepository());

      final options = await container.read(
        catalogViewModelProvider.future,
      );

      expect(options.brands.any((brand) => !brand.active), isTrue);
    });

    test('shows the failure on screen when nothing loaded', () async {
      final repository = _SpyRepository()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(repository);

      await expectLater(
        container.read(catalogViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(catalogViewModelProvider).hasError, isTrue);

      // And the retry that works fills the screen.
      expect(
        await container.read(catalogViewModelProvider.notifier).refresh(),
        isNull,
      );
      expect(container.read(catalogViewModelProvider).hasValue, isTrue);
    });

    test('keeps what is on screen when a refresh fails', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      final loaded = await container.read(catalogViewModelProvider.future);

      repository.failNextCall = ApiException(500, 'boom');

      expect(
        await container.read(catalogViewModelProvider.notifier).refresh(),
        'O servidor está indisponível. Tente de novo em instantes.',
      );
      expect(container.read(catalogViewModelProvider).value, loaded);
      expect(container.read(catalogViewModelProvider).hasError, isFalse);
    });

    test('never lets the raw exception reach the sentence', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      repository.failNextCall = ApiException(
        500,
        'duplicate key value violates unique constraint "brand_name_key"',
      );

      final message = await container
          .read(catalogViewModelProvider.notifier)
          .refresh();

      expect(message, isNot(contains('brand_name_key')));
      expect(message, isNot(contains('ApiException')));
    });
  });

  group('creating a catalog entry on the spot', () {
    test('puts the new category in the list the screen watches', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createCategory('Padaria'),
        isNull,
      );
      expect(
        container
            .read(catalogViewModelProvider)
            .value!
            .categories
            .map((category) => category.name),
        contains('Padaria'),
      );
    });

    test('refuses a repeated name, ignoring case and accents', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createCategory('  BEBIDAS '),
        'Já existe a categoria Bebidas.',
      );
      // Answered in Dart, before any I/O.
      expect(repository.createCategoryCalls, 0);
    });

    test('offers to reactivate a deactivated brand', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createBrand('guarana antarctica'),
        'O cadastro Guaraná Antarctica existe, mas está desativado. '
        'Reative-o na manutenção do cadastro.',
      );
      expect(repository.createBrandCalls, 0);
    });

    test('refuses a blank name in the entity, not in the screen', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createBrand('   '),
        'Informe um nome.',
      );
      expect(repository.createBrandCalls, 0);
    });

    test('keeps a product type unique across the whole catalog', () async {
      // Not per category: the type is the level the reports add up, and two
      // "Refrigerante" would split that sum in half.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createType(
              name: 'refrigerante',
              // A different category, and it still collides.
              categoryId: 'cat-3',
              baseUnit: BaseUnit.liter,
            ),
        'Já existe o tipo Refrigerante.',
      );
      expect(repository.createTypeCalls, 0);
    });

    test('creates the type with its category and base unit', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createType(
              name: 'Achocolatado',
              categoryId: 'cat-1',
              baseUnit: BaseUnit.kilogram,
            ),
        isNull,
      );

      final created = container
          .read(catalogViewModelProvider)
          .value!
          .types
          .lastWhere((type) => type.name == 'Achocolatado');
      expect(created.baseUnit, BaseUnit.kilogram);
      expect(created.categoryId, 'cat-1');
    });

    test('turns a failed create into a sentence', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      repository.failNextCall = NetworkException('offline');

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .createCategory('Padaria'),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
      // The lists already on screen stay there: an ACTION that failed never
      // takes over the screen.
      expect(container.read(catalogViewModelProvider).hasValue, isTrue);
    });

    test('creates once on a double tap', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final notifier = container.read(catalogViewModelProvider.notifier);
      await Future.wait([
        notifier.createCategory('Padaria'),
        notifier.createCategory('Padaria'),
      ]);

      expect(repository.createCategoryCalls, 1);
    });
  });

  group('the identity guard', () {
    test('finds the registration that already holds it, with its leaves', () async {
      final container = containerWith(_SpyRepository());
      await container.read(catalogViewModelProvider.future);

      final conflict = await container
          .read(catalogViewModelProvider.notifier)
          .checkIdentity(
            productTypeId: 'type-1',
            brandId: 'brand-1',
            // Same identity, typed differently: the comparison is normalized.
            description: '  ORIGINAL ',
          );

      expect(conflict, isNotNull);
      expect(conflict!.registration.id, 'reg-1');
      // The four packagings of the wireframe, so the screen can say how many.
      expect(conflict.products, hasLength(4));
    });

    test('counts a blank description as a value', () async {
      // Two ground beefs with no description under the same type ARE the same
      // product — that is what NULLS NOT DISTINCT means in the index.
      final container = containerWith(_SpyRepository());
      await container.read(catalogViewModelProvider.future);

      final conflict = await container
          .read(catalogViewModelProvider.notifier)
          .checkIdentity(productTypeId: 'type-2', description: '');

      expect(conflict?.registration.id, 'reg-2');
    });

    test('lets a different description through', () async {
      final container = containerWith(_SpyRepository());
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .checkIdentity(
              productTypeId: 'type-1',
              brandId: 'brand-1',
              description: 'zero',
            ),
        isNull,
      );
    });

    test('does not block the registration when the check itself fails', () async {
      // The check is a COURTESY the screen pays before saving; the unique
      // index is what actually holds. Turning a lost connection into a block
      // would keep a legitimate registration from ever being written.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      repository.failNextCall = NetworkException('offline');

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .checkIdentity(
              productTypeId: 'type-1',
              brandId: 'brand-1',
              description: 'original',
            ),
        isNull,
      );
    });

    test('suggests the descriptions already used in that type and brand', () async {
      final container = containerWith(_SpyRepository());
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .descriptionsFor(productTypeId: 'type-1', brandId: 'brand-1'),
        contains('original'),
      );
    });
  });

  group('saving', () {
    test('writes the registration and its four packagings at once', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final error = await container
          .read(catalogViewModelProvider.notifier)
          .save(
            registration: ProductRegistration(
              productTypeId: 'type-1',
              brandId: 'brand-1',
              description: 'zero',
              sellingMode: SellingMode.byPiece,
            ),
            packagings: [
              bottle('350', MeasureUnit.milliliter),
              bottle('269', MeasureUnit.milliliter),
              bottle('2', MeasureUnit.liter),
              Packaging.typed(
                pieceCount: '12',
                pieceSize: '350',
                pieceSizeUnit: MeasureUnit.milliliter,
              ),
            ].lock,
          );

      expect(error.error, isNull);
      // ONE call: registration and leaves travel in a single transaction.
      expect(repository.saveCalls, 1);
      expect(
        await repository.fetchProductsOf('reg-100'),
        hasLength(4),
      );
      // And the rows come BACK, with the ids the database gave them —
      // without that, screen 3 could not select what was just registered
      // without reloading the whole catalog.
      expect(error.saved!.products, hasLength(4));
      expect(error.saved!.registration.id, 'reg-100');
    });

    test('saves a weight-sold product with no packaging at all', () async {
      // Decision B1: the leaf still exists, it simply has no packaging.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final error = await container
          .read(catalogViewModelProvider.notifier)
          .save(
            registration: ProductRegistration(
              productTypeId: 'type-2',
              sellingMode: SellingMode.byWeight,
            ),
            packagings: const IList.empty(),
          );

      expect(error.error, isNull);
      expect(error.saved!.products.single.isSoldByWeight, isTrue);
      final leaves = await repository.fetchProductsOf('reg-100');
      expect(leaves, hasLength(1));
      expect(leaves.first.isSoldByWeight, isTrue);
    });

    test('refuses a by-piece registration with no packaging', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .save(
              registration: ProductRegistration(
                productTypeId: 'type-1',
                sellingMode: SellingMode.byPiece,
              ),
              packagings: const IList.empty(),
            )
            .then((result) => result.error),
        'Informe ao menos uma embalagem para este produto.',
      );
      expect(repository.saveCalls, 0);
    });

    test('refuses a weight-sold registration carrying a packaging', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .save(
              registration: ProductRegistration(
                productTypeId: 'type-2',
                sellingMode: SellingMode.byWeight,
              ),
              packagings: [bottle('350', MeasureUnit.milliliter)].lock,
            )
            .then((result) => result.error),
        'Produto vendido a peso não tem embalagem.',
      );
      expect(repository.saveCalls, 0);
    });

    test('turns the duplicate the index caught into its own sentence', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      repository.failNextCall = ApiException(409, 'duplicate key');

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .save(
              registration: ProductRegistration(
                productTypeId: 'type-1',
                sellingMode: SellingMode.byPiece,
              ),
              packagings: [bottle('350', MeasureUnit.milliliter)].lock,
            )
            .then((result) => result.error),
        'Já existe um cadastro com esses dados.',
      );
    });

    test('saves once on a double tap', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final notifier = container.read(catalogViewModelProvider.notifier);
      final registration = ProductRegistration(
        productTypeId: 'type-1',
        sellingMode: SellingMode.byPiece,
      );
      final packagings = [bottle('350', MeasureUnit.milliliter)].lock;

      await Future.wait([
        notifier.save(registration: registration, packagings: packagings),
        notifier.save(registration: registration, packagings: packagings),
      ]);

      expect(repository.saveCalls, 1);
    });

    test('adds a packaging to a registration that already exists', () async {
      // "comprou o Omo de 2,3 kg tendo só o de 500 g".
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .addPackagings(
              registrationId: 'reg-1',
              packagings: [bottle('600', MeasureUnit.milliliter)].lock,
            )
            .then((result) => result.error),
        isNull,
      );
      expect(repository.addPackagingCalls, 1);
      expect(await repository.fetchProductsOf('reg-1'), hasLength(5));
    });

    test('refuses to add nothing', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .addPackagings(
              registrationId: 'reg-1',
              packagings: const IList.empty(),
            )
            .then((result) => result.error),
        'Informe ao menos uma embalagem para este produto.',
      );
      expect(repository.addPackagingCalls, 0);
    });
  });

  group('the two paths the `#1a` panel needs', () {
    test('reactivates the deactivated type instead of creating a second', () async {
      // Decision B3: a second "Sabão em pó" would split in two the history the
      // soft delete exists to preserve.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final deactivated = container
          .read(catalogViewModelProvider)
          .value!
          .types
          .first
          .deactivated();
      await repository.updateType(deactivated);

      final error = await container
          .read(catalogViewModelProvider.notifier)
          .reactivateType(deactivated);

      expect(error, isNull);
      expect(
        container
            .read(catalogViewModelProvider)
            .value!
            .types
            .firstWhere((t) => t.id == deactivated.id)
            .active,
        isTrue,
      );
    });

    test('a failed reactivation answers a sentence and moves nothing', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      final before = container.read(catalogViewModelProvider).value!.types;
      repository.failNextCall = NetworkException('offline');

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .reactivateType(before.first.deactivated()),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
      expect(container.read(catalogViewModelProvider).value!.types, before);
    });

    test('brings the count that orders the panel', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .purchaseCountsByType(),
        {'type-1': 7}.lock,
      );
      expect(repository.countCalls, 1);
    });

    test('an empty count is not an error — order is a comfort', () async {
      // A count that did not load is no reason to stop anyone from putting
      // milk on the list.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(catalogViewModelProvider.future);

      repository.failNextCall = ApiException(500, 'boom');

      expect(
        await container
            .read(catalogViewModelProvider.notifier)
            .purchaseCountsByType(),
        const IMap<String, int>.empty(),
      );
    });
  });
}
