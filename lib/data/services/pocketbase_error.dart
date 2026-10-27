import 'package:pocketbase/pocketbase.dart';

import 'api_exception.dart';

const _notUniqueCode = 'validation_not_unique';
const _sessionExpiredBody = 'session expired';

/// Turns a PocketBase SDK failure into one of the two exception types the rest
/// of the app knows about, and rethrows it. Every `_remote` method wraps its
/// I/O with this.
///
/// It is a `Never`, so the call site does not need a `return` after it.
Never rethrowAsKnownFailure(Object error, StackTrace stackTrace) {
  // Already classified (e.g. the 401 of requireSession, called inside the
  // `try`): pass the same instance through.
  if (error is ApiException || error is NetworkException) {
    Error.throwWithStackTrace(error, stackTrace);
  }
  if (error is ClientException) {
    // Status 0 means no response at all (offline, aborted).
    if (error.statusCode == 0) throw NetworkException(error);
    throw ApiException(statusCodeOf(error), _messageOf(error));
  }
  // Not ours to classify: keep the original stack trace.
  Error.throwWithStackTrace(error, stackTrace);
}

/// Throws a 401 when there is no valid session.
///
/// An expired token becomes an **anonymous** call in PocketBase (empty list,
/// create answers 400), never a 401, so the check has to happen here. Clearing
/// the store fires `authStore.onChange`.
void requireSession(PocketBase pb) {
  if (pb.authStore.isValid) return;
  // Only clear when there is something to clear, to avoid repeated onChange
  // events on every call after sign-out.
  if (pb.authStore.token.isNotEmpty) pb.authStore.clear();
  throw ApiException(401, _sessionExpiredBody);
}

/// Maps a PocketBase failure to the HTTP status `AppFailure.from` expects.
///
/// Visible for testing; the repositories call [rethrowAsKnownFailure].
int statusCodeOf(ClientException error) {
  var status = error.statusCode;
  Object? data = _mapOf(error.response)?['data'];

  // Batch errors come nested: data.requests.<index>.response.
  final requests = _mapOf(data)?['requests'];
  final inner = _firstInnerResponse(requests);
  if (inner != null) {
    status = _intOf(inner['status']) ?? status;
    data = inner['data'];
  }

  final dataMap = _mapOf(data);
  final hasData = dataMap != null && dataMap.isNotEmpty;

  switch (status) {
    case 400:
      if (hasData) {
        final duplicated = dataMap.values.any(
          (field) => _mapOf(field)?['code'] == _notUniqueCode,
        );
        return duplicated ? 409 : 422;
      }
      // The 0.40.5 answers 400 without data when createRule blocks the create.
      return 403;
    case 429:
      // Rate limit: for the user it is "server unavailable".
      return 503;
    default:
      return status;
  }
}

String _messageOf(ClientException error) {
  var message = _mapOf(error.response)?['message'];
  final data = _mapOf(_mapOf(error.response)?['data']);
  final inner = _firstInnerResponse(data?['requests']);
  if (inner != null) message = inner['message'];
  return message is String ? message : '';
}

Map<String, dynamic>? _firstInnerResponse(Object? requests) {
  final Iterable<Object?> entries;
  if (requests is Map) {
    entries = requests.values;
  } else if (requests is List) {
    entries = requests;
  } else {
    return null;
  }
  for (final entry in entries) {
    final response = _mapOf(_mapOf(entry)?['response']);
    if (response != null) return response;
  }
  return null;
}

Map<String, dynamic>? _mapOf(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;

int? _intOf(Object? value) => value is int ? value : null;
