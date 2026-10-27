import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/data/services/pocketbase_error.dart';

import '../helpers/pocketbase_test_client.dart';

ClientException _error(int status, [Object? response]) => ClientException(
  statusCode: status,
  response: response is Map<String, dynamic> ? response : const {},
);

Map<String, dynamic> _validation(String code) => {
  'status': 400,
  'message': 'x',
  'data': {
    'name': {'code': code, 'message': 'm'},
  },
};

Map<String, dynamic> _batch(Map<String, dynamic> requests) => {
  'status': 400,
  'message': 'Batch transaction failed.',
  'data': {'requests': requests},
};

Map<String, dynamic> _inner(int status, Map<String, dynamic> data) => {
  'response': {'status': status, 'message': 'inner', 'data': data},
};

Object _caught(ClientException e) {
  try {
    rethrowAsKnownFailure(e, StackTrace.current);
  } on Object catch (thrown) {
    return thrown;
  }
}

void main() {
  group('statusCodeOf', () {
    test('maps not_unique on name to 409', () {
      expect(
        statusCodeOf(_error(400, _validation('validation_not_unique'))),
        409,
      );
    });

    test('maps not_unique on id to 409', () {
      final response = {
        'data': {
          'id': {'code': 'validation_not_unique'},
        },
      };
      expect(statusCodeOf(_error(400, response)), 409);
    });

    test('maps other validation codes to 422', () {
      expect(
        statusCodeOf(_error(400, _validation('validation_required'))),
        422,
      );
    });

    test('maps 400 with empty data to 403', () {
      expect(statusCodeOf(_error(400, {'data': <String, dynamic>{}})), 403);
    });

    test('maps 400 without data key to 403', () {
      expect(statusCodeOf(_error(400, {'message': 'x'})), 403);
    });

    test('keeps 401, 403 and 404', () {
      expect(statusCodeOf(_error(401)), 401);
      expect(statusCodeOf(_error(403)), 403);
      expect(statusCodeOf(_error(404)), 404);
    });

    test('maps 429 to 503', () {
      expect(statusCodeOf(_error(429)), 503);
    });

    test('keeps 5xx and other statuses', () {
      expect(statusCodeOf(_error(500)), 500);
      expect(statusCodeOf(_error(503)), 503);
      expect(statusCodeOf(_error(405)), 405);
    });

    test('unwraps a batch error with not_unique to 409', () {
      final response = _batch({
        '0': <String, dynamic>{},
        '1': _inner(400, {
          'id': {'code': 'validation_not_unique'},
        }),
      });
      expect(statusCodeOf(_error(400, response)), 409);
    });

    test('unwraps a batch error with 404', () {
      expect(statusCodeOf(_error(400, _batch({'0': _inner(404, {})}))), 404);
    });

    test('unwraps a batch error with empty inner data to 403', () {
      expect(statusCodeOf(_error(400, _batch({'0': _inner(400, {})}))), 403);
    });

    test('accepts a batch error as a list', () {
      final response = {
        'data': {
          'requests': [_inner(404, {})],
        },
      };
      expect(statusCodeOf(_error(400, response)), 404);
    });

    test('ignores data of an unexpected type', () {
      expect(statusCodeOf(_error(404, {'data': 'oops'})), 404);
      expect(
        statusCodeOf(
          _error(400, {
            'data': {'requests': 'oops'},
          }),
        ),
        422,
      );
      expect(
        statusCodeOf(
          _error(500, {
            'data': {
              'requests': {'0': 'oops'},
            },
          }),
        ),
        500,
      );
    });
  });

  group('rethrowAsKnownFailure', () {
    test('turns status 0 into NetworkException', () {
      expect(_caught(_error(0)), isA<NetworkException>());
    });

    test('turns an abort into NetworkException', () {
      final abort = ClientException(isAbort: true);
      expect(_caught(abort), isA<NetworkException>());
    });

    test('carries the response message', () {
      final thrown = _caught(_error(404, {'message': 'not found'}));
      expect(thrown, isA<ApiException>());
      expect((thrown as ApiException).statusCode, 404);
      expect(thrown.body, 'not found');
    });

    test('carries the inner message of a batch', () {
      final thrown = _caught(_error(400, _batch({'0': _inner(404, {})})));
      expect((thrown as ApiException).body, 'inner');
    });

    test('uses an empty body without a message', () {
      expect((_caught(_error(500)) as ApiException).body, '');
    });

    test(
      'passes ApiException and NetworkException through as the same instance',
      () {
        final api = ApiException(401, 'session expired');
        final network = NetworkException('x');
        expect(
          () => rethrowAsKnownFailure(api, StackTrace.current),
          throwsA(same(api)),
        );
        expect(
          () => rethrowAsKnownFailure(network, StackTrace.current),
          throwsA(same(network)),
        );
      },
    );

    test('keeps unknown errors as they are', () {
      expect(
        () => rethrowAsKnownFailure(StateError('bug'), StackTrace.current),
        throwsStateError,
      );
    });
  });

  group('requireSession', () {
    test('does nothing with a valid session', () {
      expect(
        () => requireSession(testPocketBase(offlineClient())),
        returnsNormally,
      );
    });

    test('clears an expired token and throws 401', () async {
      final pb = testPocketBase(offlineClient(), signedIn: false);
      pb.authStore.save(fakeAuthToken(DateTime.utc(2000)), null);
      final events = <AuthStoreEvent>[];
      final sub = pb.authStore.onChange.listen(events.add);

      expect(
        () => requireSession(pb),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(pb.authStore.token, isEmpty);
      expect(pb.authStore.record, isNull);
      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('throws 401 without clearing when signed out', () async {
      final pb = testPocketBase(offlineClient(), signedIn: false);
      final events = <AuthStoreEvent>[];
      final sub = pb.authStore.onChange.listen(events.add);

      expect(
        () => requireSession(pb),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  group('with the SDK', () {
    Future<Object?> run(Future<Object?> Function() body) async {
      try {
        await body();
      } on Object catch (e, st) {
        try {
          rethrowAsKnownFailure(e, st);
        } on Object catch (known) {
          return known;
        }
      }
      return null;
    }

    test('offline becomes NetworkException', () async {
      final pb = testPocketBase(offlineClient());
      expect(
        await run(() => pb.collection('x').getFullList()),
        isA<NetworkException>(),
      );
    });

    test('duplicate id becomes 409', () async {
      final pb = testPocketBase(
        MockClient(
          (_) async => errorJson(
            400,
            data: {
              'id': {'code': 'validation_not_unique', 'message': 'dup'},
            },
          ),
        ),
      );
      final thrown = await run(() => pb.collection('x').create(body: {}));
      expect((thrown! as ApiException).statusCode, 409);
    });

    test('batch failure becomes 404', () async {
      final pb = testPocketBase(
        MockClient((_) async => batchErrorJson(index: 0, status: 404)),
      );
      final batch = pb.createBatch();
      batch.collection('x').create(body: {'a': 1});
      final thrown = await run(() => batch.send());
      expect((thrown! as ApiException).statusCode, 404);
    });
  });

  test('listJson is read by getFullList', () async {
    final pb = testPocketBase(
      MockClient(
        (_) async => listJson([
          recordJson('abc123abc123abc', {'name': 'Milk'}),
        ]),
      ),
    );
    final items = await pb.collection('x').getFullList();
    expect(items.single.id, 'abc123abc123abc');
    expect(items.single.getStringValue('user'), testUserId);
  });

  group('SessionExpiredException', () {
    test('requireSession throws SessionExpiredException', () {
      final signedOut = testPocketBase(offlineClient(), signedIn: false);
      expect(
        () => requireSession(signedOut),
        throwsA(isA<SessionExpiredException>()),
      );

      final expired = testPocketBase(offlineClient(), signedIn: false);
      expired.authStore.save(fakeAuthToken(DateTime.utc(2000)), null);
      expect(
        () => requireSession(expired),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('rethrowAsKnownFailure passes the same instance through', () {
      final original = SessionExpiredException();

      expect(
        () => rethrowAsKnownFailure(original, StackTrace.current),
        throwsA(same(original)),
      );
    });
  });
}
