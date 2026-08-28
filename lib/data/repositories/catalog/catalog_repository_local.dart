import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import 'catalog_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// The seed is the wireframe's own two examples, and they are there because
/// they are the two shapes that break differently: the soft drink with FOUR
/// packagings (one registration, four leaves, four prices) and the ground beef
/// sold BY WEIGHT (no brand, no description, one leaf with no packaging).
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class CatalogRepositoryLocal implements CatalogRepository {
  CatalogRepositoryLocal({this.latency = const Duration(milliseconds: 400)});

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<Category> _categories = [
    Category(id: 'cat-1', name: 'Bebidas'),
    Category(id: 'cat-2', name: 'Carnes'),
    Category(id: 'cat-3', name: 'Limpeza'),
  ];

  final List<ProductType> _types = [
    ProductType(
      id: 'type-1',
      name: 'Refrigerante',
      categoryId: 'cat-1',
      baseUnit: BaseUnit.liter,
    ),
    ProductType(
      id: 'type-2',
      name: 'Acém moído',
      categoryId: 'cat-2',
      baseUnit: BaseUnit.kilogram,
    ),
    ProductType(
      id: 'type-3',
      name: 'Papel higiênico',
      categoryId: 'cat-3',
      baseUnit: BaseUnit.unit,
    ),
  ];

  final List<Brand> _brands = [
    Brand(id: 'brand-1', name: 'Coca-Cola'),
    Brand(id: 'brand-2', name: 'Omo'),
    // Deactivated on purpose: it is what makes the B3 guard visible while
    // developing against the fakes.
    Brand(id: 'brand-3', name: 'Guaraná Antarctica', active: false),
  ];

  final List<ProductRegistration> _registrations = [
    ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: 'brand-1',
      description: 'original',
      sellingMode: SellingMode.byPiece,
    ),
    ProductRegistration(
      id: 'reg-2',
      productTypeId: 'type-2',
      description: '',
      sellingMode: SellingMode.byWeight,
    ),
  ];

  late final List<Product> _products = [
    // The four packagings of the wireframe, all under ONE registration.
    _leaf('prod-1', 'reg-1', 1, 350, MeasureUnit.milliliter),
    _leaf('prod-2', 'reg-1', 1, 269, MeasureUnit.milliliter),
    _leaf('prod-3', 'reg-1', 1, 2000, MeasureUnit.liter),
    _leaf('prod-4', 'reg-1', 12, 350, MeasureUnit.milliliter),
    // Sold by weight: the leaf exists, the packaging does not (decision B1).
    const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
  ];

  var _nextId = 100;

  static Product _leaf(
    String id,
    String registrationId,
    int pieceCount,
    int pieceSize,
    MeasureUnit unit,
  ) => Product(
    id: id,
    productRegistrationId: registrationId,
    packaging: Packaging(
      pieceCount: pieceCount,
      pieceSize: pieceSize,
      pieceSizeUnit: unit,
    ),
  );

  @override
  Future<IList<Category>> fetchCategories() async {
    await Future<void>.delayed(latency);
    return _categories.toIList();
  }

  @override
  Future<IList<ProductType>> fetchTypes() async {
    await Future<void>.delayed(latency);
    return _types.toIList();
  }

  @override
  Future<IList<Brand>> fetchBrands() async {
    await Future<void>.delayed(latency);
    return _brands.toIList();
  }

  @override
  Future<Category> createCategory(Category category) async {
    await Future<void>.delayed(latency);
    final created = category.copyWith(id: 'cat-${_nextId++}');
    _categories.add(created);
    return created;
  }

  @override
  Future<ProductType> createType(ProductType type) async {
    await Future<void>.delayed(latency);
    final created = type.copyWith(id: 'type-${_nextId++}');
    _types.add(created);
    return created;
  }

  @override
  Future<Brand> createBrand(Brand brand) async {
    await Future<void>.delayed(latency);
    final created = brand.copyWith(id: 'brand-${_nextId++}');
    _brands.add(created);
    return created;
  }

  @override
  Future<ProductType> updateType(ProductType type) async {
    await Future<void>.delayed(latency);
    final index = _types.indexWhere((entry) => entry.id == type.id);
    if (index >= 0) _types[index] = type;
    return type;
  }

  @override
  Future<IMap<String, int>> fetchPurchaseCountsByType() async {
    await Future<void>.delayed(latency);
    // The fake has no purchases — and that is exactly the case that makes the
    // `#1a` order fall back to alphabetical, which is what the first weeks of
    // the real app look like too.
    return const IMap.empty();
  }

  @override
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId) async {
    await Future<void>.delayed(latency);
    final registrations = _registrations
        .where((entry) => entry.productTypeId == productTypeId)
        .toList();

    return [
      for (final registration in registrations)
        for (final product in _products.where(
          (leaf) => leaf.productRegistrationId == registration.id,
        ))
          (product: product, registration: registration),
    ].toIList();
  }

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    await Future<void>.delayed(latency);
    // The same comparison the real unique index makes: normalized description,
    // and a null brand counting as a value.
    final candidate = ProductRegistration(
      productTypeId: productTypeId,
      brandId: brandId,
      description: description,
      sellingMode: SellingMode.byPiece,
    );
    return candidate.conflictIn(_registrations);
  }

  @override
  Future<IList<String>> fetchDescriptions({
    required String productTypeId,
    String? brandId,
  }) async {
    await Future<void>.delayed(latency);
    return _registrations
        .where(
          (entry) =>
              entry.productTypeId == productTypeId && entry.brandId == brandId,
        )
        .map((entry) => entry.description)
        .where((description) => description.isNotEmpty)
        .toSet()
        .toIList();
  }

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async {
    await Future<void>.delayed(latency);
    return _products
        .where((product) => product.productRegistrationId == registrationId)
        .toIList();
  }

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  }) async {
    await Future<void>.delayed(latency);

    final created = registration.copyWith(id: 'reg-${_nextId++}');
    _registrations.add(created);

    final products = _insert(created.id!, packagings);
    return (registration: created, products: products);
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<Packaging> packagings,
  }) async {
    await Future<void>.delayed(latency);
    return _insert(registrationId, packagings);
  }

  /// The fake's half of the transaction: one leaf per packaging, and exactly
  /// one leaf with no packaging when the product is sold by weight.
  IList<Product> _insert(String registrationId, IList<Packaging> packagings) {
    final leaves = packagings.isEmpty
        ? [Product(productRegistrationId: registrationId)]
        : [
            for (final packaging in packagings)
              Product(
                productRegistrationId: registrationId,
                packaging: packaging,
              ),
          ];

    final created = [
      for (final leaf in leaves) leaf.copyWith(id: 'prod-${_nextId++}'),
    ];
    _products.addAll(created);
    return created.toIList();
  }
}
