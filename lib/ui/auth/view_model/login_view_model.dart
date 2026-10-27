import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../core/error_translation.dart';

/// Validates the sign-in form and calls the [AuthRepository].
///
/// The state is `true` while a sign-in is running. Navigation after success is
/// not here: the router's redirect takes the person out of the login screen.
final class LoginViewModel extends Notifier<bool> {
  /// Reentrancy guard: a double tap would otherwise sign in twice.
  bool _running = false;

  @override
  bool build() => false;

  /// Signs in and returns null, or the pt-BR sentence for the SnackBar.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (_running) return null;
    _running = true;
    state = true;
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        return 'Preencha o e-mail e a senha.';
      }
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password);
      return null;
    } on Object catch (e, st) {
      return translateSignInError(e, st);
    } finally {
      _running = false;
      if (ref.mounted) state = false;
    }
  }
}

final loginViewModelProvider = NotifierProvider<LoginViewModel, bool>(
  LoginViewModel.new,
);
