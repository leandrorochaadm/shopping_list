import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/pending_changes.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';

import '../helpers/pocketbase_test_client.dart';

const _itemId = 'item00000000001';
const _otherItemId = 'item00000000002';
const _typeId = 'type00000000001';
const _categoryId = 'cat000000000001';
const _registrationId = 'reg000000000001';
const _brandId = 'brand0000000001';
const _otherId = 'other0000000001';

const _expandQuery =
    'product_type_id.category_id,'
    'preferred_registration_id.brand_id,'
    'list_write_off_via_shopping_list_item_id';
const _openFilter = 'fulfilled_on = "" && removed_on = ""';

ShoppingListItem _item({
  int? quantity,
  ProductRegistration? registration,
  bool picked = false,
}) => ShoppingListItem(
  id: _itemId,
  type: ProductType(
    id: _typeId,
    name: 'Leite',
    categoryId: _categoryId,
    baseUnit: BaseUnit.milliliter,
  ),
  category: Category(id: _categoryId, name: 'Bebidas'),
  preferredRegistration: registration,
  quantity: quantity,
  enteredOn: DateTime(2026, 8, 28),
  picked: picked,
);

Map<String, dynamic> _itemRecord({
  String id = _itemId,
  Map<String, dynamic> data = const {},
  Map<String, dynamic>? expandOverride,
  bool picked = false,
}) => recordJson(
  id,
  {
    'product_type_id': _typeId,
    'preferred_registration_id': '',
    'quantity': 0,
    'entered_on': '2026-08-28 00:00:00.000Z',
    'picked': picked,
    'not_found': false,
    'fulfilled_on': '',
    'removed_on': '',
    ...data,
  },
  expand:
      expandOverride ??
      {
        'product_type_id': recordJson(_typeId, {
          'name': 'Leite',
          'category_id': _categoryId,
          'base_unit': 'milliliter',
          'active': true,
          'expand': {
            'category_id': recordJson(_categoryId, {
              'name': 'Bebidas',
              'active': true,
            }),
          },
        }),
      },
);

Map<String, dynamic> _registrationRecord({String brandId = _brandId}) =>
    recordJson(_registrationId, {
      'product_type_id': _typeId,
      'brand_id': brandId,
      'description': 'integral',
      'selling_mode': 'by_piece',
      'active': true,
      if (brandId.isNotEmpty)
        'expand': {
          'brand_id': recordJson(_brandId, {'name': 'Italac', 'active': true}),
        },
    });

Map<String, dynamic> _typeExpand() =>
    (_itemRecord()['expand'] as Map<String, dynamic>)['product_type_id']
        as Map<String, dynamic>;

RecordSubscriptionEvent _event(String action, {String? id = _otherId}) =>
    RecordSubscriptionEvent(
      action: action,
      record: id == null ? null : RecordModel.fromJson({'id': id}),
    );

http.Response _echoBatch(http.Request request) {
  final requests = (jsonDecode(request.body) as Map)['requests'] as List;
  return http.Response(
    jsonEncode([
      for (final _ in requests) {'status': 200, 'body': <String, dynamic>{}},
    ]),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

final _is409 = isA<ApiException>().having((e) => e.statusCode, 'status', 409);

Map<String, dynamic> _body(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  late List<http.Request> requests;

  ShoppingListRepositoryRemote build(
    FutureOr<http.Response> Function(http.Request) handler, {
    bool signedIn = true,
  }) => ShoppingListRepositoryRemote(
    testPocketBase(
      MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
      signedIn: signedIn,
    ),
  );

  ShoppingListRepositoryRemote answering(http.Response response) =>
      build((_) => response);

  /// A repository whose every write fails, so only the echo bookkeeping stays.
  ShoppingListRepositoryRemote failing() =>
      ShoppingListRepositoryRemote(testPocketBase(offlineClient()));

  setUp(() => requests = []);

  group('fetchAll', () {
    test('rebuilds the line from the expand', () async {
      final repository = answering(
        listJson([
          _itemRecord(
            data: {'preferred_registration_id': _registrationId},
            expandOverride: {
              'product_type_id': _typeExpand(),
              'preferred_registration_id': _registrationRecord(),
              'list_write_off_via_shopping_list_item_id': [
                recordJson('wo0000000000001', {'quantity_written_off': 300}),
                recordJson('wo0000000000002', {'quantity_written_off': 200}),
              ],
            },
          ),
        ]),
      );

      final items = await repository.fetchAll();

      final item = items.single;
      expect(item.preferredRegistration?.id, _registrationId);
      expect(item.preferredRegistrationBrand?.name, 'Italac');
      expect(item.writtenOffQuantity, 500);
      expect(item.writeOffCount, 2);
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/collections/shopping_list_item/records');
      expect(request.url.queryParameters['filter'], _openFilter);
      expect(request.url.queryParameters['expand'], _expandQuery);
    });

    test('reads the empty value of PocketBase as null', () async {
      final repository = answering(listJson([_itemRecord()]));

      final item = (await repository.fetchAll()).single;

      expect(item.quantity, isNull);
      expect(item.preferredRegistration, isNull);
      expect(item.writtenOffQuantity, 0);
      expect(item.writeOffCount, 0);
      expect(item.fulfilledOn, isNull);
      expect(item.removedOn, isNull);
      expect(item.enteredOn, DateTime(2026, 8, 28));
    });

    test('a registration without brand has no brand', () async {
      final repository = answering(
        listJson([
          _itemRecord(
            data: {'preferred_registration_id': _registrationId},
            expandOverride: {
              'product_type_id': _typeExpand(),
              'preferred_registration_id': _registrationRecord(brandId: ''),
            },
          ),
        ]),
      );

      final item = (await repository.fetchAll()).single;

      expect(item.preferredRegistration?.brandId, isNull);
      expect(item.preferredRegistrationBrand, isNull);
    });

    test('an empty list comes back empty', () async {
      final items = await answering(listJson([])).fetchAll();

      expect(items, isEmpty);
    });

    test('a date with a time is rejected', () async {
      final repository = answering(
        listJson([
          _itemRecord(data: {'entered_on': '2026-08-28 15:30:00.000Z'}),
        ]),
      );

      await expectLater(repository.fetchAll(), throwsFormatException);
    });
  });

  group('fetchItemsByIds', () {
    test('brings a closed item, with no open filter', () async {
      final repository = answering(
        listJson([
          _itemRecord(data: {'fulfilled_on': '2026-08-30 00:00:00.000Z'}),
        ]),
      );

      final items = await repository.fetchItemsByIds([_itemId]);

      expect(items.single.fulfilledOn, DateTime(2026, 8, 30));
      final filter = requests.single.url.queryParameters['filter']!;
      expect(filter, contains(_itemId));
      expect(filter, isNot(contains('fulfilled_on = ""')));
    });

    test('an empty set does not touch the client', () async {
      final items = await answering(
        listJson([]),
      ).fetchItemsByIds(const <String>[]);

      expect(items, isEmpty);
      expect(requests, isEmpty);
    });

    test('splits the ids in blocks of 50 without repeating any', () async {
      final repository = answering(listJson([]));
      final ids = [
        for (var i = 0; i < 120; i++) 'id${i.toString().padLeft(12, '0')}',
      ];

      await repository.fetchItemsByIds([...ids, ...ids.take(5)]);

      expect(requests, hasLength(3));
      final perRequest = [
        for (final r in requests)
          RegExp(
            'id\\d{12}',
          ).allMatches(r.url.queryParameters['filter']!).map((m) => m[0]!),
      ];
      expect(perRequest.map((l) => l.length).toList()..sort(), [20, 50, 50]);
      final all = perRequest.expand((l) => l).toList();
      expect(all.toSet(), hasLength(120));
      expect(all, hasLength(120));
    });
  });

  group('countOpenItemsOfType', () {
    test('reads the total, not the page', () async {
      final repository = answering(
        listJson([_itemRecord()], perPage: 1, totalItems: 3),
      );

      expect(await repository.countOpenItemsOfType(_typeId), 3);
      final query = requests.single.url.queryParameters;
      expect(query['perPage'], '1');
      expect(query['skipTotal'], 'false');
      expect(query['filter'], contains('product_type_id = "$_typeId"'));
      expect(query['filter'], contains('fulfilled_on = ""'));
    });

    test('is zero when nothing is open', () async {
      final repository = answering(listJson([], perPage: 1, totalItems: 0));

      expect(await repository.countOpenItemsOfType(_typeId), 0);
    });
  });

  group('writes', () {
    test('add writes the columns with the owner and reads back', () async {
      final repository = answering(recordResponse(_itemRecord()));

      final saved = await repository.add(_item());

      expect(saved, _item());
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.queryParameters['expand'], _expandQuery);
      expect(_body(request), {
        'id': _itemId,
        'product_type_id': _typeId,
        'preferred_registration_id': '',
        'quantity': 0,
        'entered_on': '2026-08-28 00:00:00.000Z',
        'picked': false,
        'not_found': false,
        'fulfilled_on': '',
        'removed_on': '',
        'user': testUserId,
      });
    });

    test('add sends the registration and the quantity', () async {
      final repository = answering(recordResponse(_itemRecord()));
      final registration = ProductRegistration(
        id: _registrationId,
        productTypeId: _typeId,
        sellingMode: SellingMode.byPiece,
      );

      await repository.add(_item(quantity: 1000, registration: registration));

      final body = _body(requests.single);
      expect(body['preferred_registration_id'], _registrationId);
      expect(body['quantity'], 1000);
    });

    test('update sends neither the owner nor the id', () async {
      final repository = answering(recordResponse(_itemRecord(picked: true)));

      final saved = await repository.update(_item().togglePicked());

      expect(saved.picked, isTrue);
      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(
        request.url.path,
        '/api/collections/shopping_list_item/records/$_itemId',
      );
      expect(request.url.queryParameters['expand'], _expandQuery);
      final body = _body(request);
      expect(body, isNot(contains('user')));
      expect(body, isNot(contains('id')));
      expect(body['picked'], isTrue);
    });

    test('remove writes only removed_on', () async {
      final repository = answering(recordResponse(_itemRecord()));

      await repository.remove(_item(), DateTime(2026, 8, 28, 15, 30));

      expect(requests, hasLength(1));
      expect(requests.single.method, 'PATCH');
      expect(
        requests.single.url.path,
        '/api/collections/shopping_list_item/records/$_itemId',
      );
      expect(_body(requests.single), {
        'removed_on': '2026-08-28 00:00:00.000Z',
      });
    });
  });

  group('removeOpenItemsOfType', () {
    test('swallows the echo of every row it removed', () async {
      final repository = build((request) {
        if (request.method == 'POST') return _echoBatch(request);
        return listJson([
          recordJson(_itemId, {}),
          recordJson(_otherItemId, {}),
        ]);
      });
      final emitted = <ListChangeKind>[];
      repository.watchChanges().listen(emitted.add);

      final ids = await repository.removeOpenItemsOfType(
        _typeId,
        DateTime(2026, 8, 28),
      );

      expect(ids.toList(), [_itemId, _otherItemId]);
      final get = requests.first;
      expect(get.url.queryParameters['fields'], 'id');
      expect(get.url.queryParameters['filter'], contains(_typeId));
      expect(get.url.queryParameters['filter'], contains('fulfilled_on = ""'));
      final batch = requests.singleWhere((r) => r.url.path == '/api/batch');
      final sent = _body(batch)['requests'] as List;
      expect(sent, hasLength(2));
      for (final r in sent.cast<Map<String, dynamic>>()) {
        expect(r['method'], 'PATCH');
        expect(r['body'], {'removed_on': '2026-08-28 00:00:00.000Z'});
      }

      repository.onEvent(_event('update', id: _itemId));
      repository.onEvent(_event('update', id: _otherItemId));
      await pumpEventQueue();
      expect(emitted, isEmpty);

      repository.onEvent(_event('update', id: _itemId));
      await pumpEventQueue();
      expect(emitted, [ListChangeKind.changed]);
    });

    test('does nothing when no item is open', () async {
      final repository = answering(listJson([]));

      final ids = await repository.removeOpenItemsOfType(
        _typeId,
        DateTime(2026, 8, 28),
      );

      expect(ids, isEmpty);
      expect(requests.where((r) => r.url.path == '/api/batch'), isEmpty);
    });

    test('a failing batch is classified and writes nothing', () async {
      final repository = build((request) {
        if (request.method == 'POST') {
          return batchErrorJson(index: 1, status: 400);
        }
        return listJson([
          recordJson(_itemId, {}),
          recordJson(_otherItemId, {}),
        ]);
      });

      await expectLater(
        repository.removeOpenItemsOfType(_typeId, DateTime(2026, 8, 28)),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });

  group('failures', () {
    final conflict = errorJson(
      400,
      data: {
        'id': {'code': 'validation_not_unique', 'message': ''},
      },
    );

    final calls =
        <String, Future<Object?> Function(ShoppingListRepositoryRemote)>{
          'fetchAll': (r) => r.fetchAll(),
          'fetchItemsByIds': (r) => r.fetchItemsByIds([_itemId]),
          'countOpenItemsOfType': (r) => r.countOpenItemsOfType(_typeId),
          'removeOpenItemsOfType': (r) =>
              r.removeOpenItemsOfType(_typeId, DateTime(2026, 8, 28)),
          'add': (r) => r.add(_item()),
          'update': (r) => r.update(_item()),
          'remove': (r) => r.remove(_item(), DateTime(2026, 8, 28)),
        };

    for (final entry in calls.entries) {
      test('${entry.key} translates the failure', () async {
        await expectLater(entry.value(answering(conflict)), throwsA(_is409));
      });

      test('${entry.key} without a session sends nothing', () async {
        final repository = build((_) => conflict, signedIn: false);

        await expectLater(
          entry.value(repository),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 401),
          ),
        );
        expect(requests, isEmpty);
      });
    }

    test('offline is a NetworkException', () async {
      final repository = ShoppingListRepositoryRemote(
        testPocketBase(offlineClient()),
      );

      await expectLater(
        repository.fetchAll(),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        repository.add(_item()),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        repository.removeOpenItemsOfType(_typeId, DateTime(2026, 8, 28)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('an item of another owner or already gone is a 404', () async {
      final repository = answering(errorJson(404));

      await expectLater(
        repository.update(_item()),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)),
      );
    });
  });

  group('the channel', () {
    late ShoppingListRepositoryRemote repository;
    late List<ListChangeKind> emitted;

    setUp(() {
      repository = failing();
      emitted = [];
    });

    Future<void> listen() async {
      repository.watchChanges().listen(emitted.add);
      await pumpEventQueue();
    }

    test('an insert from the other phone is a new item', () async {
      await listen();

      repository.onEvent(_event('create'));
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.added]);
    });

    test('an update and a delete are just a change', () async {
      await listen();

      repository.onEvent(_event('update'));
      repository.onEvent(_event('delete'));
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.changed, ListChangeKind.changed]);
    });

    test('an event with no record still counts', () async {
      await listen();

      repository.onEvent(_event('create', id: null));
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.added]);
    });

    test('the echo of OUR OWN write says nothing', () async {
      await listen();
      await expectLater(
        repository.add(_item()),
        throwsA(isA<NetworkException>()),
      );

      repository.onEvent(_event('create', id: _itemId));
      await pumpEventQueue();

      expect(emitted, isEmpty);
    });

    test('two writes to the same row swallow two echoes', () async {
      await listen();
      for (var i = 0; i < 2; i++) {
        await expectLater(
          repository.update(_item()),
          throwsA(isA<NetworkException>()),
        );
      }

      for (var i = 0; i < 3; i++) {
        repository.onEvent(_event('update', id: _itemId));
      }
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.changed]);
    });

    test('expectEcho counts WITH repetition', () async {
      await listen();
      repository.expectEcho([_itemId, _itemId]);

      for (var i = 0; i < 3; i++) {
        repository.onEvent(_event('update', id: _itemId));
      }
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.changed]);
    });

    test('a row this phone never wrote comes through', () async {
      await listen();
      await expectLater(
        repository.remove(_item(), DateTime(2026, 8, 28)),
        throwsA(isA<NetworkException>()),
      );

      repository.onEvent(_event('update'));
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.changed]);
    });

    test('coming back after a drop says the list changed', () async {
      await listen();

      repository.onConnect();
      await pumpEventQueue();
      expect(emitted, isEmpty);

      repository.onSubscribed();
      repository.onConnect();
      await pumpEventQueue();
      expect(emitted, [ListChangeKind.changed]);
    });

    test('reopening the screen does not invent a change', () async {
      final first = repository.watchChanges().listen((_) {});
      repository.onSubscribed();
      await first.cancel();
      await pumpEventQueue();

      repository.watchChanges().listen(emitted.add);
      repository.onConnect();
      await pumpEventQueue();

      expect(emitted, isEmpty);
    });

    test('closing the channel forgets the pending echoes', () async {
      repository.expectEcho([_itemId]);
      final first = repository.watchChanges().listen((_) {});
      await first.cancel();
      await pumpEventQueue();

      await listen();
      repository.onEvent(_event('update', id: _itemId));
      await pumpEventQueue();

      expect(emitted, [ListChangeKind.changed]);
    });

    test('a failing subscription is silence, not an error', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        repository.watchChanges().listen((_) {}, onError: errors.add);
        await pumpEventQueue();
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    });

    test('two listeners share one stream', () async {
      final a = repository.watchChanges().listen(emitted.add);
      final b = repository.watchChanges().listen(emitted.add);
      await pumpEventQueue();

      repository.onEvent(_event('update'));
      await pumpEventQueue();
      expect(emitted, hasLength(2));

      await a.cancel();
      await b.cancel();
    });
  });
}

http.Response recordResponse(Map<String, dynamic> json) => http.Response(
  jsonEncode(json),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
