import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/data/services/pocketbase_error.dart';

import '../helpers/pocketbase_test_client.dart';

http.Response _authOk(DateTime expiresAt) => http.Response(
  jsonEncode({
    'token': fakeAuthToken(expiresAt),
    'record': recordJson(testUserId, {'email': 'a@b.test'}),
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient _noRequests() =>
    MockClient((request) async => fail('no request expected: ${request.url}'));

MockClient _answering(http.Response response) =>
    MockClient((_) async => response);

void _expire(PocketBase pb) =>
    pb.authStore.save(fakeAuthToken(DateTime.utc(2000)), pb.authStore.record);

void main() {
  group('isSignedIn', () {
    test('is signed in with a valid token', () {
      final repository = AuthRepositoryRemote(testPocketBase(_noRequests()));
      expect(repository.isSignedIn, isTrue);
    });

    test('is signed out without a token', () {
      final repository = AuthRepositoryRemote(
        testPocketBase(_noRequests(), signedIn: false),
      );
      expect(repository.isSignedIn, isFalse);
    });

    test('is signed out with an expired token', () {
      final pb = testPocketBase(_noRequests());
      _expire(pb);
      expect(AuthRepositoryRemote(pb).isSignedIn, isFalse);
    });
  });

  group('signIn', () {
    test('signs in and emits true', () async {
      late http.Request sent;
      final pb = testPocketBase(
        MockClient((request) async {
          sent = request;
          return _authOk(DateTime.utc(2100));
        }),
        signedIn: false,
      );
      final repository = AuthRepositoryRemote(pb);
      final emitted = expectLater(repository.changes, emits(true));

      await repository.signIn(email: 'a@b.test', password: 'secret123');
      await emitted;

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/collections/users/auth-with-password');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['identity'], 'a@b.test');
      expect(body['password'], 'secret123');
      expect(repository.isSignedIn, isTrue);
    });

    test('turns a rejected login into a 401', () async {
      final repository = AuthRepositoryRemote(
        testPocketBase(
          _answering(errorJson(400, message: 'Failed to authenticate.')),
          signedIn: false,
        ),
      );

      await expectLater(
        repository.signIn(email: 'a@b.test', password: 'wrong'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('reports no connection when signing in offline', () async {
      final repository = AuthRepositoryRemote(
        testPocketBase(offlineClient(), signedIn: false),
      );

      await expectLater(
        repository.signIn(email: 'a@b.test', password: 'x'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps a rate-limited login to 503', () async {
      final repository = AuthRepositoryRemote(
        testPocketBase(_answering(errorJson(429)), signedIn: false),
      );

      await expectLater(
        repository.signIn(email: 'a@b.test', password: 'x'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('keeps the server status on a failed login', () async {
      final repository = AuthRepositoryRemote(
        testPocketBase(_answering(errorJson(500)), signedIn: false),
      );

      await expectLater(
        repository.signIn(email: 'a@b.test', password: 'x'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('signOut and changes', () {
    test('signs out locally and emits false', () async {
      final pb = testPocketBase(_noRequests());
      final repository = AuthRepositoryRemote(pb);
      final emitted = expectLater(repository.changes, emits(false));

      await repository.signOut();
      await emitted;

      expect(repository.isSignedIn, isFalse);
    });

    test('emits false when requireSession clears an expired token', () async {
      final pb = testPocketBase(_noRequests());
      _expire(pb);
      final repository = AuthRepositoryRemote(pb);
      final emitted = expectLater(repository.changes, emits(false));

      expect(
        () => requireSession(pb),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      await emitted;
    });
  });

  group('restoreSession', () {
    test('restoreSession does nothing without a token', () async {
      final pb = testPocketBase(_noRequests(), signedIn: false);

      await restoreSession(pb);

      expect(pb.authStore.token, isEmpty);
    });

    test('restoreSession clears an expired token without a request', () async {
      final pb = testPocketBase(_noRequests());
      _expire(pb);

      await restoreSession(pb);

      expect(pb.authStore.token, isEmpty);
    });

    test('restoreSession refreshes a valid session', () async {
      final pb = testPocketBase(_answering(_authOk(DateTime.utc(2101))));
      final before = pb.authStore.token;

      await restoreSession(pb);

      expect(pb.authStore.token, isNot(before));
      expect(pb.authStore.isValid, isTrue);
    });

    for (final status in [401, 403]) {
      test('restoreSession clears the session on $status', () async {
        final pb = testPocketBase(_answering(errorJson(status)));

        await restoreSession(pb);

        expect(pb.authStore.isValid, isFalse);
        expect(pb.authStore.token, isEmpty);
      });
    }

    test('restoreSession keeps the session offline', () async {
      final pb = testPocketBase(offlineClient());
      final before = pb.authStore.token;

      await restoreSession(pb);

      expect(pb.authStore.token, before);
      expect(pb.authStore.record?.id, testUserId);
    });

    for (final status in [500, 429]) {
      test(
        'restoreSession keeps the session when the server fails $status',
        () async {
          final pb = testPocketBase(_answering(errorJson(status)));
          final before = pb.authStore.token;

          await restoreSession(pb);

          expect(pb.authStore.token, before);
        },
      );
    }

    test('restoreSession keeps the session on timeout', () async {
      final pb = testPocketBase(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _authOk(DateTime.utc(2101));
        }),
      );
      final before = pb.authStore.token;

      await restoreSession(pb, timeout: const Duration(milliseconds: 10));

      expect(pb.authStore.token, before);
    });
  });
}
