import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/shopping_list/shopping_list_repository.dart';
import '../../../domain/models/pending_changes.dart';

/// The banner. It is the list's update mechanism (decision of 26/08/2026): the
/// screen redraws itself nowhere on its own — what arrived from the other
/// phone stays HERE, and it is the tap that redraws.
final class PendingChangesNotifier extends Notifier<PendingChanges> {
  @override
  PendingChanges build() {
    // A PURE build(): it subscribes and returns, with no await and nothing
    // that can throw. In a Notifier<State> the error of build() does not
    // become one of the states — it is rethrown as a ProviderException on
    // read, and the whole screen would fall over because of a banner.
    final subscription = ref
        .watch(shoppingListRepositoryProvider)
        .watchChanges()
        .listen((kind) => state = state.plus(kind));

    ref.onDispose(subscription.cancel);
    return PendingChanges.none;
  }

  /// Called together with the refresh, when the banner is tapped.
  void clear() => state = PendingChanges.none;
}

/// No `retry`: there is no future here to repeat.
final pendingChangesProvider =
    NotifierProvider<PendingChangesNotifier, PendingChanges>(
      PendingChangesNotifier.new,
    );
