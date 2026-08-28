import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/app_failure.dart';

void main() {
  group('AppFailure.from', () {
    test('classifies a transport failure as NoConnection', () {
      expect(
        AppFailure.from(NetworkException(Exception('offline'))),
        isA<NoConnection>(),
      );
    });

    test('classifies 401 and 403 as AccessDenied', () {
      expect(AppFailure.from(ApiException(401, '')), isA<AccessDenied>());
      expect(AppFailure.from(ApiException(403, '')), isA<AccessDenied>());
    });

    test('classifies 404 as RecordNotFound', () {
      expect(AppFailure.from(ApiException(404, '')), isA<RecordNotFound>());
    });

    test('classifies 409 as DuplicateRecord', () {
      expect(AppFailure.from(ApiException(409, '')), isA<DuplicateRecord>());
    });

    test('classifies 5xx as ServerUnavailable', () {
      expect(AppFailure.from(ApiException(500, '')), isA<ServerUnavailable>());
      expect(AppFailure.from(ApiException(503, '')), isA<ServerUnavailable>());
    });

    test('classifies any other 4xx as RequestRejected', () {
      expect(AppFailure.from(ApiException(422, '')), isA<RequestRejected>());
    });

    test('classifies an Error as our own bug, not a connection problem', () {
      expect(AppFailure.from(ArgumentError('bad cast')), isA<AppBug>());
    });

    test('falls back to UnexpectedFailure for anything unknown', () {
      expect(AppFailure.from(Exception('?')), isA<UnexpectedFailure>());
    });

    test('unwraps the ProviderException Riverpod wraps a failure into', () {
      // Built through a real container instead of by hand: the wrapping is
      // Riverpod's, and ProviderException's constructor is internal to it.
      final failing = Provider<int>(
        (ref) => throw NetworkException(Exception('offline')),
      );
      final container = ProviderContainer.test();

      Object? caught;
      try {
        container.read(failing);
      } on Object catch (e) {
        caught = e;
      }

      // The guard: if Riverpod ever stopped wrapping, this test would be
      // passing for the wrong reason.
      expect(caught, isNot(isA<NetworkException>()));
      expect(AppFailure.from(caught!), isA<NoConnection>());
    });

    test('unwraps nested wrappers, one per provider hop', () {
      final failing = Provider<int>((ref) => throw ApiException(404, ''));
      final middle = Provider<int>((ref) => ref.watch(failing));
      final outer = Provider<int>((ref) => ref.watch(middle));
      final container = ProviderContainer.test();

      Object? caught;
      try {
        container.read(outer);
      } on Object catch (e) {
        caught = e;
      }

      // Fails if the unwrap ever goes back to a single `if` instead of a loop.
      expect(AppFailure.from(caught!), isA<RecordNotFound>());
    });
  });
}
