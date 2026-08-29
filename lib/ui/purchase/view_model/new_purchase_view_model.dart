import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/purchase/purchase_repository.dart';
import '../../../data/repositories/shopping_list/shopping_list_repository.dart';
import '../../../data/services/connectivity/online_status.dart';
import '../../../domain/models/price_reference.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_draft.dart';
import '../../../domain/models/write_off_plan.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import 'purchase_draft_view_model.dart';

/// How a save ended. **Three outcomes, not two**, which is why this is a
/// sealed type and not the project's usual `String?`.
///
/// The third — "guardei no aparelho e vou tentar depois" — is neither an
/// error nor a success: the screen shows a banner instead of a SnackBar and
/// does NOT navigate away. A `String?` would force the screen to guess from
/// the text.
///
/// This is **not** the `Result<T>` rule 15 forbids: that one is a repository's
/// return type crossing the layers. This is one screen action's outcome.
sealed class SaveOutcome {
  const SaveOutcome();
}

final class PurchaseSaved extends SaveOutcome {
  const PurchaseSaved();
}

/// No signal: the purchase is on the phone, marked as pending, and will go up
/// when the connection comes back with the app OPEN, or on the next opening.
final class PurchaseHeldOffline extends SaveOutcome {
  const PurchaseHeldOffline();
}

final class SaveFailed extends SaveOutcome {
  const SaveFailed(this.message);

  /// pt-BR, already translated — the raw exception never reaches a screen.
  final String message;
}

/// The I/O of screen 3: the Produto picker, and the single transactional
/// write that registers a purchase.
///
/// **The stores are NOT here.** They are `storeViewModelProvider`, which the
/// SCREEN watches in parallel. Watching it from this `build()` would make
/// `NewStoreDialog` — which sets `AsyncData` on that provider — invalidate
/// this one, redoing both catalog queries and blanking the two fields in the
/// face of whoever just registered a store. Two `ref.watch` in the widget's
/// build cost two lines and keep the loads independent.
final class NewPurchaseViewModel extends AsyncNotifier<IList<ProductOption>> {
  /// Reentrancy guard (rule 14): the purchase stays on screen during the
  /// save, so the button stays tappable — and a double tap on `[ Salvar
  /// compra ]` would otherwise be two write attempts.
  bool _running = false;

  @override
  Future<IList<ProductOption>> build() => _load();

  /// The body of `build()`, extracted because `refresh()` needs it too.
  Future<IList<ProductOption>> _load() async {
    final repository = ref.watch(purchaseRepositoryProvider);

    // Started together, awaited together: two round trips in sequence would
    // be twice the wait on a phone, in an aisle.
    final options = repository.fetchProductOptions();
    // The clock enters the system HERE (rule 9). No `now()` and no
    // `current_date` in SQL (decision 7).
    final history = repository.fetchRecentItems(
      threeMonthsBefore(DateTime.now()),
    );

    return rankOptions(await options, await history);
  }

  /// Re-reads the picker. Returns null on success, or the sentence for the
  /// SnackBar — what is already on screen stays there.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<IList<ProductOption>>();

      final options = await _load();
      if (!ref.mounted) return null;

      state = AsyncData(options);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar os produtos');
      // With nothing to fall back on the failure has to OCCUPY the field:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<IList<ProductOption>>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// Registers the purchase, writes the list off, and kills the draft.
  ///
  /// Returns `null` when the reentrancy guard barred a second tap — the
  /// screen shows nothing then, which is the same `return null` the rest of
  /// the project uses.
  Future<SaveOutcome?> save({
    required PurchaseDraft draft,
    required DateTime today,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      // 1. The rules, before any I/O — and all of them the domain's.
      Purchase.checkDate(draft.date, today);
      final storeId = draft.storeId;
      if (storeId == null) throw const MissingStore();
      if (draft.items.isEmpty) throw const EmptyPurchase();

      // 2. No signal, no attempt: it is kept and the second outcome is
      //    returned. The draft already holds the purchase key, so the resend
      //    cannot become a second purchase.
      if (!ref.read(onlineStatusProvider)) {
        await ref.read(purchaseDraftViewModelProvider.notifier).markPending();
        return const PurchaseHeldOffline();
      }

      final purchase = Purchase(
        id: draft.purchaseId,
        date: draft.date,
        storeId: storeId,
        // The label copied when the purchase BEGAN, never read again here:
        // it can be changed in Configurações between typing and saving, and
        // `handoff §8` says what the purchase keeps is the label of the
        // moment of the purchase.
        registeredBy: draft.registeredBy,
        items: draft.items,
      );

      // 3. The list, read at the LAST possible moment — the smaller the
      //    window between reading and writing, the smaller the chance the
      //    other phone touched it in between.
      final listItems = await ref
          .read(shoppingListRepositoryProvider)
          .fetchAll();
      if (!ref.mounted) return null;

      // 4. The write-off rule, pure. Every line of the purchase already
      //    carries its own leaf, so the type of each one is known without
      //    crossing the catalog — a product deactivated on the other phone
      //    between typing and saving still writes the list off, which is the
      //    honest outcome: deactivating a product does not undo a purchase.
      final writeOffs = planWriteOffs(
        purchased: purchase.amounts,
        listItems: listItems,
        purchaseDate: purchase.date,
      );

      // 5. The single write. A `true` means the purchase was already there —
      //    the resend that arrived twice. Not an error, and the draft has to
      //    die all the same.
      await ref.read(purchaseRepositoryProvider).save((
        purchase: purchase,
        writeOffs: writeOffs,
      ));
      if (!ref.mounted) return null;

      // 6. The draft dies HERE, and only here: it is the one guard against
      //    the same purchase being registered twice.
      await ref.read(purchaseDraftViewModelProvider.notifier).clear();
      return const PurchaseSaved();
    } on FutureDate catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return SaveFailed(e.message);
    } on MissingStore catch (e) {
      return SaveFailed(e.message);
    } on EmptyPurchase catch (e) {
      return SaveFailed(e.message);
    } on Object catch (e, st) {
      // A transport failure with the browser saying "online" — a hotel
      // Wi-Fi, a captive portal, a tunnel. It becomes pending too, or "nada
      // se perde" would depend on the browser having noticed the drop.
      if (AppFailure.from(e) is NoConnection) {
        if (!ref.mounted) return null;
        await ref.read(purchaseDraftViewModelProvider.notifier).markPending();
        return const PurchaseHeldOffline();
      }
      return SaveFailed(translateError(e, st, 'salvar a compra'));
    } finally {
      _running = false;
    }
  }
}

/// The window decision C1 orders the picker by. Three CALENDAR months, so
/// "os últimos 3 meses" means what it says on a receipt — `Duration(days: 90)`
/// would drift a day every leap year and two every February.
///
/// A day that does not exist in the target month normalizes forward (31 May
/// minus three months is 3 March), which is fine: this window only orders a
/// list, it decides nothing.
DateTime threeMonthsBefore(DateTime now) =>
    DateTime(now.year, now.month - 3, now.day);

/// Crosses the leaves with the last three months of purchases: how many times
/// each was bought (which ORDERS the picker) and what the last purchase of it
/// paid (which PRE-FILLS the value). Both from one round trip (P4).
///
/// Pure, and public so the ViewModel test can exercise it without a container.
IList<ProductOption> rankOptions(
  IList<ProductOption> options,
  IList<PurchaseHistoryEntry> history,
) {
  final counts = <String, int>{};
  final latest = <String, PurchaseHistoryEntry>{};

  for (final entry in history) {
    counts.update(entry.productId, (n) => n + 1, ifAbsent: () => 1);
    final known = latest[entry.productId];
    // The most RECENT one is the reference. There is no `order` in the query
    // that brought these: ordering an embedded table in PostgREST orders the
    // children, not the parents, so the comparison happens here.
    if (known == null || entry.purchasedOn.isAfter(known.purchasedOn)) {
      latest[entry.productId] = entry;
    }
  }

  return options
      .map((option) {
        final entry = latest[option.id];
        return option.withHistory(
          purchaseCount: counts[option.id] ?? 0,
          lastPurchasedOn: entry?.purchasedOn,
          // Null is the wireframe's "sem base de comparação": a product never
          // bought in the window pre-fills nothing.
          priceReference: entry == null
              ? null
              : PriceReference(
                  paid: entry.paid,
                  quantityInBaseUnit: entry.quantityInBaseUnit,
                  purchasedOn: entry.purchasedOn,
                ),
        );
      })
      .toIList()
      .sort(compareForPicker);
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final newPurchaseViewModelProvider =
    AsyncNotifierProvider<NewPurchaseViewModel, IList<ProductOption>>(
      NewPurchaseViewModel.new,
      retry: (retryCount, error) => null,
    );
