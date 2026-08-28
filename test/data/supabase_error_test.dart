import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/data/services/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  group('statusCodeOf', () {
    test('maps a unique violation to 409, not to a 23505 server error', () {
      // The duplicate guard on the catalog is the failure this project hits
      // the most, and reading the SQLSTATE as a number would send the user
      // "the server is unavailable" instead of "this record already exists".
      final error = PostgrestException(message: 'duplicate key', code: '23505');

      expect(statusCodeOf(error), 409);
    });

    test('maps a foreign key violation to 409', () {
      expect(
        statusCodeOf(PostgrestException(message: 'fk', code: '23503')),
        409,
      );
    });

    test('maps a not-null violation to 422', () {
      expect(
        statusCodeOf(PostgrestException(message: 'null value', code: '23502')),
        422,
      );
    });

    test('maps a check violation to 422', () {
      expect(
        statusCodeOf(
          PostgrestException(message: 'check failed', code: '23514'),
        ),
        422,
      );
    });

    test('maps a malformed uuid or numeric to 422', () {
      expect(
        statusCodeOf(
          PostgrestException(message: 'invalid input', code: '22P02'),
        ),
        422,
      );
    });

    test('maps an RLS denial to 403', () {
      expect(
        statusCodeOf(PostgrestException(message: 'denied', code: '42501')),
        403,
      );
    });

    test('maps "no rows returned" to 404', () {
      expect(
        statusCodeOf(PostgrestException(message: 'no rows', code: 'PGRST116')),
        404,
      );
    });

    test('maps a JWT problem to 401, so it never reads as a server outage', () {
      // 401 is what makes AppFailure answer AccessDenied. Losing this line
      // would tell the user the server is down when the anon key is wrong.
      expect(
        statusCodeOf(
          PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        ),
        401,
      );
    });

    test('keeps a plain HTTP status when PostgREST returns one', () {
      expect(
        statusCodeOf(PostgrestException(message: 'not found', code: '404')),
        404,
      );
    });

    test('keeps the exact edges of the HTTP status range', () {
      expect(statusCodeOf(PostgrestException(message: 'x', code: '100')), 100);
      expect(statusCodeOf(PostgrestException(message: 'x', code: '599')), 599);
    });

    test('rejects a number just outside the HTTP status range', () {
      // 99 and 600 are not statuses: they are SQLSTATEs that happen to parse.
      // Letting them through would invent a status AppFailure cannot classify.
      expect(statusCodeOf(PostgrestException(message: 'x', code: '99')), 500);
      expect(statusCodeOf(PostgrestException(message: 'x', code: '600')), 500);
    });

    test('falls back to 500 for an unmapped state and for a missing code', () {
      expect(
        statusCodeOf(PostgrestException(message: 'x', code: '42P01')),
        500,
      );
      expect(statusCodeOf(PostgrestException(message: 'x')), 500);
    });
  });

  group('rethrowAsKnownFailure', () {
    test('turns a PostgrestException into an ApiException', () {
      expect(
        () => rethrowAsKnownFailure(
          PostgrestException(message: 'duplicate key', code: '23505'),
          StackTrace.empty,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('turns a transport failure into a NetworkException', () {
      expect(
        () => rethrowAsKnownFailure(
          ClientException('connection closed'),
          StackTrace.empty,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('rethrows anything else untouched, so our bugs stay our bugs', () {
      expect(
        () => rethrowAsKnownFailure(StateError('boom'), StackTrace.empty),
        throwsA(isA<StateError>()),
      );
    });
  });
}
