import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:shopping_list/domain/models/record_id.dart';
import 'package:shopping_list/domain/models/scale_label.dart';

import '../helpers/pocketbase_test_client.dart';

const _storeId = 'store000000001';
const _regId = 'reg00000000001';
const _leafId = 'leaf0000000001';

void main() {
  late List<http.Request> requests;

  MockClient answering(http.Response response) => MockClient((request) async {
    requests.add(request);
    return response;
  });

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  CatalogRepositoryRemote repositoryAnswering(
    http.Response response, {
    bool signedIn = true,
  }) => CatalogRepositoryRemote(
    testPocketBase(answering(response), signedIn: signedIn),
  );

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  List<Map<String, dynamic>> batchRequests(http.Request request) =>
      (bodyOf(request)['requests'] as List).cast<Map<String, dynamic>>();

  final packaging = Packaging(
    pieceCount: 6,
    pieceSize: 350,
    baseUnit: BaseUnit.milliliter,
  );

  Map<String, dynamic> leafRow(String id, {Packaging? packaging}) =>
      recordJson(id, {
        'product_registration_id': _regId,
        ...?packaging?.toJson(),
        'active': true,
      });

  final registration = ProductRegistration(
    productTypeId: 'type0000000001',
    brandId: 'brand000000001',
    description: 'zero',
    sellingMode: SellingMode.byPiece,
  );

  Map<String, dynamic> registrationRow(String id, {String brand = ''}) =>
      recordJson(id, {
        'product_type_id': 'type0000000001',
        'brand_id': brand,
        'description': 'zero',
        'selling_mode': 'by_piece',
        'active': true,
      });

  setUp(() => requests = []);

  group('reads', () {
    test('fetchCategories lists everything sorted by name', () async {
      final repository = repositoryAnswering(
        listJson([
          recordJson('cat00000000001', {'name': 'Limpeza', 'active': false}),
        ]),
      );

      final categories = await repository.fetchCategories();

      expect(
        categories.single,
        Category(id: 'cat00000000001', name: 'Limpeza', active: false),
      );
      final query = requests.single.url.queryParameters;
      expect(requests.single.url.path, '/api/collections/category/records');
      expect(query['sort'], 'name');
      expect(query, isNot(contains('filter')));
    });

    test('fetchTypes and fetchBrands read their collections', () async {
      final types = repositoryAnswering(
        listJson([
          recordJson('type0000000001', {
            'name': 'Leite',
            'category_id': 'cat00000000001',
            'base_unit': BaseUnit.milliliter.toJson(),
            'active': true,
          }),
        ]),
      );
      expect((await types.fetchTypes()).single.name, 'Leite');
      expect(requests.single.url.path, '/api/collections/product_type/records');

      requests.clear();
      final brands = repositoryAnswering(
        listJson([
          recordJson('brand000000001', {'name': 'Italac', 'active': true}),
        ]),
      );
      expect((await brands.fetchBrands()).single.name, 'Italac');
      expect(requests.single.url.path, '/api/collections/brand/records');
    });

    test('fetchRegistrations maps the empty brand to null', () async {
      final repository = repositoryAnswering(
        listJson([registrationRow(_regId)]),
      );

      final result = await repository.fetchRegistrations();

      expect(result.single.brandId, isNull);
      expect(requests.single.url.queryParameters['sort'], 'description');
    });

    test(
      'fetchProducts expands the codes and splits the scale codes',
      () async {
        final repository = repositoryAnswering(
          listJson([
            recordJson(
              _leafId,
              {'product_registration_id': _regId, 'active': true},
              expand: {
                'product_barcode_via_product_id': [
                  {'code': '7891000100103', 'store_id': ''},
                  {'code': '2000123', 'store_id': _storeId},
                ],
              },
            ),
          ]),
        );

        final product = (await repository.fetchProducts()).single;

        expect(product.barcodes.single, Barcode.fromJson('7891000100103'));
        expect(
          product.scaleCodes.single,
          const ScaleCode(storeId: _storeId, itemCode: '2000123'),
        );
        expect(
          requests.single.url.queryParameters['expand'],
          'product_barcode_via_product_id',
        );
      },
    );

    test('fetchProducts reads a leaf without expanded codes', () async {
      final repository = repositoryAnswering(listJson([leafRow(_leafId)]));

      final product = (await repository.fetchProducts()).single;

      expect(product.barcodes.isEmpty, isTrue);
      expect(product.scaleCodes.isEmpty, isTrue);
    });

    test('findRegistrationById returns null when nothing matches', () async {
      final repository = repositoryAnswering(listJson([]));

      expect(await repository.findRegistrationById(_regId), isNull);
      final query = requests.single.url.queryParameters;
      expect(query['filter'], 'id = "$_regId"');
      expect(query['perPage'], '1');
    });

    test('findRegistrationById returns the registration', () async {
      final repository = repositoryAnswering(
        listJson([registrationRow(_regId, brand: 'brand000000001')]),
      );

      final found = await repository.findRegistrationById(_regId);

      expect(found!.id, _regId);
      expect(found.brandId, 'brand000000001');
    });

    test('fetchPurchaseCountsByType sums the view per type', () async {
      final repository = CatalogRepositoryRemote(
        testPocketBase(
          MockClient((request) async {
            requests.add(request);
            final path = request.url.path;
            if (path.endsWith('/purchase_item_totals/records')) {
              return listJson([
                {'id': 'v1', 'product_id': _leafId, 'purchase_count': 3},
              ]);
            }
            if (path.endsWith('/product/records')) {
              return listJson([leafRow(_leafId)]);
            }
            return listJson([registrationRow(_regId)]);
          }),
        ),
      );

      final counts = await repository.fetchPurchaseCountsByType();

      expect(counts['type0000000001'], 3);
      expect(requests, hasLength(3));
    });

    test('fetchLeavesOfType pairs each leaf with its registration', () async {
      final repository = repositoryAnswering(
        listJson([
          recordJson(
            _leafId,
            {'product_registration_id': _regId, 'active': true},
            expand: {'product_registration_id': registrationRow(_regId)},
          ),
        ]),
      );

      final leaves = await repository.fetchLeavesOfType('type0000000001');

      expect(leaves.single.registration.id, _regId);
      expect(leaves.single.product.id, _leafId);
      final query = requests.single.url.queryParameters;
      expect(
        query['filter'],
        contains('product_registration_id.product_type_id = "type0000000001"'),
      );
      expect(query['expand'], 'product_registration_id');
    });

    test('findRegistration compares the normalized description', () async {
      final repository = repositoryAnswering(
        listJson([
          recordJson(_regId, {
            'product_type_id': 'type0000000001',
            'brand_id': '',
            'description': 'Açaí',
            'selling_mode': 'by_piece',
            'active': true,
          }),
        ]),
      );

      final found = await repository.findRegistration(
        productTypeId: 'type0000000001',
        description: ' acai ',
      );

      expect(found!.id, _regId);
      expect(
        requests.single.url.queryParameters['filter'],
        'product_type_id = "type0000000001" && brand_id = ""',
      );
    });

    test('findRegistration returns null when no description matches', () async {
      final repository = repositoryAnswering(
        listJson([registrationRow(_regId)]),
      );

      expect(
        await repository.findRegistration(
          productTypeId: 'type0000000001',
          description: 'other',
        ),
        isNull,
      );
    });

    test('fetchDescriptions returns distinct non-empty descriptions', () async {
      final repository = repositoryAnswering(
        listJson([
          registrationRow('reg00000000001'),
          registrationRow('reg00000000002'),
        ]),
      );

      final descriptions = await repository.fetchDescriptions(
        productTypeId: 'type0000000001',
        brandId: 'brand000000001',
      );

      expect(descriptions.toList(), ['zero']);
      expect(
        requests.single.url.queryParameters['filter'],
        contains('description != ""'),
      );
      expect(
        requests.single.url.queryParameters['filter'],
        contains('brand_id = "brand000000001"'),
      );
    });

    test('fetchProductsOf filters by registration', () async {
      final repository = repositoryAnswering(
        listJson([leafRow(_leafId, packaging: packaging)]),
      );

      final products = await repository.fetchProductsOf(_regId);

      expect(products.single.packaging, packaging);
      expect(
        requests.single.url.queryParameters['filter'],
        'product_registration_id = "$_regId"',
      );
    });
  });

  group('creates and updates', () {
    test('createCategory sends the owner', () async {
      final repository = repositoryAnswering(
        json(recordJson('cat00000000002', {'name': 'Carnes', 'active': true})),
      );

      final created = await repository.createCategory(Category(name: 'Carnes'));

      expect(created.id, 'cat00000000002');
      final body = bodyOf(requests.single);
      expect(requests.single.method, 'POST');
      expect(body['user'], testUserId);
      expect(body['name'], 'Carnes');
    });

    test('createBrand and createType write to their collections', () async {
      final brands = repositoryAnswering(
        json(recordJson('brand000000002', {'name': 'Nova', 'active': true})),
      );
      await brands.createBrand(Brand(name: 'Nova'));
      expect(requests.single.url.path, '/api/collections/brand/records');

      requests.clear();
      final types = repositoryAnswering(
        json(
          recordJson('type0000000002', {
            'name': 'Arroz',
            'category_id': 'cat00000000001',
            'base_unit': BaseUnit.gram.toJson(),
            'active': true,
          }),
        ),
      );
      final type = await types.createType(
        ProductType(
          name: 'Arroz',
          categoryId: 'cat00000000001',
          baseUnit: BaseUnit.gram,
        ),
      );
      expect(type.id, 'type0000000002');
      expect(bodyOf(requests.single)['user'], testUserId);
    });

    test('updateCategory never sends the id or the owner', () async {
      final repository = repositoryAnswering(
        json(recordJson('cat00000000002', {'name': 'Carnes', 'active': false})),
      );

      await repository.updateCategory(
        Category(id: 'cat00000000002', name: 'Carnes', active: false),
      );

      expect(requests.single.method, 'PATCH');
      expect(
        requests.single.url.path,
        '/api/collections/category/records/cat00000000002',
      );
      final body = bodyOf(requests.single);
      expect(body, isNot(contains('id')));
      expect(body, isNot(contains('user')));
      expect(body['active'], false);
    });

    test('updateBrand and updateType patch by id', () async {
      final brands = repositoryAnswering(
        json(recordJson('brand000000001', {'name': 'Italac', 'active': true})),
      );
      await brands.updateBrand(Brand(id: 'brand000000001', name: 'Italac'));
      expect(
        requests.single.url.path,
        '/api/collections/brand/records/brand000000001',
      );

      requests.clear();
      final types = repositoryAnswering(
        json(
          recordJson('type0000000001', {
            'name': 'Leite',
            'category_id': 'cat00000000001',
            'base_unit': BaseUnit.milliliter.toJson(),
            'active': true,
          }),
        ),
      );
      await types.updateType(
        ProductType(
          id: 'type0000000001',
          name: 'Leite',
          categoryId: 'cat00000000001',
          baseUnit: BaseUnit.milliliter,
        ),
      );
      expect(
        requests.single.url.path,
        '/api/collections/product_type/records/type0000000001',
      );
    });

    test(
      'updateRegistration writes a null brand as the empty string',
      () async {
        final repository = repositoryAnswering(json(registrationRow(_regId)));

        final updated = await repository.updateRegistration(
          ProductRegistration(
            id: _regId,
            productTypeId: 'type0000000001',
            sellingMode: SellingMode.byPiece,
          ),
        );

        expect(updated.brandId, isNull);
        expect(bodyOf(requests.single)['brand_id'], '');
      },
    );

    test('updateProduct returns the leaf with its codes', () async {
      final repository = repositoryAnswering(
        json(
          recordJson(
            _leafId,
            {'product_registration_id': _regId, 'active': false},
            expand: {
              'product_barcode_via_product_id': [
                {'code': '7891000100103', 'store_id': ''},
              ],
            },
          ),
        ),
      );

      final updated = await repository.updateProduct(
        Product(id: _leafId, productRegistrationId: _regId, active: false),
      );

      expect(updated.active, isFalse);
      expect(updated.barcodes.length, 1);
      final body = bodyOf(requests.single);
      expect(body, isNot(contains('id')));
      expect(body, isNot(contains('user')));
      expect(
        requests.single.url.queryParameters['expand'],
        'product_barcode_via_product_id',
      );
    });
  });

  group('batches', () {
    final code = Barcode.fromJson('7891000100103');

    http.Response batchAnswer(List<Map<String, dynamic>> bodies) => json([
      for (final b in bodies) {'status': 200, 'body': b},
    ]);

    test('saveRegistrationWithProducts sends one ordered batch', () async {
      final repository = CatalogRepositoryRemote(
        testPocketBase(
          MockClient((request) async {
            requests.add(request);
            final sent = batchRequests(request);
            return batchAnswer([
              for (final r in sent)
                {
                  ...(r['body'] as Map<String, dynamic>),
                  'id':
                      (r['body'] as Map<String, dynamic>)['id'] ??
                      'code0000000001',
                },
            ]);
          }),
        ),
      );

      final saved = await repository.saveRegistrationWithProducts(
        registration: registration,
        packagings: [
          PackagingWithBarcodes(packaging: packaging, barcodes: [code].lock),
        ].lock,
      );

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/batch');
      final sent = batchRequests(requests.single);
      expect(sent.map((r) => r['url']).toList(), [
        '/api/collections/product_registration/records',
        '/api/collections/product/records',
        '/api/collections/product_barcode/records',
      ]);
      final regBody = sent[0]['body'] as Map<String, dynamic>;
      final leafBody = sent[1]['body'] as Map<String, dynamic>;
      final codeBody = sent[2]['body'] as Map<String, dynamic>;
      expect(isRecordId(regBody['id'] as String), isTrue);
      expect(regBody['user'], testUserId);
      expect(leafBody['product_registration_id'], regBody['id']);
      expect(codeBody['product_id'], leafBody['id']);
      expect(codeBody['code'], code.toJson());
      expect(codeBody['store_id'], '');
      expect(saved.registration.id, regBody['id']);
      expect(saved.products.single.id, leafBody['id']);
      expect(saved.products.single.barcodes.single, code);
    });

    test(
      'saveRegistrationWithProducts without packagings keeps one loose leaf with the scale codes',
      () async {
        final repository = CatalogRepositoryRemote(
          testPocketBase(
            MockClient((request) async {
              requests.add(request);
              return batchAnswer([
                for (final r in batchRequests(request))
                  r['body'] as Map<String, dynamic>,
              ]);
            }),
          ),
        );
        const scale = ScaleCode(storeId: _storeId, itemCode: '2000123');

        final saved = await repository.saveRegistrationWithProducts(
          registration: ProductRegistration(
            productTypeId: 'type0000000001',
            sellingMode: SellingMode.byWeight,
          ),
          packagings: const IList.empty(),
          scaleCodes: [scale].lock,
        );

        final sent = batchRequests(requests.single);
        expect(sent, hasLength(3));
        expect((sent[0]['body'] as Map)['brand_id'], '');
        expect((sent[2]['body'] as Map)['store_id'], _storeId);
        expect((sent[2]['body'] as Map)['code'], '2000123');
        expect(saved.products.single.packaging, isNull);
        expect(saved.products.single.scaleCodes.single, scale);
      },
    );

    test(
      'saveRegistrationWithProducts translates a duplicate inside the batch',
      () async {
        final repository = repositoryAnswering(
          batchErrorJson(
            index: 0,
            status: 400,
            data: {
              'code': {'code': 'validation_not_unique'},
            },
          ),
        );

        await expectLater(
          repository.saveRegistrationWithProducts(
            registration: registration,
            packagings: [PackagingWithBarcodes(packaging: packaging)].lock,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );
      },
    );

    test('addPackagings with an empty list asks nothing', () async {
      final repository = repositoryAnswering(json({}));

      final result = await repository.addPackagings(
        registrationId: _regId,
        packagings: const IList.empty(),
      );

      expect(result.isEmpty, isTrue);
      expect(requests, isEmpty);
    });

    test(
      'addPackagings without a session throws before the empty shortcut',
      () async {
        final repository = repositoryAnswering(json({}), signedIn: false);

        await expectLater(
          repository.addPackagings(
            registrationId: _regId,
            packagings: const IList.empty(),
          ),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('addPackagings creates leaves and codes in one batch', () async {
      final repository = CatalogRepositoryRemote(
        testPocketBase(
          MockClient((request) async {
            requests.add(request);
            return batchAnswer([
              for (final r in batchRequests(request))
                r['body'] as Map<String, dynamic>,
            ]);
          }),
        ),
      );

      final products = await repository.addPackagings(
        registrationId: _regId,
        packagings: [
          PackagingWithBarcodes(packaging: packaging, barcodes: [code].lock),
          PackagingWithBarcodes(
            packaging: Packaging(
              pieceCount: 1,
              pieceSize: 2000,
              baseUnit: BaseUnit.milliliter,
            ),
          ),
        ].lock,
      );

      final sent = batchRequests(requests.single);
      expect(
        sent
            .map((r) => r['url'] as String)
            .map((u) => u.split('/')[3])
            .toList(),
        ['product', 'product_barcode', 'product'],
      );
      expect(products, hasLength(2));
      expect(products.first.barcodes.single, code);
      expect(products.last.barcodes.isEmpty, isTrue);
    });
  });

  group('codes', () {
    final code = Barcode.fromJson('7891000100103');

    test('findOwners with no codes asks nothing', () async {
      final repository = repositoryAnswering(listJson([]));

      expect(
        (await repository.findOwners(const IList.empty())).isEmpty,
        isTrue,
      );
      expect(requests, isEmpty);
    });

    Map<String, dynamic> ownerRow(
      String id, {
      required bool active,
      bool withBrand = true,
    }) => recordJson(
      id,
      {'product_id': _leafId, 'code': code.toJson(), 'store_id': ''},
      expand: {
        'product_id': {
          ...leafRow(_leafId, packaging: packaging),
          'active': active,
          'expand': {
            'product_registration_id': {
              ...registrationRow(
                _regId,
                brand: withBrand ? 'brand000000001' : '',
              ),
              'expand': {
                'product_type_id': recordJson('type0000000001', {
                  'name': 'Refrigerante',
                  'category_id': 'cat00000000001',
                  'base_unit': BaseUnit.milliliter.toJson(),
                  'active': true,
                }),
                if (withBrand)
                  'brand_id': recordJson('brand000000001', {
                    'name': 'Guaraná',
                    'active': true,
                  }),
              },
            },
          },
        },
      },
    );

    test('findOwners builds the owner and leaves scale codes out', () async {
      final repository = repositoryAnswering(
        listJson([ownerRow('bc000000000001', active: true)]),
      );

      final owners = await repository.findOwners([code].lock);

      final owner = owners[code]!;
      expect(owner.product.id, _leafId);
      expect(owner.registration.id, _regId);
      expect(owner.type.name, 'Refrigerante');
      expect(owner.brand!.name, 'Guaraná');
      final filter = requests.single.url.queryParameters['filter']!;
      expect(filter, contains('store_id = ""'));
      expect(filter, contains('code = "${code.toJson()}"'));
    });

    test('findOwners accepts a registration without brand', () async {
      final repository = repositoryAnswering(
        listJson([ownerRow('bc000000000001', active: true, withBrand: false)]),
      );

      final owners = await repository.findOwners([code].lock);

      expect(owners[code]!.brand, isNull);
    });

    test('findOwners keeps the active owner of a duplicated code', () async {
      final repository = repositoryAnswering(
        listJson([
          ownerRow('bc000000000001', active: false),
          ownerRow('bc000000000002', active: true),
        ]),
      );

      final owners = await repository.findOwners([code].lock);

      expect(owners[code]!.isActive, isTrue);
    });

    test('addBarcode writes a code with no store', () async {
      final repository = repositoryAnswering(
        json(recordJson('bc000000000001', {})),
      );

      await repository.addBarcode(productId: _leafId, code: code);

      final body = bodyOf(requests.single);
      expect(body['product_id'], _leafId);
      expect(body['code'], code.toJson());
      expect(body['store_id'], '');
      expect(body['user'], testUserId);
    });

    test('addScaleCode writes the store and the item code', () async {
      final repository = repositoryAnswering(
        json(recordJson('bc000000000001', {})),
      );

      await repository.addScaleCode(
        productId: _leafId,
        code: const ScaleCode(storeId: _storeId, itemCode: '2000123'),
      );

      final body = bodyOf(requests.single);
      expect(body['store_id'], _storeId);
      expect(body['code'], '2000123');
    });

    test('removeBarcode deletes the rows it finds in one batch', () async {
      final repository = CatalogRepositoryRemote(
        testPocketBase(
          MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/api/batch') {
              return json([
                {'status': 204, 'body': {}},
              ]);
            }
            return listJson([recordJson('bc000000000001', {})]);
          }),
        ),
      );

      await repository.removeBarcode(productId: _leafId, code: code);

      expect(requests, hasLength(2));
      expect(
        requests.first.url.queryParameters['filter'],
        contains('store_id = ""'),
      );
      final sent = batchRequests(requests.last);
      expect(sent.single['method'], 'DELETE');
      expect(
        sent.single['url'],
        '/api/collections/product_barcode/records/bc000000000001',
      );
    });

    test('removeBarcode writes nothing when no row matches', () async {
      final repository = repositoryAnswering(listJson([]));

      await repository.removeBarcode(productId: _leafId, code: code);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
    });

    test('removeScaleCode filters by store and item code', () async {
      final repository = repositoryAnswering(listJson([]));

      await repository.removeScaleCode(
        productId: _leafId,
        code: const ScaleCode(storeId: _storeId, itemCode: '2000123'),
      );

      final filter = requests.single.url.queryParameters['filter']!;
      expect(filter, contains('code = "2000123"'));
      expect(filter, contains('store_id = "$_storeId"'));
    });
  });

  group('failures', () {
    test('no session throws before any request', () async {
      final repository = repositoryAnswering(listJson([]), signedIn: false);

      await expectLater(repository.fetchBrands(), throwsA(isA<ApiException>()));
      expect(requests, isEmpty);
    });

    test('offline becomes NetworkException', () async {
      final repository = CatalogRepositoryRemote(
        testPocketBase(offlineClient()),
      );

      await expectLater(
        repository.fetchCategories(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a 403 stays a 403', () async {
      final repository = repositoryAnswering(errorJson(403));

      await expectLater(
        repository.fetchCategories(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('newRecordId ids are accepted by isRecordId', () {
      expect(isRecordId(newRecordId()), isTrue);
    });
  });
}
