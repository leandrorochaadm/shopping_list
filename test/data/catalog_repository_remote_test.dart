import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// A select chain that records what the repository asked, and answers rows.
class _FakeQuery extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  _FakeQuery(this.rows);

  final PostgrestList rows;
  final inFilters = <String, List<dynamic>>{};
  final isFilters = <String, Object?>{};

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> inFilter(
    String column,
    List<dynamic> values,
  ) {
    inFilters[column] = values;
    return this;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> isFilter(String column, Object? value) {
    isFilters[column] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList) onValue, {
    Function? onError,
  }) => Future.value(rows).then(onValue, onError: onError);
}

class _FakeTable extends Fake implements SupabaseQueryBuilder {
  _FakeTable(this.rows);

  final PostgrestList rows;
  final queries = <_FakeQuery>[];
  final columns = <String>[];

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    this.columns.add(columns);
    final query = _FakeQuery(rows);
    queries.add(query);
    return query;
  }
}

/// `rpc` is not a Future, it only implements one — see the purchase tests.
class _FakeRpc extends Fake
    implements PostgrestFilterBuilder<Map<String, dynamic>> {
  _FakeRpc(this.value);

  final Map<String, dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

class _FakeListRpc extends Fake
    implements PostgrestFilterBuilder<List<dynamic>> {
  _FakeListRpc(this.value);

  final List<dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

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
      () =>
          client.rpc<Map<String, dynamic>>(any(), params: any(named: 'params')),
    ).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );
    when(
      () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
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

  final barcode = Barcode.typed('7894900011517');
  const scaleCode = ScaleCode(storeId: 'store-1', itemCode: '2822521');
  final withCode = PackagingWithBarcodes(
    packaging: packaging,
    barcodes: [barcode].lock,
  );

  group('CatalogRepositoryRemote', () {
    late CatalogRepositoryRemote repository;

    setUp(() => repository = CatalogRepositoryRemote(client));

    final calls = <String, Future<void> Function()>{
      'fetchCategories': () => repository.fetchCategories(),
      'fetchTypes': () => repository.fetchTypes(),
      'fetchBrands': () => repository.fetchBrands(),
      'createCategory': () =>
          repository.createCategory(Category(name: 'Bebidas')),
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
            packagings: [withCode].lock,
          ),
      'addPackagings': () => repository.addPackagings(
        registrationId: 'reg-1',
        packagings: [withCode].lock,
      ),
      'findOwners': () => repository.findOwners([barcode].lock),
      'addBarcode': () =>
          repository.addBarcode(productId: 'prod-1', code: barcode),
      'removeBarcode': () =>
          repository.removeBarcode(productId: 'prod-1', code: barcode),
      // A repeated scale code is the same 23505, and must not leak either.
      'addScaleCode': () =>
          repository.addScaleCode(productId: 'prod-1', code: scaleCode),
      'removeScaleCode': () =>
          repository.removeScaleCode(productId: 'prod-1', code: scaleCode),
      'updateType': () => repository.updateType(
        ProductType(
          id: 'type-1',
          name: 'Refrigerante',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.milliliter,
        ),
      ),
      'fetchPurchaseCountsByType': () => repository.fetchPurchaseCountsByType(),
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

  group('CatalogRepositoryRemote — barcodes', () {
    late _MockClient client;
    late CatalogRepositoryRemote repository;

    final ean = Barcode.typed('7894900011517');
    const gtin = '07894900011517';

    PostgrestMap leafRow({List<Map<String, dynamic>>? codes}) => {
      'id': 'prod-1',
      'product_registration_id': 'reg-1',
      'piece_count': 1,
      'piece_size': 350,
      'total_content': 350,
      'piece_size_unit': 'milliliter',
      'active': true,
      'product_barcode': ?codes,
    };

    _FakeTable stubTable(String name, PostgrestList rows) {
      final table = _FakeTable(rows);
      when(() => client.from(name)).thenAnswer((_) => table);
      return table;
    }

    setUp(() {
      client = _MockClient();
      repository = CatalogRepositoryRemote(client);
    });

    test('findOwners leaves scale codes out', () async {
      final table = stubTable('product_barcode', const []);

      await repository.findOwners([ean].lock);

      final query = table.queries.single;
      expect(query.isFilters, {'store_id': null});
      expect(query.inFilters, {
        'code': [gtin],
      });
      expect(table.columns.single, contains('product!inner'));
      expect(table.columns.single, contains('brand ( * )'));
    });

    test('findOwners reads the owner from the embed', () async {
      stubTable('product_barcode', [
        {
          'code': gtin,
          'product': {
            ...leafRow(),
            'product_registration': {
              'id': 'reg-1',
              'product_type_id': 'type-1',
              'brand_id': 'brand-1',
              'description': '',
              'selling_mode': 'by_piece',
              'active': true,
              'product_type': {
                'id': 'type-1',
                'name': 'Refrigerante',
                'category_id': 'cat-1',
                'base_unit': 'milliliter',
                'active': true,
              },
              'brand': {'id': 'brand-1', 'name': 'Coca-Cola', 'active': true},
            },
          },
        },
      ]);

      final owners = await repository.findOwners([ean].lock);

      expect(owners.keys, [ean]);
      expect(owners[ean]!.label, 'Refrigerante Coca-Cola 350 ml');
      expect(owners[ean]!.product.id, 'prod-1');
    });

    test('findOwners with no code does not reach the database', () async {
      final owners = await repository.findOwners(const IList.empty());

      expect(owners, isEmpty);
      verifyNever(() => client.from(any()));
    });

    test("save sends each card's codes in GTIN-14", () async {
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) => _FakeRpc({
          'registration': {
            'id': 'reg-1',
            'product_type_id': 'type-1',
            'selling_mode': 'by_piece',
          },
          'products': [leafRow()],
        }),
      );

      await repository.saveRegistrationWithProducts(
        registration: ProductRegistration(
          productTypeId: 'type-1',
          sellingMode: SellingMode.byPiece,
        ),
        packagings: [
          PackagingWithBarcodes(packaging: packaging, barcodes: [ean].lock),
        ].lock,
      );

      final params =
          verify(
                () => client.rpc<Map<String, dynamic>>(
                  'create_product_registration',
                  params: captureAny(named: 'params'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final element = (params['p_packagings'] as List).single as Map;
      expect(element['barcodes'], [gtin]);
      expect(element['piece_count'], 1);
    });

    test('save by weight sends the scale codes in the empty element', () async {
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) => _FakeRpc({
          'registration': {
            'id': 'reg-1',
            'product_type_id': 'type-2',
            'selling_mode': 'by_weight',
          },
          'products': [
            {'id': 'prod-1', 'product_registration_id': 'reg-1'},
          ],
        }),
      );
      final byWeight = ProductRegistration(
        productTypeId: 'type-2',
        sellingMode: SellingMode.byWeight,
      );

      await repository.saveRegistrationWithProducts(
        registration: byWeight,
        packagings: const IList.empty(),
        scaleCodes: [scaleCode].lock,
      );
      await repository.saveRegistrationWithProducts(
        registration: byWeight,
        packagings: const IList.empty(),
      );

      final sent = verify(
        () => client.rpc<Map<String, dynamic>>(
          'create_product_registration',
          params: captureAny(named: 'params'),
        ),
      ).captured.cast<Map<String, dynamic>>();
      expect(sent.first['p_packagings'], [
        {
          'scale_codes': [
            {'store_id': 'store-1', 'code': '2822521'},
          ],
        },
      ]);
      expect(sent.last['p_packagings'], [<String, dynamic>{}]);
    });

    test(
      'addPackagings calls add_packagings and reads the codes back',
      () async {
        when(
          () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
        ).thenAnswer(
          (_) => _FakeListRpc([
            leafRow(
              codes: [
                {'code': gtin, 'store_id': null},
              ],
            ),
          ]),
        );

        final products = await repository.addPackagings(
          registrationId: 'reg-1',
          packagings: [
            PackagingWithBarcodes(packaging: packaging, barcodes: [ean].lock),
          ].lock,
        );

        final params =
            verify(
                  () => client.rpc<List<dynamic>>(
                    'add_packagings',
                    params: captureAny(named: 'params'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(params['p_registration_id'], 'reg-1');
        expect(((params['p_packagings'] as List).single as Map)['barcodes'], [
          gtin,
        ]);
        expect(products.single.barcodes, [ean]);
        verifyNever(() => client.from(any()));
      },
    );

    test(
      'addPackagings with no packaging sends an empty list, never [{}]',
      () async {
        when(
          () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
        ).thenAnswer((_) => _FakeListRpc(const []));

        await repository.addPackagings(
          registrationId: 'reg-1',
          packagings: const IList.empty(),
        );

        final params =
            verify(
                  () => client.rpc<List<dynamic>>(
                    'add_packagings',
                    params: captureAny(named: 'params'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(params['p_packagings'], isEmpty);
      },
    );

    test('fetchProductsOf embeds the codes without !inner', () async {
      final table = stubTable('product', [leafRow()]);

      await repository.fetchProductsOf('reg-1');

      expect(
        table.columns.single,
        contains('product_barcode ( code, store_id )'),
      );
      expect(table.columns.single, isNot(contains('product_barcode!inner')));
    });
  });
}
