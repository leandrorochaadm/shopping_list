import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/device_user/device_user_repository.dart';
import '../../../data/repositories/purchase_draft/purchase_draft_repository.dart';
import '../../../domain/models/purchase_draft.dart';
import '../../../domain/models/purchase_item.dart';
import '../../core/error_translation.dart';

/// Whether the purchase ON SCREEN came from a previous run of the app —
/// which is the only honest reading of "rascunho recuperado".
///
/// It cannot live on the entity: the same stored draft has to read as "born
/// now" to the session that wrote it and "recovered" to the next one. And it
/// cannot be recomputed from the box either, because after the first line is
/// typed the box always has one.
///
/// So it is answered ONCE, from the box, and then **consumed**: saving or
/// discarding replaces the recovered purchase with a new one, and what is on
/// screen from that moment was born here.
///
/// **It is pinned by the first `build()` of the ViewModel below**, which runs
/// before anything can be typed.
final class RecoveredDraft extends Notifier<bool> {
  @override
  bool build() => ref.watch(purchaseDraftRepositoryProvider).readNow() != null;

  /// The recovered purchase is gone — registered, or thrown away.
  void consumed() => state = false;
}

final recoveredDraftProvider = NotifierProvider<RecoveredDraft, bool>(
  RecoveredDraft.new,
);

/// What paints the "Rascunho recuperado" banner: a draft from a previous run
/// that nobody has dismissed yet. Composed here, once, so no screen puts the
/// two halves together on its own.
final recoveryBannerProvider = Provider<bool>(
  (ref) =>
      ref.watch(recoveredDraftProvider) &&
      !ref.watch(
        purchaseDraftViewModelProvider.select((draft) => draft.bannerDismissed),
      ),
);

/// The purchase being typed — H8's whole story, and the state screen 3 draws.
///
/// A `Notifier<PurchaseDraft>` and not an `AsyncNotifier`: it is born from
/// Hive, which is synchronous, so this `build()` makes no network call and
/// cannot fail the way the CLAUDE.md reservation warns about. The reservation
/// is about an initial LOAD losing the protection of `build()`; there is no
/// load here.
final class PurchaseDraftViewModel extends Notifier<PurchaseDraft> {
  /// Reentrancy guard (rule 14). Every mutation here is a local write and
  /// each one recomputes the draft from `state`, so a dropped second tap
  /// costs nothing — what it prevents is two writes racing to the same key.
  bool _running = false;

  @override
  PurchaseDraft build() {
    // Pins the session answer before a single line can be typed. `read` and
    // not `watch`: the value never changes, and depending on it would only
    // add a rebuild path that must not exist.
    ref.read(recoveredDraftProvider);

    return ref.watch(purchaseDraftRepositoryProvider).readNow() ??
        PurchaseDraft.startedOn(
          // The clock enters the system HERE (rule 9), never in a widget and
          // never in an entity.
          DateTime.now(),
          // This phone's label, copied into the purchase. `readNow` is
          // synchronous because the box is opened by `main`, and the router's
          // redirect guarantees the label exists — no route opens without it.
          ref.watch(storedDeviceUserProvider)?.name ?? '',
        );
  }

  /// **This build() runs more than once.** It watches `storedDeviceUserProvider`,
  /// which `DeviceUserViewModel.save` invalidates when the label is changed in
  /// Configurações, and Riverpod then recreates the notifier. With a draft in
  /// the box that is harmless — `readNow()` returns the same object, purchase
  /// key included. With NO draft saved yet, `startedOn` draws a new key and
  /// reads the clock again, which is why **nothing outside this notifier ever
  /// holds the purchase key**: whoever needs it reads it from `state`.

  Future<String?> setDate(DateTime date) =>
      _mutate(state.copyWith(date: date), 'guardar a data da compra');

  Future<String?> setStore(String storeId) =>
      _mutate(state.copyWith(storeId: storeId), 'guardar o mercado');

  /// Adds the line — or REPLACES the one with the same id, which is what the
  /// `[ed]` of an item already in the purchase does.
  Future<String?> putItem(PurchaseItem item) =>
      _mutate(state.withItem(item), 'guardar o item da compra');

  Future<String?> removeItem(String itemId) =>
      _mutate(state.withoutItem(itemId), 'remover o item da compra');

  /// Saved with no signal: it will go up when the connection comes back with
  /// the app open, or on the next opening.
  Future<String?> markPending() =>
      _mutate(state.markedPending(), 'guardar a compra no aparelho');

  /// The `[ Continuar ]` of the recovered-draft banner. It is persisted, so
  /// the banner does not come back when this notifier is rebuilt.
  Future<String?> dismissBanner() =>
      _mutate(state.dismissedBanner(), 'guardar o rascunho');

  /// The `[ Descartar ]` of the banner: the recovered purchase is thrown
  /// away and a new one begins.
  Future<String?> discard() => clear();

  /// Runs right after a purchase is registered, and it is the ONLY guard
  /// against the same purchase being saved twice.
  Future<String?> clear() async {
    if (_running) return null;
    _running = true;
    try {
      await ref.read(purchaseDraftRepositoryProvider).clear();
      if (!ref.mounted) return null;

      state = PurchaseDraft.startedOn(DateTime.now(), state.registeredBy);
      // Whatever is on screen from here on was born in this run — without
      // this the banner would come back over an empty purchase, or over the
      // next one being typed.
      ref.read(recoveredDraftProvider.notifier).consumed();
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;
      // The draft could not be erased. The screen still starts a new
      // purchase, because the one that was there is registered — leaving it
      // on screen would invite a second save of a purchase that already
      // exists.
      state = PurchaseDraft.startedOn(DateTime.now(), state.registeredBy);
      ref.read(recoveredDraftProvider.notifier).consumed();
      return translateError(e, st, 'limpar o rascunho');
    } finally {
      _running = false;
    }
  }

  /// The one mutation, written once. **It persists BEFORE swapping the
  /// state** — but it swaps it even when the write was refused, and that is
  /// deliberate: a browser that denies IndexedDB (a private window) must not
  /// make eighteen typed items disappear from the screen. The sentence tells
  /// the person the purchase is not safe yet; the purchase itself stays.
  Future<String?> _mutate(PurchaseDraft next, String action) async {
    if (_running) return null;
    _running = true;
    try {
      await ref.read(purchaseDraftRepositoryProvider).save(next);
      if (!ref.mounted) return null;

      state = next;
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      state = next;
      return translateError(e, st, action);
    } finally {
      _running = false;
    }
  }
}

/// No `retry`: there is no future here to repeat, and the state is local.
final purchaseDraftViewModelProvider =
    NotifierProvider<PurchaseDraftViewModel, PurchaseDraft>(
      PurchaseDraftViewModel.new,
    );
