import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../../data/services/api_exception.dart'
    show ApiException, NetworkException;

/// Classifies a technical failure ONCE, so every consumer — the message, a
/// flow decision, a log line — switches over a sealed type instead of
/// re-inspecting the raw exception on its own.
///
/// `sealed` is the whole point: adding a variant below makes every switch over
/// AppFailure stop compiling until it is handled. A chain of `if (e is X)`
/// never tells you that you forgot one.
sealed class AppFailure {
  const AppFailure();

  /// The ONLY place in the app that inspects a raw error.
  factory AppFailure.from(Object error) {
    // Riverpod 3 wraps whatever ref.watch/ref.read rethrows into a
    // ProviderException — ONE LAYER PER HOP in the provider chain, which is
    // why this is a loop and not a single unwrap. Without it every
    // provider-init failure (missing --dart-define, provider not overridden)
    // arrives as an unknown type and falls through to the generic message.
    var raw = error;
    while (raw is ProviderException) {
      raw = raw.exception;
    }

    // Idempotent on purpose: a failure that was already classified must
    // survive a second trip through here. Without this line an AppFailure
    // thrown into the state would fall through to UnexpectedFailure, and
    // "Sem conexão" would reach the screen as the generic sentence. It sits
    // AFTER the loop so it also catches one that arrived wrapped by a hop in
    // the provider chain.
    if (raw is AppFailure) return raw;

    if (raw is NetworkException) return const NoConnection();
    if (raw is ApiException) {
      return switch (raw.statusCode) {
        401 || 403 => const AccessDenied(),
        404 => const RecordNotFound(),
        409 => const DuplicateRecord(),
        >= 500 => const ServerUnavailable(),
        _ => const RequestRejected(),
      };
    }
    // An Error is a bug in our own code, never a runtime condition: bad cast,
    // malformed JSON, missing --dart-define. Telling the user to check the
    // connection would send them chasing a problem that is ours.
    if (raw is Error) return AppBug(raw);
    return UnexpectedFailure(raw);
  }
}

/// The request never reached the server. On this project that is the common
/// case inside a supermarket, not an edge case.
final class NoConnection extends AppFailure {
  const NoConnection();
}

/// 401/403. There is no login here, so this is never an expired session: it is
/// a row-level security policy — or a wrong anon key — saying no.
final class AccessDenied extends AppFailure {
  const AccessDenied();
}

final class RecordNotFound extends AppFailure {
  const RecordNotFound();
}

/// 409. In a system with no concurrent editing (last write wins, by decision),
/// the conflict that actually happens is the catalog's duplicate guard: a type,
/// a category, a brand, a store or a product registration that already exists.
final class DuplicateRecord extends AppFailure {
  const DuplicateRecord();
}

final class ServerUnavailable extends AppFailure {
  const ServerUnavailable();
}

/// A 4xx with no sentence of its own — the server rejected the request and the
/// useful detail, when there is one, lives in the response body.
final class RequestRejected extends AppFailure {
  const RequestRejected();
}

/// Ours to fix. It carries the original Error so the log gets the real cause.
final class AppBug extends AppFailure {
  const AppBug(this.error);

  final Error error;
}

/// Nothing matched. This is the bucket that must stay small: if it starts
/// showing up in the logs, a new failure type deserves a variant.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.error);

  final Object error;
}
