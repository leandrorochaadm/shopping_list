import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_status_platform.dart';

/// Whether the browser thinks there is a connection.
///
/// A `Notifier<bool>` and not a `StreamProvider`: the first answer is
/// SYNCHRONOUS — `navigator.onLine` costs nothing — and an `AsyncValue` would
/// give screen 3 a "loading the connection" state that does not exist.
///
/// **Tests override this provider whole.** There is no navigator in the Dart
/// VM, and the stub is deliberately mute rather than pretending otherwise —
/// which is why this class is NOT `final`: the offline path is reachable only
/// by extending it, the same way the `_local` fakes are extended by their
/// spies.
class OnlineStatus extends Notifier<bool> {
  @override
  bool build() {
    // A pure build(): it subscribes and returns, with nothing that can throw.
    // In a Notifier<State> an error in build() is rethrown as a
    // ProviderException on read, and the whole app would fall over because of
    // a connection flag.
    final subscription = watchOnlineStatus().listen((online) => state = online);
    ref.onDispose(subscription.cancel);
    return readOnlineStatus();
  }
}

/// No `retry`: there is no future here to repeat.
final onlineStatusProvider = NotifierProvider<OnlineStatus, bool>(
  OnlineStatus.new,
);
