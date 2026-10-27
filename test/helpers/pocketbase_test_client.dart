import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/services/pb_schema.dart';

const testBaseUrl = 'http://pb.test';
const testUserId = 'testuser0000001';

String _b64(Map<String, dynamic> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// A JWT-shaped token that expires at [expiresAt]; the signature is fake.
String fakeAuthToken(DateTime expiresAt) {
  final header = _b64({'alg': 'HS256', 'typ': 'JWT'});
  final payload = _b64({
    'id': testUserId,
    'type': 'auth',
    'collectionId': '_pb_users_auth_',
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.fakesignature';
}

PocketBase testPocketBase(MockClient client, {bool signedIn = true}) {
  final store = AsyncAuthStore(save: (_) async {}, initial: null);
  if (signedIn) {
    store.save(
      fakeAuthToken(DateTime.utc(2100)),
      RecordModel.fromJson({
        'id': testUserId,
        'collectionId': '_pb_users_auth_',
        'collectionName': PbCollections.users,
      }),
    );
  }
  return PocketBase(
    testBaseUrl,
    authStore: store,
    httpClientFactory: () => client,
  );
}

Map<String, dynamic> recordJson(
  String id,
  Map<String, dynamic> data, {
  Map<String, dynamic>? expand,
}) => {
  'id': id,
  'collectionId': 'testcollection01',
  'collectionName': 'test',
  'created': '2026-10-01 12:00:00.000Z',
  'updated': '2026-10-01 12:00:00.000Z',
  'user': testUserId,
  ...data,
  'expand': ?expand,
};

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response listJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int perPage = 500,
  int? totalItems,
}) {
  final total = totalItems ?? items.length;
  return _json(200, {
    'page': page,
    'perPage': perPage,
    'totalItems': total,
    'totalPages': (total / perPage).ceil(),
    'items': items,
  });
}

http.Response errorJson(
  int status, {
  String message = '',
  Map<String, dynamic> data = const {},
}) => _json(status, {'status': status, 'message': message, 'data': data});

http.Response batchErrorJson({
  required int index,
  required int status,
  Map<String, dynamic> data = const {},
}) => _json(400, {
  'status': 400,
  'message': 'Batch transaction failed.',
  'data': {
    'requests': {
      '$index': {
        'code': 'batch_request_failed',
        'message': 'Batch request failed.',
        'response': {
          'status': status,
          'message': 'inner failure',
          'data': data,
        },
      },
    },
  },
});

MockClient offlineClient() =>
    MockClient((_) async => throw http.ClientException('offline'));
