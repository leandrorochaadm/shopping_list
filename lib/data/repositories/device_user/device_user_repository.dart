import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/device_user.dart';

/// Reads and writes the device user label. I/O only — the rule about what a
/// valid name is lives in [DeviceUser].
abstract class DeviceUserRepository {
  /// The label saved on this device, or null on a phone that was never asked.
  Future<DeviceUser?> read();

  /// The same read, without awaiting. It exists for ONE caller: the
  /// `redirect` of the router, which go_router runs synchronously and which
  /// therefore cannot await anything. The Hive box is opened by `main` before
  /// runApp precisely so this can be honest instead of a cached guess.
  DeviceUser? readNow();

  Future<void> save(DeviceUser user);
}

/// Overridden in `config/dependencies.dart` — with the fake in debug without
/// --dart-define, with Hive everywhere else.
///
/// Unoverridden it throws, and the throw is an Error: `AppFailure` classifies
/// it as [AppBug] and the screen says the app has a problem, which is exactly
/// what a forgotten override is.
final deviceUserRepositoryProvider = Provider<DeviceUserRepository>(
  (ref) => throw UnimplementedError(
    'deviceUserRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);

/// What the `redirect` reads, and the ONLY provider that may be read from it.
///
/// A plain Provider CACHES: it holds the null of the first read until someone
/// invalidates it. That is why [DeviceUserViewModel.save] invalidates this
/// one — without it, saving the label changes nothing that the redirect can
/// see, and `context.go('/')` bounces straight back to the welcome screen.
final storedDeviceUserProvider = Provider<DeviceUser?>(
  (ref) => ref.watch(deviceUserRepositoryProvider).readNow(),
);
