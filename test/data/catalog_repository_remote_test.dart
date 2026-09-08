import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_remote.dart';
import 'package:shopping_list/data/repositories/store/store_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// The one inviolable rule of every `_remote` method, held by a test.
///
/// Without `rethrowAsKnownFailure` the SQLSTATE of a unique violation — the
/// duplicate guard of the catalog — arrives as "status 23505", falls into the
/// `>= 500` arm of AppFailure and tells the user the server is down when the
/// product simply already exists. It is the kind of bug that never shows up
/// in a happy path, so the only thing that catches it is this.
void main() {
  late _MockClient client;

  setUp(() {
    client = _MockClient();
    // The failure is raised at the first hop of every chain, which is where a
    // real PostgrestException would surface anyway.
    when(() => client.from(any())).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );
    when(
      () => client.rpc<Map<String, dynamic>>(any(), params: any(named: 'params')),
    ).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );
  });

  final packaging = Packaging.typed(
    pieceCount: '1',
    pieceSize: '350',
    baseUnit: BaseUnit.milliliter,
  );

  final registration = ProductRegistration(
    productTypeId: 'type-1',
    sellingMode: SellingMode.byPiece,
  );

  group('CatalogRepositoryRemote', () {
    late CatalogRepositoryRemote repository;

    setUp(() => repository = CatalogRepositoryRemote(client));

    final calls = <String, Future<void> Function()>{
      'fetchCategories': () => repository.fetchCategories(),
      'fetchTypes': () => repository.fetchTypes(),
      'fetchBrands': () => repository.fetchBrands(),
      'createCategory': () => repository.createCategory(
        Category(name: 'Bebidas'),
      ),
      'createType': () => repository.createType(
        ProductType(
          name: 'Refrigerante',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.milliliter,
        ),
      ),
      'createBrand': () => repository.createBrand(Brand(name: 'Omo')),
      'findRegistration': () =>
          repository.findRegistration(productTypeId: 't', description: ''),
      'fetchDescriptions': () =>
          repository.fetchDescriptions(productTypeId: 't'),
      'fetchProductsOf': () => repository.fetchProductsOf('reg-1'),
      'saveRegistrationWithProducts': () =>
          repository.saveRegistrationWithProducts(
            registration: registration,
            packagings: [packaging].lock,
          ),
      'addPackagings': () => repository.addPackagings(
        registrationId: 'reg-1',
        packagings: [packaging].lock,
      ),
      'updateType': () => repository.updateType(
        ProductType(
          id: 'type-1',
          name: 'Refrigerante',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.milliliter,
        ),
      ),
      'fetchPurchaseCountsByType': () =>
          repository.fetchPurchaseCountsByType(),
      'fetchLeavesOfType': () => repository.fetchLeavesOfType('type-1'),
      // H10 — the maintenance writes and the two whole-level reads.
      'updateCategory': () =>
          repository.updateCategory(Category(id: 'cat-1', name: 'Bebidas')),
      'updateBrand': () =>
          repository.updateBrand(Brand(id: 'brand-1', name: 'Omo')),
      'updateRegistration': () =>
          repository.updateRegistration(registration.copyWith(id: 'reg-1')),
      'updateProduct': () => repository.updateProduct(
        const Product(id: 'prod-1', productRegistrationId: 'reg-1'),
      ),
      'fetchRegistrations': () => repository.fetchRegistrations(),
      'fetchProducts': () => repository.fetchProducts(),
      'findRegistrationById': () => repository.findRegistrationById('reg-1'),
    };

    for (final entry in calls.entries) {
      test('${entry.key} translates the SQLSTATE instead of leaking it', () {
        expect(
          entry.value,
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              // 409, not 23505 read as a number.
              409,
            ),
          ),
        );
      });
    }

    test('finds a registration with no brand by IS NULL, not by equality', () {
      // A null brand is a VALUE (decision B2), and `.eq` never matches NULL —
      // the query would silently return nothing and the guard would let a
      // duplicate through.
      expect(
        () => repository.findRegistration(
          productTypeId: 'type-1',
          description: '',
        ),
        throwsA(isA<ApiException>()),
      );
      verify(() => client.from('product_registration')).called(1);
    });
  });

  group('StoreRepositoryRemote', () {
    late StoreRepositoryRemote repository;

    setUp(() => repository = StoreRepositoryRemote(client));

    test('fetchAll translates the SQLSTATE instead of leaking it', () {
      expect(repository.fetchAll, throwsA(isA<ApiException>()));
    });

    test('create translates the SQLSTATE instead of leaking it', () {
      expect(
        () => repository.create(Store(name: 'Carrefour')),
        throwsA(isA<ApiException>()),
      );
    });

    test('update translates the SQLSTATE instead of leaking it', () {
      // Renaming "Carrefur" to "Carrefour" collides with a store that
      // already holds the name, and 23505 is what comes back.
      expect(
        () => repository.update(Store(id: 'store-1', name: 'Carrefour')),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
