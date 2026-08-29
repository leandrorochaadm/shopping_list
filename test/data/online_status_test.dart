import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/services/connectivity/online_status.dart';
import 'package:shopping_list/data/services/connectivity/online_status_stub.dart';

/// What the Dart VM sees. The browser half is ten lines behind a conditional
/// import and is the one file the suite cannot reach — by design: importing
/// `package:web` unconditionally would break every test, which is the risk
/// §13 of the plan names.
void main() {
  test('the stub is online and mute', () {
    // "Always online" is the honest answer off the browser: there is no
    // navigator to ask, and a fake "offline" would send every test down the
    // pending-submission path.
    expect(readOnlineStatus(), isTrue);
    expect(watchOnlineStatus(), emitsDone);
  });

  test('the provider answers synchronously, with no loading state', () {
    // Screen 3 asks this while deciding what the save button says; a Future
    // there would make the button flicker on every build.
    final container = ProviderContainer.test();

    expect(container.read(onlineStatusProvider), isTrue);
  });

  test('a test can pretend to be offline by overriding the provider', () {
    // The only way to reach the offline path in the suite, and the reason the
    // provider exists instead of a bare function call.
    final container = ProviderContainer.test(
      overrides: [onlineStatusProvider.overrideWith(() => _AlwaysOffline())],
    );

    expect(container.read(onlineStatusProvider), isFalse);
  });
}

final class _AlwaysOffline extends OnlineStatus {
  @override
  bool build() => false;
}
