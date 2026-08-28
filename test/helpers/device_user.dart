import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/domain/models/device_user.dart';

/// The device user label every widget test needs, in ONE place.
///
/// Since H1 there is a redirect: a test that pumps a screen without answering
/// "who is using this phone" lands on the welcome screen instead of the screen
/// it meant to pump. Nine more screens are coming, and each of them would
/// otherwise repeat this override.
///
/// [name] null means a phone that was never asked — the state the redirect
/// exists for.
Override deviceUserOverride({String? name = 'Leandro'}) =>
    deviceUserRepositoryProvider.overrideWith(
      (ref) => DeviceUserRepositoryLocal(
        initial: name == null ? null : DeviceUser(name),
        // Zero, not the fake's 400 ms: what is being tested here is the
        // screen, and every pumpAndSettle would otherwise carry the delay.
        latency: Duration.zero,
      ),
    );
