import 'dart:async';

import 'auth_repository.dart';

/// In-memory fake: debug without configuration, and every screen test.
///
/// It starts signed in. Not `final`: the ViewModel tests extend it with a spy
/// that fails the next call.
class AuthRepositoryLocal implements AuthRepository {
  AuthRepositoryLocal({
    bool signedIn = true,
    this.latency = const Duration(milliseconds: 400),
  }) : _signedIn = signedIn; // ignore: prefer_initializing_formals

  /// Roughly what the real thing costs. Tests pass [Duration.zero].
  final Duration latency;

  final _controller = StreamController<bool>.broadcast();
  bool _signedIn;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(latency);
    _set(true);
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(latency);
    _set(false);
  }

  Future<void> dispose() => _controller.close();

  void _set(bool value) {
    if (_signedIn == value) return;
    _signedIn = value;
    _controller.add(value);
  }
}
