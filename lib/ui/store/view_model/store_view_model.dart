import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/store/store_repository.dart';
import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/store.dart';
import '../../core/error_translation.dart';

/// The stores, and the one action H3 has: creating one.
///
/// H3 has no screen of its own — the dialog lives inside screen 3, which is
/// H7's. Until then this ViewModel and its tests are what prove the story
/// works, which is exactly the reservation `handoff §H3` makes.
final class StoreViewModel extends AsyncNotifier<IList<Store>> {
  /// Reentrancy guard: the list stays on screen during an action, so the
  /// button stays tappable and a double tap would otherwise write twice.
  bool _running = false;

  @override
  Future<IList<Store>> build() => ref.watch(storeRepositoryProvider).fetchAll();

  /// Creates a store and returns null, or the pt-BR sentence for the SnackBar.
  ///
  /// The duplicate guard answers HERE, before the I/O — the unique index in
  /// Postgres is the net underneath, and a net is not an explanation.
  Future<String?> create(String name) async {
    if (_running) return null;
    _running = true;
    try {
      // The rule lives in the entity: a name made of blanks never reaches the
      // database.
      final store = Store(name: name);

      // The guard needs the list, and H3 has no screen of its own: the dialog
      // is opened from screen 3, so nothing may have watched this provider
      // yet and `state.value` would be null. A null list is not "no conflict"
      // — it is "no answer", and letting it through is how a second
      // "Carrefour" is born.
      var stores = state.value;
      if (stores == null) {
        stores = await ref.read(storeRepositoryProvider).fetchAll();
        if (!ref.mounted) return null;
        state = AsyncData(stores);
      }

      final conflict = findNameConflict(stores, name);
      if (conflict != null) return _conflictMessage(conflict);

      final created = await ref.read(storeRepositoryProvider).create(store);
      if (!ref.mounted) return null;

      state = AsyncData([...?state.value, created].toIList());
      return null;
    } on BlankName catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, 'salvar o mercado');
    } finally {
      _running = false;
    }
  }

  /// Re-reads the list. Returns null on success, or the sentence for the
  /// SnackBar — the list already on screen stays there.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<IList<Store>>();

      final stores = await ref.read(storeRepositoryProvider).fetchAll();
      if (!ref.mounted) return null;

      state = AsyncData(stores);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar os mercados');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<IList<Store>>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// Decision B3: the guard sees the deactivated rows too, and the way out of
  /// a deactivated match is to REACTIVATE the one that exists — never to
  /// create a second one, which would split its purchase history in two.
  /// Reactivating itself belongs to the catalog maintenance screen (H10).
  String _conflictMessage(Store conflict) => conflict.active
      ? 'Já existe o mercado ${conflict.name}.'
      : 'O mercado ${conflict.name} existe, mas está desativado. '
            'Reative-o na manutenção do cadastro.';
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final storeViewModelProvider =
    AsyncNotifierProvider<StoreViewModel, IList<Store>>(
      StoreViewModel.new,
      retry: (retryCount, error) => null,
    );
