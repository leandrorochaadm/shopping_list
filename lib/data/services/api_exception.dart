/// The two failure types the layers above this one know about.
///
/// They live in their own file — not inside an `api_client.dart` — because this
/// project has no HTTP client of its own: `supabase_flutter` brings the client,
/// and the repositories talk to it directly. See `10_backend` in the
/// flutter-mvvm skill.
library;

/// The server ANSWERED and said no.
///
/// `final` for the same reason the eight AppFailure variants are: these two
/// are the types `AppFailure.from` runs `is` against, in the only place in the
/// app that inspects a raw exception. A subclass nobody expected would change
/// that classification in silence.
final class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
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
