import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../core/error_translation.dart';

/// Ends the session. The state is `true` while the sign-out is running.
///
/// It only calls [AuthRepository.signOut]: the purchase draft and the device
/// user label stay as they were. Navigation is not here either: the router's
/// redirect takes the person to the login screen.
final class SignOutViewModel extends Notifier<bool> {
  /// Reentrancy guard: a double tap would otherwise sign out twice.
  bool _running = false;

  // Does NOT read the auth repository: screens that never override the
  // session can still build.
  @override
  bool build() => false;

  /// Signs out and returns null, or the pt-BR sentence for the SnackBar.
  Future<String?> signOut() async {
    if (_running) return null;
    _running = true;
    state = true;
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!ref.mounted) return null;
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'sair');
    } finally {
      _running = false;
      if (ref.mounted) state = false;
    }
  }
}

final signOutViewModelProvider = NotifierProvider<SignOutViewModel, bool>(
  SignOutViewModel.new,
);
