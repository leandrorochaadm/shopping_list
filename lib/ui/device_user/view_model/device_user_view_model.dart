import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/device_user/device_user_repository.dart';
import '../../../domain/models/device_user.dart';
import '../../core/error_translation.dart';

/// The label of who is using this phone: read on startup, written by the
/// welcome screen and by settings.
///
/// The state is `DeviceUser?` and the null is meaningful — it is a phone that
/// was never asked, which is exactly what the router's redirect acts on.
final class DeviceUserViewModel extends AsyncNotifier<DeviceUser?> {
  /// Reentrancy guard. The list stays on screen during an action, so the
  /// button stays tappable: without this a double tap writes twice.
  bool _running = false;

  @override
  Future<DeviceUser?> build() => ref.watch(deviceUserRepositoryProvider).read();

  /// Saves the label and returns null on success, or the pt-BR sentence the
  /// View should put in a SnackBar. Errors of an ACTION never take over the
  /// screen — what is already there stays.
  Future<String?> save(String name) async {
    if (_running) return null;
    _running = true;
    try {
      // The rule lives in the entity, and it is asked BEFORE the I/O: a name
      // made of blanks never reaches Hive.
      final user = DeviceUser(name);

      await ref.read(deviceUserRepositoryProvider).save(user);
      if (!ref.mounted) return null;

      // The redirect reads a plain Provider, and a plain Provider caches:
      // without this line the router still sees the old null, and the
      // `context.go('/')` of the welcome screen bounces right back to it. The
      // symptom — "the welcome screen never goes away" — points at nothing.
      ref.invalidate(storedDeviceUserProvider);
      state = AsyncData(user);
      return null;
    } on EmptyDeviceUserName catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, 'salvar quem está usando');
    } finally {
      _running = false;
    }
  }

  /// Re-reads the label after a failed load. Returns null on success, or the
  /// sentence for the SnackBar.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<DeviceUser?>();

      final user = await ref.read(deviceUserRepositoryProvider).read();
      if (!ref.mounted) return null;

      state = AsyncData(user);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'ler quem está usando');
      // With nothing to fall back on, the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value)
          : AsyncError<DeviceUser?>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now —
/// not after 6.4 seconds of blank waiting.
final deviceUserViewModelProvider =
    AsyncNotifierProvider<DeviceUserViewModel, DeviceUser?>(
      DeviceUserViewModel.new,
      retry: (retryCount, error) => null,
    );
