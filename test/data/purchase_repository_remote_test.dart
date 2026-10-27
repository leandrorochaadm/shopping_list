import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';

import '../helpers/pocketbase_test_client.dart';
import '../helpers/purchase.dart';

const _purchaseId = 'purchase0000001';
const _itemId = 'item00000000001';
const _storeId = 'store000000001';
const _listItemId = 'listitem0000001';

void main() {
  late List<http.Request> requests;
  final clock = DateTime.utc(2026, 8, 18, 15, 30);

  http.Response ok(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Answers by method + path; the batch endpoint echoes one 200 per request.
  PurchaseRepositoryRemote repositoryWith(
    http.Response Function(http.Request request) answer, {
    bool signedIn = true,
  }) {
    final client = MockClient((request) async {
      requests.add(request);
      return answer(request);
    });
    return PurchaseRepositoryRemote(
      testPocketBase(client, signedIn: signedIn),
      clock: () => clock,
    );
  }

  List<Map<String, dynamic>> batchRequests() {
    final batch = requests.lastWhere((r) => r.url.path == '/api/batch');
    return (jsonDecode(batch.body)['requests'] as List)
        .cast<Map<String, dynamic>>();
  }

  http.Response echoBatch(http.Request request) {
    final sent = (jsonDecode(request.body)['requests'] as List).length;
    return ok([
      for (var i = 0; i < sent; i++)
        {'status': 200, 'body': <String, dynamic>{}},
    ]);
  }

  final piece = optionByPiece(id: 'product0000001');
  final purchase = Purchase(
    id: _purchaseId,
    date: DateTime.utc(2026, 8, 18),
    storeId: _storeId,
    registeredBy: 'Ana',
    items: [purchaseItem(id: _itemId, option: piece, quantity: 2)].lock,
  );
  final writeOff = ListWriteOff(
    purchaseItemId: _itemId,
    shoppingListItemId: _listItemId,
    quantityWrittenOff: 2,
    fulfills: true,
  );

  setUp(() => requests = []);

  group('session', () {
    test('every read refuses to run without a signed-in user', () async {
      final repository = repositoryWith(
        (_) => fail('no request expected'),
        signedIn: false,
      );

      await expectLater(
        repository.fetchProductOptions(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.fetchDetail(_purchaseId),
        throwsA(isA<ApiException>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('fetchProductOptions', () {
    test('builds the option and sends only the active filter', () async {
      final product = recordJson(
        piece.product.id!,
        {
          ...piece.product.toJson()..remove('id'),
          'product_registration_id': piece.registration.id,
        },
        expand: {
          'product_registration_id': recordJson(
            piece.registration.id!,
            {...piece.registration.toJson()..remove('id'), 'brand_id': ''},
            expand: {
              'product_type_id': recordJson(piece.type.id!, {
                ...piece.type.toJson()..remove('id'),
              }),
            },
          ),
        },
      );
      final repository = repositoryWith((_) => listJson([product]));

      final options = await repository.fetchProductOptions();

      expect(options.single.product.id, piece.product.id);
      expect(options.single.type, piece.type);
      expect(options.single.brand, isNull);
      final query = requests.single.url.queryParameters;
      expect(query['filter'], contains('active = true'));
      expect(query['filter'], isNot(contains('user')));
    });
  });

  group('fetchPage', () {
    test(
      'asks for the page by number and reads hasMore from the total',
      () async {
        final repository = repositoryWith(
          (_) => listJson(
            [
              recordJson(
                _purchaseId,
                {
                  'purchase_date': '2026-08-18 00:00:00.000Z',
                  'registered_by': 'Ana',
                  'store_id': _storeId,
                },
                expand: {
                  'store_id': recordJson(_storeId, {'name': 'Carrefour'}),
                  'purchase_item_via_purchase_id': [
                    recordJson(_itemId, {'total_paid': 1200}),
                  ],
                },
              ),
            ],
            page: 2,
            perPage: 20,
            totalItems: 45,
          ),
        );

        final page = await repository.fetchPage(offset: 20, limit: 20);

        expect(page.hasMore, isTrue);
        expect(page.purchases.single.storeName, 'Carrefour');
        final query = requests.single.url.queryParameters;
        expect(query['page'], '2');
        expect(query['perPage'], '20');
        expect(query['sort'], '-purchase_date,-created_at,-id');
      },
    );

    test('has no more pages on the last one', () async {
      final repository = repositoryWith(
        (_) => listJson([], page: 3, perPage: 20, totalItems: 45),
      );

      final page = await repository.fetchPage(offset: 40, limit: 20);

      expect(page.hasMore, isFalse);
    });

    test('rejects an offset that is not a multiple of the limit', () {
      final repository = repositoryWith((_) => fail('no request expected'));

      expect(
        () => repository.fetchPage(offset: 5, limit: 20),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  group('save', () {
    test('sends one atomic batch in the order of the plan', () async {
      final repository = repositoryWith(echoBatch);

      final repeated = await repository.save(
        PurchaseSubmission(purchase: purchase, writeOffs: [writeOff].lock),
      );

      expect(repeated, isFalse);
      expect(requests, hasLength(1));
      final sent = batchRequests();
      expect(sent.map((r) => '${r['method']} ${r['url']}').toList(), [
        'POST /api/collections/purchase/records',
        'POST /api/collections/purchase_item/records',
        'POST /api/collections/list_write_off/records',
        'PATCH /api/collections/shopping_list_item/records/$_listItemId',
      ]);
      final created = sent.first['body'] as Map<String, dynamic>;
      expect(created['id'], _purchaseId);
      expect(created['purchase_date'], '2026-08-18 00:00:00.000Z');
      expect(created['created_at'], '2026-08-18 15:30:00.000Z');
      expect(created['user'], testUserId);
      final off = sent[2]['body'] as Map<String, dynamic>;
      expect(off, isNot(contains('fulfills')));
      expect(off['user'], testUserId);
      expect(
        (sent[3]['body'] as Map<String, dynamic>)['fulfilled_on'],
        '2026-08-18 00:00:00.000Z',
      );
    });

    test('a 409 whose purchase is already stored is a repeated send', () async {
      final repository = repositoryWith((request) {
        if (request.url.path == '/api/batch') {
          return batchErrorJson(
            index: 0,
            status: 400,
            data: {
              'id': {'code': 'validation_not_unique', 'message': 'taken'},
            },
          );
        }
        return listJson([recordJson(_purchaseId, {})]);
      });

      final repeated = await repository.save(
        PurchaseSubmission(purchase: purchase, writeOffs: const IList.empty()),
      );

      expect(repeated, isTrue);
      expect(
        requests.last.url.queryParameters['filter'],
        contains(_purchaseId),
      );
    });

    test('a 409 with no stored purchase rethrows the original error', () async {
      final repository = repositoryWith((request) {
        if (request.url.path == '/api/batch') {
          return batchErrorJson(
            index: 0,
            status: 400,
            data: {
              'id': {'code': 'validation_not_unique', 'message': 'taken'},
            },
          );
        }
        return listJson([]);
      });

      await expectLater(
        repository.save(
          PurchaseSubmission(
            purchase: purchase,
            writeOffs: const IList.empty(),
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('creates the month alert from the stored state', () async {
      final month = DateTime.utc(2026, 8);
      final repository = repositoryWith((request) {
        if (request.url.path == '/api/batch') return echoBatch(request);
        return listJson([]);
      });

      await repository.save(
        PurchaseSubmission(
          purchase: purchase,
          writeOffs: const IList.empty(),
          capAlerts: [
            CapAlerts(month: month, warned80: true, warned100: false),
          ].lock,
        ),
      );

      final alert = batchRequests().last;
      expect(alert['url'], '/api/collections/spending_cap_alert/records');
      final body = alert['body'] as Map<String, dynamic>;
      expect(body['month'], '2026-08-01 00:00:00.000Z');
      expect(body['warned_80_at'], '2026-08-18 15:30:00.000Z');
      expect(body['warned_100_at'], '');
      expect(body['user'], testUserId);
    });
  });

  group('correct', () {
    test('deletes the stored lines, then recreates them', () async {
      final repository = repositoryWith((request) {
        if (request.url.path == '/api/batch') return echoBatch(request);
        return listJson([
          recordJson(
            'olditem00000001',
            {},
            expand: {
              'list_write_off_via_purchase_item_id': [
                recordJson('oldoff000000001', {}),
              ],
            },
          ),
        ]);
      });

      await repository.correct(
        purchase: purchase,
        writeOffs: const IList.empty(),
        restored: const IList.empty(),
      );

      final sent = batchRequests();
      expect(sent.map((r) => '${r['method']} ${r['url']}').toList(), [
        'PATCH /api/collections/purchase/records/$_purchaseId',
        'DELETE /api/collections/list_write_off/records/oldoff000000001',
        'DELETE /api/collections/purchase_item/records/olditem00000001',
        'POST /api/collections/purchase_item/records',
      ]);
      final patch = sent.first['body'] as Map<String, dynamic>;
      expect(patch.keys, unorderedEquals(['purchase_date', 'store_id']));
    });

    test('reopens a restored list item with an empty fulfilled_on', () async {
      final repository = repositoryWith((request) {
        if (request.url.path == '/api/batch') return echoBatch(request);
        return listJson([]);
      });

      await repository.delete(
        purchaseId: _purchaseId,
        restored: [
          const RestoredListItem(
            id: _listItemId,
            fulfilledOn: null,
            notFound: false,
          ),
        ].lock,
      );

      final sent = batchRequests();
      final patch = sent.firstWhere((r) => r['method'] == 'PATCH');
      expect((patch['body'] as Map<String, dynamic>)['fulfilled_on'], '');
      expect(sent.last['method'], 'DELETE');
      expect(
        sent.last['url'],
        '/api/collections/purchase/records/$_purchaseId',
      );
    });
  });

  group('fetchSameDayTypes', () {
    test('asks nothing when there are no types', () async {
      final repository = repositoryWith((_) => fail('no request expected'));

      final alerts = await repository.fetchSameDayTypes(
        date: DateTime.utc(2026, 8, 18),
        registeredBy: 'Ana',
        productTypeIds: const ISet.empty(),
      );

      expect(alerts, isEmpty);
      expect(requests, isEmpty);
    });

    test('flags a type the other person bought the same day', () async {
      final repository = repositoryWith(
        (_) => listJson([
          recordJson(
            _itemId,
            {},
            expand: {
              'purchase_id': recordJson(_purchaseId, {
                'purchase_date': '2026-08-18 00:00:00.000Z',
                'registered_by': 'Bia',
              }),
              'product_id': recordJson(
                'product0000009',
                {},
                expand: {
                  'product_registration_id': recordJson(
                    'registration001',
                    {},
                    expand: {
                      'product_type_id': recordJson(piece.type.id!, {
                        'name': piece.type.name,
                      }),
                    },
                  ),
                },
              ),
            },
          ),
        ]),
      );

      final alerts = await repository.fetchSameDayTypes(
        date: DateTime.utc(2026, 8, 18),
        registeredBy: 'Ana',
        productTypeIds: {piece.type.id!}.lock,
      );

      expect(alerts.single.productTypeId, piece.type.id);
      expect(requests.single.url.queryParameters['filter'], contains('Ana'));
    });
  });
}
