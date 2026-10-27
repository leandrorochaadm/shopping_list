/// The failure types the layers above this one know about.
///
/// They live in their own file — not inside an `api_client.dart` — because this
/// project has no HTTP client of its own: `supabase_flutter` brings the client,
/// and the repositories talk to it directly. See `10_backend` in the
/// flutter-mvvm skill.
library;

/// The server ANSWERED and said no.
///
/// `final` for the same reason the AppFailure variants are: these types are
/// what `AppFailure.from` runs `is` against, in the only place in the app that
/// inspects a raw exception. The only subclass is [SessionExpiredException],
/// which `AppFailure.from` tests BEFORE this one; any other would change that
/// classification in silence.
final class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// The session is gone: there is no token, or it expired. A 401 of its own so
/// that a bare `ApiException(401)` keeps meaning "the server said no".
final class SessionExpiredException extends ApiException {
  SessionExpiredException() : super(401, 'session expired');
}

/// No answer came back at all. Keeping this separate from ApiException is what
/// lets the UI report NoConnection only when that is actually true — see the
/// AppFailure classification in `ui/core/app_failure.dart`.
final class NetworkException implements Exception {
  NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException: $cause';
}
