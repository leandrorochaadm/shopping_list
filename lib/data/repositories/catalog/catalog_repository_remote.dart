import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../services/supabase_error.dart';
import 'catalog_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// 23505 of the duplicate guard arrives as "status 23505", falls into the
/// >= 500 arm of AppFailure and tells the user the server is down when the
/// product simply already exists.
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
  Future<IMap<String, int>> fetchPurchaseCountsByType() async {
    try {
      // A view that only sums and groups — no now(), no window, no threshold
      // (decisions 7 and 13). What to do with the count is Dart's business.
      final rows = await _client
          .from('product_type_purchase_count')
          .select();
      return {
        for (final row in rows)
          row['product_type_id'] as String:
              (row['purchase_count'] as num).toInt(),
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
      return rows
          .map((row) => row['description'] as String)
          .toSet()
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async {
    try {
      final rows = await _client
          .from('product')
          .select()
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
    required IList<Packaging> packagings,
  }) async {
    try {
      // The transactional function of the base migration, never two loose
      // inserts: a registration with four packagings is five rows in two
      // tables, and PostgREST cannot write that atomically.
      final response = await _client.rpc<Map<String, dynamic>>(
        'create_product_registration',
        params: {
          'p_product_type_id': registration.productTypeId,
          'p_brand_id': registration.brandId,
          'p_description': registration.description,
          'p_selling_mode': registration.sellingMode.toJson(),
          'p_packagings': _packagingsPayload(packagings),
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
    required IList<Packaging> packagings,
  }) async {
    try {
      // One table, so a plain insert is transactional on its own — the
      // function exists for the two-table case.
      final rows = await _client
          .from('product')
          .insert([
            for (final packaging in packagings)
              {
                'product_registration_id': registrationId,
                ...packaging.toJson(),
              },
          ])
          .select();
      return rows.map(Product.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// One JSON element per leaf. A product sold by weight arrives with no
  /// packaging and still gets ONE leaf (decision B1), which the empty object
  /// is: the function inserts a row whose packaging columns stay null.
  static List<Map<String, dynamic>> _packagingsPayload(
    IList<Packaging> packagings,
  ) => packagings.isEmpty
      ? [const <String, dynamic>{}]
      : [for (final packaging in packagings) packaging.toJson()];
}
