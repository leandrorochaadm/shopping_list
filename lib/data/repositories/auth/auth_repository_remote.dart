import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../../services/api_exception.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'auth_repository.dart';

/// How long the opening waits for the session renewal. A technical constant:
/// `main` waits for [restoreSession] before runApp, and a slow network would
/// leave a blank screen.
const restoreSessionTimeout = Duration(seconds: 5);

const _wrongCredentialsBody = 'invalid credentials';

final class AuthRepositoryRemote implements AuthRepository {
  AuthRepositoryRemote(this._pb);

  final PocketBase _pb;

  @override
  bool get isSignedIn => _pb.authStore.isValid;

  // Not a controller of our own: it would miss the `clear` that
  // `requireSession` does, which only touches the authStore.
  @override
  Stream<bool> get changes =>
      _pb.authStore.onChange.map((_) => _pb.authStore.isValid);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _pb
          .collection(PbCollections.users)
          .authWithPassword(email, password);
    } on ClientException catch (e, st) {
      // PocketBase answers a wrong password with 400, which the translator
      // would read as a blocked create (403).
      if (e.statusCode == 400) {
        Error.throwWithStackTrace(ApiException(401, _wrongCredentialsBody), st);
      }
      rethrowAsKnownFailure(e, st);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  // The PocketBase token cannot be revoked on the server: no request.
  @override
  Future<void> signOut() async => _pb.authStore.clear();
}

/// Renews the saved session at app opening. Called by `main` before runApp.
///
/// Only 401/403 end the session; offline, a slow or failing server keeps it,
/// so the app opens with what is stored.
Future<void> restoreSession(
  PocketBase pb, {
  Duration timeout = restoreSessionTimeout,
}) async {
  if (pb.authStore.token.isEmpty) return;
  if (!pb.authStore.isValid) {
    pb.authStore.clear();
    return;
  }
  try {
    await pb.collection(PbCollections.users).authRefresh().timeout(timeout);
  } on ClientException catch (e) {
    if (e.statusCode == 401 || e.statusCode == 403) pb.authStore.clear();
  } on TimeoutException {
    // Keeps the session.
  }
}
