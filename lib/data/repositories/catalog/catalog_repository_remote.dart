import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/barcode.dart';
import '../../../domain/models/barcode_owner.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/scale_label.dart';
import '../../services/supabase_error.dart';
import 'catalog_repository.dart';

const _productTable = 'product';
const _barcodeTable = Product.barcodesKey;
const _productIdColumn = 'product_id';
const _codeColumn = ScaleCode.codeKey;
const _storeIdColumn = ScaleCode.storeIdKey;

const _createRegistrationRpc = 'create_product_registration';
const _addPackagingsRpc = 'add_packagings';
const _registrationIdParam = 'p_registration_id';
const _packagingsParam = 'p_packagings';

// The keys of each element of `p_packagings`.
const _barcodesField = 'barcodes';
const _scaleCodesField = 'scale_codes';

// No `!inner`: a leaf with no code still has to come back.
const _productColumns = '*, $_barcodeTable ( $_codeColumn, $_storeIdColumn )';

const _productOwnerEmbed = 'product';
const _ownerColumns =
    '$_codeColumn, $_productOwnerEmbed!inner ( *, '
    '${BarcodeOwner.registrationKey}!inner ( *, '
    '${BarcodeOwner.typeKey}!inner ( * ), ${BarcodeOwner.brandKey} ( * ) ) )';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// 23505 of the duplicate guard arrives as "status 23505", falls into the
/// >= 500 arm of AppFailure and tells the user the server is down when the
/// product simply already exists. The same goes for a repeated code: the 23505
/// of `product_barcode_code_key` becomes a 409 (`DuplicateRecord`) here too.
final class CatalogRepositoryRemote implements CatalogRepository {
  CatalogRepositoryRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<IList<Category>> fetchCategories() async {
    try {
      // No `.eq('active', true)` anywhere in this file: decision B3 needs the
      // deactivated rows for the duplicate guard, and the screen greys them
      // out instead of the query hiding them.
      final rows = await _client.from('category').select().order('name');
      return rows.map(Category.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<ProductType>> fetchTypes() async {
    try {
      final rows = await _client.from('product_type').select().order('name');
      return rows.map(ProductType.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Brand>> fetchBrands() async {
    try {
      final rows = await _client.from('brand').select().order('name');
      return rows.map(Brand.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Category> createCategory(Category category) async {
    try {
      final row = await _client
          .from('category')
          .insert(category.toJson())
          .select()
          .single();
      return Category.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductType> createType(ProductType type) async {
    try {
      final row = await _client
          .from('product_type')
          .insert(type.toJson())
          .select()
          .single();
      return ProductType.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Brand> createBrand(Brand brand) async {
    try {
      final row = await _client
          .from('brand')
          .insert(brand.toJson())
          .select()
          .single();
      return Brand.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductType> updateType(ProductType type) async {
    try {
      final payload = type.toJson()..remove('id');
      final row = await _client
          .from('product_type')
          .update(payload)
          .eq('id', type.id!)
          .select()
          .single();
      return ProductType.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Category> updateCategory(Category category) async =>
      _update('category', category.id!, category.toJson(), Category.fromJson);

  @override
  Future<Brand> updateBrand(Brand brand) async =>
      _update('brand', brand.id!, brand.toJson(), Brand.fromJson);

  @override
  Future<ProductRegistration> updateRegistration(
    ProductRegistration registration,
  ) async => _update(
    'product_registration',
    registration.id!,
    registration.toJson(),
    ProductRegistration.fromJson,
  );

  @override
  Future<Product> updateProduct(Product product) async => _update(
    _productTable,
    product.id!,
    product.toJson(),
    Product.fromJson,
    columns: _productColumns,
  );

  /// The five updates differ in their table and their `fromJson`, and in
  /// nothing else. The id leaves the payload because it is already in the
  /// `.eq`, and sending a primary key inside an update is asking to swap it
  /// by accident one day.
  Future<T> _update<T>(
    String table,
    String id,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic> json) fromJson, {
    String columns = '*',
  }) async {
    try {
      final row = await _client
          .from(table)
          .update(payload..remove('id'))
          .eq('id', id)
          .select(columns)
          .single();
      return fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<ProductRegistration>> fetchRegistrations() async {
    try {
      // No `active` filter, like every other read in this file: the
      // maintenance screen is what offers "mostrar desativados", and the
      // duplicate guard needs to see them anyway (decision B3).
      final rows = await _client
          .from('product_registration')
          .select()
          .order('description');
      return rows.map(ProductRegistration.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> fetchProducts() async {
    try {
      final rows = await _client
          .from(_productTable)
          .select(_productColumns)
          .order('total_content');
      return rows.map(Product.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductRegistration?> findRegistrationById(String id) async {
    try {
      final rows = await _client
          .from('product_registration')
          .select()
          .eq('id', id)
          .limit(1);
      return rows.isEmpty ? null : ProductRegistration.fromJson(rows.first);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IMap<String, int>> fetchPurchaseCountsByType() async {
    try {
      // A view that only sums and groups — no now(), no window, no threshold
      // (decisions 7 and 13). What to do with the count is Dart's business.
      final rows = await _client.from('product_type_purchase_count').select();
      return {
        for (final row in rows)
          row['product_type_id'] as String: (row['purchase_count'] as num)
              .toInt(),
      }.lock;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId) async {
    try {
      // `!inner` turns the embed into a join that also FILTERS: without it a
      // leaf of another type would come back with a null registration.
      final rows = await _client
          .from('product')
          .select('*, product_registration!inner ( * )')
          .eq('product_registration.product_type_id', productTypeId)
          .order('total_content');

      return rows
          .map(
            (row) => TypeLeaf(
              product: Product.fromJson(row),
              registration: ProductRegistration.fromJson(
                row['product_registration'] as Map<String, dynamic>,
              ),
            ),
          )
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    try {
      // The comparison runs against the GENERATED column, so it is the same
      // normalization the unique index uses — asking Postgres to lower/unaccent
      // the candidate here would be a second implementation of the rule.
      var query = _client
          .from('product_registration')
          .select()
          .eq('product_type_id', productTypeId)
          .eq('description_normalized', normalizeName(description));

      // A null brand is a VALUE (decision B2), and `.eq` never matches NULL.
      query = brandId == null
          ? query.isFilter('brand_id', null)
          : query.eq('brand_id', brandId);

      final rows = await query.limit(1);
      return rows.isEmpty ? null : ProductRegistration.fromJson(rows.first);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<String>> fetchDescriptions({
    required String productTypeId,
    String? brandId,
  }) async {
    try {
      var query = _client
          .from('product_registration')
          .select('description')
          .eq('product_type_id', productTypeId)
          .neq('description', '');

      query = brandId == null
          ? query.isFilter('brand_id', null)
          : query.eq('brand_id', brandId);

      final rows = await query.order('description');
      return rows.map((row) => row['description'] as String).toSet().toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async {
    try {
      final rows = await _client
          .from(_productTable)
          .select(_productColumns)
          .eq('product_registration_id', registrationId)
          .order('total_content');
      return rows.map(Product.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) async {
    try {
      // The transactional function of the base migration, never two loose
      // inserts: a registration with four packagings is five rows in two
      // tables, and PostgREST cannot write that atomically.
      final response = await _client.rpc<Map<String, dynamic>>(
        _createRegistrationRpc,
        params: {
          'p_product_type_id': registration.productTypeId,
          'p_brand_id': registration.brandId,
          'p_description': registration.description,
          'p_selling_mode': registration.sellingMode.toJson(),
          _packagingsParam: _packagingsPayload(packagings, scaleCodes),
        },
      );

      final products = (response['products'] as List)
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toIList();

      return SavedRegistration(
        registration: ProductRegistration.fromJson(
          response['registration'] as Map<String, dynamic>,
        ),
        products: products,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<PackagingWithBarcodes> packagings,
  }) async {
    try {
      // A function now because it is two tables (leaf + code). It does NOT go
      // through `_packagingsPayload`: there an empty list becomes `[{}]`, and
      // that would create a by-weight leaf in a by-piece registration.
      final response = await _client.rpc<List<dynamic>>(
        _addPackagingsRpc,
        params: {
          _registrationIdParam: registrationId,
          _packagingsParam: [for (final p in packagings) _packagingElement(p)],
        },
      );
      return response
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    if (codes.isEmpty) return const IMap.empty();
    try {
      // `isFilter` is what leaves the scale codes out. A 7-digit item code is
      // never equal to a GTIN-14, but the filter does not depend on that.
      final rows = await _client
          .from(_barcodeTable)
          .select(_ownerColumns)
          .inFilter(_codeColumn, [for (final c in codes) c.toJson()])
          .isFilter(_storeIdColumn, null);
      return {
        for (final row in rows)
          Barcode.fromJson(row[_codeColumn] as String): BarcodeOwner.fromJson(
            row[_productOwnerEmbed] as Map<String, dynamic>,
          ),
      }.lock;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> addBarcode({
    required String productId,
    required Barcode code,
  }) async {
    try {
      // No `store_id`: a packaging code.
      await _client.from(_barcodeTable).insert({
        _productIdColumn: productId,
        _codeColumn: code.toJson(),
      });
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> removeBarcode({
    required String productId,
    required Barcode code,
  }) async {
    try {
      await _client
          .from(_barcodeTable)
          .delete()
          .eq(_productIdColumn, productId)
          .eq(_codeColumn, code.toJson())
          .isFilter(_storeIdColumn, null);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> addScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    try {
      await _client.from(_barcodeTable).insert({
        _productIdColumn: productId,
        ...code.toJson(),
      });
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> removeScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    try {
      await _client
          .from(_barcodeTable)
          .delete()
          .eq(_productIdColumn, productId)
          .eq(_codeColumn, code.itemCode)
          .eq(_storeIdColumn, code.storeId);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// The card's leaf plus its codes. The key always goes, empty or not (the
  /// function accepts `[]`).
  static Map<String, dynamic> _packagingElement(PackagingWithBarcodes p) => {
    ...p.packaging.toJson(),
    _barcodesField: [for (final b in p.barcodes) b.toJson()],
  };

  /// One JSON element per leaf. A product sold by weight arrives with no
  /// packaging and still gets ONE leaf (decision B1), which the empty object
  /// is: the function inserts a row whose packaging columns stay null. The
  /// scale codes ride in that element.
  ///
  /// No check on [scaleCodes] here: "packagings + scale code" was already
  /// refused by `checkScaleCodes` in the domain.
  static List<Map<String, dynamic>> _packagingsPayload(
    IList<PackagingWithBarcodes> packagings,
    IList<ScaleCode> scaleCodes,
  ) => packagings.isEmpty
      ? [
          {
            if (scaleCodes.isNotEmpty)
              _scaleCodesField: [for (final c in scaleCodes) c.toJson()],
          },
        ]
      : [for (final p in packagings) _packagingElement(p)];
}
