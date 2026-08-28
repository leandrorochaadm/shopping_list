import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'api_exception.dart';

/// Turns a Supabase failure into one of the two exception types the rest of
/// the app knows about, and rethrows it. Every `_remote` method wraps its I/O
/// with this, so nothing above `data/` ever sees a PostgrestException.
///
/// It is a `Never`, so the call site does not need a `return` after it.
Never rethrowAsKnownFailure(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    throw ApiException(statusCodeOf(error), error.message);
  }
  // postgrest talks over package:http, which funnels every transport failure
  // into ClientException. On web there is no SocketException to catch.
  if (error is ClientException) throw NetworkException(error);
  // Not ours to classify: keep the original stack trace instead of a new one
  // starting here, which would point at this function for every app bug.
  Error.throwWithStackTrace(error, stackTrace);
}

/// PostgREST puts the **SQLSTATE** in `code`, not an HTTP status — '23505' for
/// a unique violation, for instance. Parsing it as a number would turn that
/// into "status 23505", which falls into the `>= 500` arm of AppFailure and
/// tells the user the server is down when what happened is that the record
/// already exists.
///
/// Visible for testing; the repositories call [rethrowAsKnownFailure].
int statusCodeOf(PostgrestException error) {
  final code = error.code;
  if (code == null) return 500;

  final sqlState = _httpStatusBySqlState[code];
  if (sqlState != null) return sqlState;

  // PostgREST also returns plain HTTP statuses as strings in some paths.
  final parsed = int.tryParse(code);
  if (parsed != null && parsed >= 100 && parsed <= 599) return parsed;

  return 500;
}

/// Only the states this app can actually produce. Anything else stays 500 —
/// which is honest: an unmapped database error IS a server-side problem.
const _httpStatusBySqlState = <String, int>{
  '23505': 409, // unique_violation — the duplicate guard on the catalog
  '23503': 409, // foreign_key_violation — deleting a row still referenced
  '23502': 422, // not_null_violation
  '23514': 422, // check_violation
  '22P02': 422, // invalid_text_representation — malformed uuid/numeric
  '42501': 403, // insufficient_privilege — RLS said no
  'PGRST116': 404, // no rows returned where exactly one was expected
  'PGRST301': 401, // JWT problem
};
