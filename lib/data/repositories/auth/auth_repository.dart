import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sign-in, session and sign-out. I/O only.
abstract class AuthRepository {
  /// A valid session RIGHT NOW (token not expired), not just "there is a
  /// token". It is synchronous because the `redirect` of go_router cannot
  /// await anything.
  bool get isSignedIn;

  /// Broadcast. Emits [isSignedIn] every time the session is saved or cleared.
  Stream<bool> get changes;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Overridden in `config/dependencies.dart`.
///
/// Unoverridden it throws, and the throw is an Error: `AppFailure` classifies
/// it as [AppBug], which is exactly what a forgotten override is.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider was not overridden. See config/dependencies.dart.',
  ),
);
