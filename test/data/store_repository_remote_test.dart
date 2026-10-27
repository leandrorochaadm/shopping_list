import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/repositories/store/store_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/store.dart';

import '../helpers/pocketbase_test_client.dart';

void main() {
  late List<http.Request> requests;

  MockClient answering(http.Response response) => MockClient((request) async {
    requests.add(request);
    return response;
  });

  http.Response recordResponse(Map<String, dynamic> json) => http.Response(
    jsonEncode(json),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  setUp(() => requests = []);

  group('fetchAll', () {
    test('lists the stores, deactivated ones included', () async {
      final repository = StoreRepositoryRemote(
        testPocketBase(
          answering(
            listJson([
              recordJson('store000000001', {
                'name': 'Carrefour',
                'active': true,
              }),
              recordJson('store000000003', {
                'name': 'Mercearia do Zé',
                'active': false,
              }),
            ]),
          ),
        ),
      );

      final stores = await repository.fetchAll();

      expect(stores.toList(), [
        Store(id: 'store000000001', name: 'Carrefour'),
        Store(id: 'store000000003', name: 'Mercearia do Zé', active: false),
      ]);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/collections/store/records');
      expect(requests.single.url.queryParameters['sort'], 'name');
      expect(requests.single.url.queryParameters, isNot(contains('filter')));
    });

    test('returns an empty list without stores', () async {
      final repository = StoreRepositoryRemote(
        testPocketBase(answering(listJson([]))),
      );

      expect((await repository.fetchAll()).isEmpty, isTrue);
    });
  });

  test('create writes the owner and returns the server record', () async {
    final repository = StoreRepositoryRemote(
      testPocketBase(
        answering(
          recordResponse(
            recordJson('store000000100', {'name': 'Atacadão', 'active': true}),
          ),
        ),
      ),
    );

    final created = await repository.create(Store(name: 'Atacadão'));

    expect(created, Store(id: 'store000000100', name: 'Atacadão'));
    final request = requests.single;
    expect(request.method, 'POST');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['name'], 'Atacadão');
    expect(body['active'], true);
    expect(body['user'], testUserId);
    expect(body, isNot(contains('id')));
  });

  test('update does not send the owner', () async {
    final repository = StoreRepositoryRemote(
      testPocketBase(
        answering(
          recordResponse(
            recordJson('store000000001', {
              'name': 'Carrefour',
              'active': false,
            }),
          ),
        ),
      ),
    );

    final updated = await repository.update(
      Store(id: 'store000000001', name: 'Carrefour', active: false),
    );

    expect(
      updated,
      Store(id: 'store000000001', name: 'Carrefour', active: false),
    );
    final request = requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/collections/store/records/store000000001');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body, isNot(contains('user')));
    expect(body, isNot(contains('id')));
  });

  test('translates a missing network on the three methods', () async {
    final repository = StoreRepositoryRemote(testPocketBase(offlineClient()));

    expect(repository.fetchAll, throwsA(isA<NetworkException>()));
    expect(
      () => repository.create(Store(name: 'Carrefour')),
      throwsA(isA<NetworkException>()),
    );
    expect(
      () => repository.update(Store(id: 'store000000001', name: 'Carrefour')),
      throwsA(isA<NetworkException>()),
    );
  });

  test('update of a record of another owner or deleted is a 404', () {
    final repository = StoreRepositoryRemote(
      testPocketBase(answering(errorJson(404))),
    );

    expect(
      () => repository.update(Store(id: 'store000000001', name: 'Carrefour')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test(
    'without a session the three methods fail with 401 and no request',
    () async {
      final repository = StoreRepositoryRemote(
        testPocketBase(answering(listJson([])), signedIn: false),
      );
      final is401 = throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', 401),
      );

      await expectLater(repository.fetchAll(), is401);
      await expectLater(repository.create(Store(name: 'Carrefour')), is401);
      await expectLater(
        repository.update(Store(id: 'store000000001', name: 'Carrefour')),
        is401,
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'an expired token fails with 401, no request, and clears the store',
    () async {
      final pb = testPocketBase(answering(listJson([])));
      pb.authStore.save(
        fakeAuthToken(DateTime.utc(2000)),
        RecordModel.fromJson({
          'id': testUserId,
          'collectionId': '_pb_users_auth_',
        }),
      );
      final repository = StoreRepositoryRemote(pb);

      await expectLater(
        repository.fetchAll(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(requests, isEmpty);
      expect(pb.authStore.token, isEmpty);
    },
  );
}
