import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/online_status.dart';

/// The state half of the online/offline detection. The platform reading it
/// subscribes to stays in `data/services/connectivity/`, and is covered by
/// `test/data/online_status_test.dart`.
void main() {
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
