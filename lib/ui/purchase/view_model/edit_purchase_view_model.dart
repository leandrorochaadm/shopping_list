import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/purchase/purchase_repository.dart';
import '../../../data/repositories/shopping_list/shopping_list_repository.dart';
import '../../../data/repositories/spending_cap/spending_cap_repository.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/write_off_plan.dart';
import '../../../domain/models/write_off_undo.dart';
import '../../core/error_translation.dart';
import '../../settings/view_model/spending_cap_view_model.dart';

/// What the correction screen has in hand: the purchase with its items and
/// its trail, and the list items that trail cites — the two sides of the undo.
///
/// A `final class` with `==`/`hashCode`, and not the inline record the first
/// draft of this screen had (rule 16). It is the `T` of an AsyncNotifier, and
/// the chain below it is already complete: `PurchaseDetail`, `IList` and
/// `ShoppingListItem` all compare by value.
final class EditPurchaseState {
  const EditPurchaseState({required this.detail, required this.listItems});

  final PurchaseDetail detail;
  final IList<ShoppingListItem> listItems;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditPurchaseState &&
          other.detail == detail &&
          other.listItems == listItems);

  @override
  int get hashCode => Object.hash(detail, listItems);
}

/// How a correction — or a deletion — ended.
///
/// `save` and `delete` were `Future<String?>` while a correction had exactly
/// two outcomes carrying nothing. H13 gives the success a payload — the cap
/// alert it may have fired — and **the number of outcomes is what picks the
/// form** (rule 16), not taste.
sealed class CorrectionOutcome {
  const CorrectionOutcome();
}

final class CorrectionSaved extends CorrectionOutcome {
  const CorrectionSaved(this.capAlert);

  /// The cut this correction crossed in the month of the CORRECTED purchase,
  /// or null. The month it may have LEFT can only have been rearmed, and a
  /// rearm is not a warning: it does not speak.
  final CapThreshold? capAlert;
}

final class CorrectionFailed extends CorrectionOutcome {
  const CorrectionFailed(this.message);

  /// pt-BR, already translated — the raw exception never reaches a screen.
  final String message;
}

/// Screen `/purchases/:id/edit` — correcting and deleting one purchase, which
/// is the story that makes a typo reversible.
///
/// A `family`: the argument arrives through the CONSTRUCTOR (Riverpod 3 — no
/// `FamilyAsyncNotifier` exists) and `build()` stays parameterless.
final class EditPurchaseViewModel extends AsyncNotifier<EditPurchaseState> {
  EditPurchaseViewModel(this.purchaseId);

  final String purchaseId;

  bool _running = false;

  @override
  Future<EditPurchaseState> build() async {
    // The two reads are SEQUENTIAL and cannot be parallelised: the ids the
    // second one asks for come out of the trail the first one brings.
    //
    // Both repositories are read BEFORE the first await — they are stateless
    // `Provider`s, reading them together costs nothing, and it is what leaves
    // this method with no use of `ref` after a suspension. `read` and not
    // `watch` for the same reason: registering a dependency after the first
    // `await` of a `build()` is not something Riverpod guarantees, and there
    // is nothing here worth watching. A purchase the other phone changed
    // arrives through `refresh()`, not through provider invalidation.
    final purchases = ref.read(purchaseRepositoryProvider);
    final lists = ref.read(shoppingListRepositoryProvider);

    final detail = await purchases.fetchDetail(purchaseId);
    // A purchase that wrote nothing off — someone bought what nobody had
    // asked for — sends an empty set, and the repository answers with an
    // empty list WITHOUT going to the database.
    final listItems = await lists.fetchItemsByIds(
      detail.trail.map((writeOff) => writeOff.shoppingListItemId).toSet(),
    );

    return EditPurchaseState(detail: detail, listItems: listItems);
  }

  /// Reloads the purchase. Returns null on success, or the sentence for the
  /// SnackBar.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      state = const AsyncLoading<EditPurchaseState>();

      final next = await build();
      if (!ref.mounted) return null;

      state = AsyncData(next);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'abrir a compra');
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<EditPurchaseState>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// Saves the correction.
  ///
  /// Returns `null` when the reentrancy guard barred a second tap — that null
  /// is "não fiz nada", never a third branch (rule 16).
  ///
  /// **Two outcomes, and since H13 the success carries a payload** — which is
  /// what makes this a sealed type and not the `Future<String?>` it was until
  /// delivery 5. A correction that pushes the month across a cut has a
  /// sentence to show, and a `String?` would force the screen to guess from
  /// the text whether it had failed.
  ///
  /// The order is D2's, and it cannot change:
  ///   1. undo the OLD purchase's effect on the list (`undoWriteOffs`), which
  ///      also hands back the list in memory with its balance restored;
  ///   2. apply the CORRECTED purchase over that state (`planWriteOffs`) —
  ///      and this is where the new date goes through the late-purchase rule
  ///      again, which is what stops the re-apply from being a blind replay;
  ///   3. tell the channel the echo is ours;
  ///   4. send both results in ONE transaction.
  Future<CorrectionOutcome?> save({
    required DateTime purchaseDate,
    required String storeId,
    required IList<PurchaseItem> items,
    DateTime? today,
  }) async {
    if (_running) return null;
    final current = state.value;
    // A FAILURE and not the guard: the null is reserved for `if (_running)`,
    // which is the one case where nothing at all happened.
    if (current == null) {
      return const CorrectionFailed('Aguarde a compra carregar.');
    }

    _running = true;
    try {
      // The clock enters the system HERE (rule 9), rounded to the day.
      final now = dayOf(today ?? DateTime.now());
      Purchase.checkDate(purchaseDate, now);
      if (items.isEmpty) throw const EmptyPurchase();

      // 1. The undo, over the trail as it was WRITTEN — never over what is on
      //    screen. It is what makes running the same correction twice end in
      //    the same state.
      final undone = undoWriteOffs(current.listItems, current.detail.trail);

      final corrected = current.detail.purchase.correctedTo(
        date: purchaseDate,
        storeId: storeId,
        items: items,
      );

      // 2. And the re-apply, over the restored list.
      final writeOffs = planWriteOffs(
        purchased: corrected.amounts,
        listItems: undone.items,
        purchaseDate: corrected.date,
      );

      // 3. BEFORE the RPC: Realtime broadcasts on commit and the HTTP
      //    response comes back after that same commit, so the echo can win.
      //
      //    All three blocks `update_purchase` touches, and WITH repetition:
      //    `restored` covers the items the undo reopened, and the write-offs
      //    cover the ones the corrected purchase closes or un-marks. An id in
      //    both takes two UPDATEs in one transaction, so it takes two echoes
      //    — a `Set` here would bring the wrong banner back in silence, in
      //    the most common correction of all: changing only the amount paid,
      //    where `restored` comes out empty.
      ref
          .read(shoppingListRepositoryProvider)
          .expectEcho(_echoIds(undone.restored, writeOffs));

      // 4. The cap of every month this correction touches — ONE when the
      //    date stayed inside its month, TWO when it crossed the turn of one.
      //    The month it LEFT loses this purchase and may rearm; the month it
      //    arrived in gains it and may cross a cut.
      final previous = current.detail.purchase;
      final months = <DateTime, ReportPeriod>{
        firstDayOfMonth(previous.date): ReportPeriod.monthOf(previous.date),
        firstDayOfMonth(corrected.date): ReportPeriod.monthOf(corrected.date),
      };
      final statuses = await ref
          .read(spendingCapRepositoryProvider)
          .fetchStatuses(months.values.toIList());
      if (!ref.mounted) return null;

      final evaluations = <DateTime, SpendingCapEvaluation>{};
      for (final status in statuses) {
        // Matched by MONTH and never by index: `cap_states` answers ordered by
        // month, not in the order asked.
        final after =
            status.spent -
            (status.month == firstDayOfMonth(previous.date)
                ? previous.total
                : Money.zero) +
            (status.month == firstDayOfMonth(corrected.date)
                ? corrected.total
                : Money.zero);
        evaluations[status.month] = evaluateSpendingCap(
          cap: status.cap,
          month: status.month,
          spent: after,
          current: status.alerts,
        );
      }

      // 5. One transaction — the purchase, the list and the marks together.
      await ref
          .read(purchaseRepositoryProvider)
          .correct(
            purchase: corrected,
            writeOffs: writeOffs,
            restored: undone.restored,
            capAlerts: [
              for (final evaluation in evaluations.values)
                if (evaluation.alerts != null) evaluation.alerts!,
            ].lock,
          );
      if (!ref.mounted) return null;

      // 6. `/settings` and screen 5 are stale by exactly this correction.
      ref.invalidate(spendingCapViewModelProvider);

      // Only the month the purchase now belongs to has anything to say: the
      // one it left can only have been rearmed, and a rearm is silent.
      return CorrectionSaved(
        evaluations[firstDayOfMonth(corrected.date)]?.headline,
      );
    } on FutureDate catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return CorrectionFailed(e.message);
    } on EmptyPurchase catch (e) {
      return CorrectionFailed(e.message);
    } on Object catch (e, st) {
      return CorrectionFailed(translateError(e, st, 'salvar a correção'));
    } finally {
      _running = false;
    }
  }

  /// Deletes the purchase and gives the list back what it had taken — the
  /// same undo, without the re-applying. The confirmation belongs to the
  /// View; this asks nothing.
  Future<CorrectionOutcome?> delete() async {
    if (_running) return null;
    final current = state.value;
    if (current == null) {
      return const CorrectionFailed('Aguarde a compra carregar.');
    }

    _running = true;
    try {
      final undone = undoWriteOffs(current.listItems, current.detail.trail);
      final purchase = current.detail.purchase;

      // Only one block to expect here: `delete_purchase` has no new
      // write-offs to write.
      ref
          .read(shoppingListRepositoryProvider)
          .expectEcho([for (final entry in undone.restored) entry.id]);

      // Deleting only ever DROPS the month, so what this produces is the
      // rearm — the cut that stops being crossed becomes available again.
      final month = ReportPeriod.monthOf(purchase.date);
      final statuses = await ref
          .read(spendingCapRepositoryProvider)
          .fetchStatuses([month].lock);
      if (!ref.mounted) return null;

      final status = statuses.first;
      final evaluation = evaluateSpendingCap(
        cap: status.cap,
        month: status.month,
        spent: status.spent - purchase.total,
        current: status.alerts,
      );

      await ref
          .read(purchaseRepositoryProvider)
          .delete(
            purchaseId: purchaseId,
            restored: undone.restored,
            capAlerts: evaluation.alerts == null
                ? const IList<CapAlerts>.empty()
                : [evaluation.alerts!].lock,
          );
      if (!ref.mounted) return null;

      ref.invalidate(spendingCapViewModelProvider);

      // A deletion has nothing to announce: whatever it crossed, it crossed
      // downwards, and the mark for it was already there.
      return const CorrectionSaved(null);
    } on Object catch (e, st) {
      return CorrectionFailed(translateError(e, st, 'apagar a compra'));
    } finally {
      _running = false;
    }
  }

  /// Every id `update_purchase` writes, counted with repetition — see the
  /// comment at step 3 of [save].
  static List<String> _echoIds(
    IList<RestoredListItem> restored,
    IList<ListWriteOff> writeOffs,
  ) => [
    for (final entry in restored) entry.id,
    for (final writeOff in writeOffs)
      if (writeOff.clearedNotFound || writeOff.fulfills)
        writeOff.shoppingListItemId,
  ];
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final editPurchaseViewModelProvider =
    AsyncNotifierProvider.family<
      EditPurchaseViewModel,
      EditPurchaseState,
      String
    >(EditPurchaseViewModel.new, retry: (retryCount, error) => null);
