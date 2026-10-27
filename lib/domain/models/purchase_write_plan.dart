import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'list_write_off.dart';
import 'purchase.dart';
import 'spending_cap.dart';
import 'write_off_undo.dart';

/// What happens to `fulfilled_on` of one line of the list.
///
/// A `sealed` class because "do not touch" and "go back to empty" are
/// different answers: the old SQL told them apart by the PRESENCE of the key.
sealed class FulfillmentChange {
  const FulfillmentChange();
}

/// `fulfilled_on` does not change (the field is omitted from the update).
final class KeepFulfillment extends FulfillmentChange {
  const KeepFulfillment();

  @override
  bool operator ==(Object other) => other is KeepFulfillment;

  @override
  int get hashCode => (KeepFulfillment).hashCode;

  @override
  String toString() => 'KeepFulfillment';
}

/// `fulfilled_on` goes back to empty: the item is open again.
final class ReopenItem extends FulfillmentChange {
  const ReopenItem();

  @override
  bool operator ==(Object other) => other is ReopenItem;

  @override
  int get hashCode => (ReopenItem).hashCode;

  @override
  String toString() => 'ReopenItem';
}

/// `fulfilled_on` is set to a calendar day.
final class SetFulfilled extends FulfillmentChange {
  // Rule 9: rounded here, so an instant with an hour never breaks the `==`.
  factory SetFulfilled(DateTime on) => SetFulfilled._(dayOf(on));

  const SetFulfilled._(this.on);

  final DateTime on;

  @override
  bool operator ==(Object other) => other is SetFulfilled && other.on == on;

  @override
  int get hashCode => Object.hash(SetFulfilled, on);

  @override
  String toString() => 'SetFulfilled(${encodeCalendarDay(on)})';
}

/// The final state of one line of the shopping list after a purchase write.
final class ListItemChange {
  const ListItemChange({
    required this.shoppingListItemId,
    required this.fulfillment,
    this.notFound,
  });

  final String shoppingListItemId;
  final FulfillmentChange fulfillment;

  /// Null means "do not touch `not_found`".
  final bool? notFound;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListItemChange &&
          other.shoppingListItemId == shoppingListItemId &&
          other.fulfillment == fulfillment &&
          other.notFound == notFound);

  @override
  int get hashCode => Object.hash(shoppingListItemId, fulfillment, notFound);

  @override
  String toString() =>
      'ListItemChange($shoppingListItemId, $fulfillment'
      '${notFound == null ? '' : ', notFound: $notFound'})';
}

/// One operation of the batch, in the order the repository must follow:
/// parent before child, and the reverse on deletion.
enum PurchaseWriteStep {
  createPurchase,
  updatePurchase,
  deleteWriteOffs,
  deleteItems,
  createItems,
  createWriteOffs,
  updateListItems,
  deletePurchase,
  writeCapAlerts,
}

/// What `create_purchase`, `update_purchase` and `delete_purchase` used to
/// decide inside Postgres, computed in Dart. The repository only walks
/// [steps] and translates each one; it decides nothing.
final class PurchaseWritePlan {
  const PurchaseWritePlan._({
    required this.purchase,
    required this.writeOffs,
    required this.listChanges,
    required this.capAlerts,
    required this.deletedPurchaseId,
    required this.steps,
  });

  factory PurchaseWritePlan.forCreate({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<CapAlerts> capAlerts,
  }) => PurchaseWritePlan._(
    purchase: purchase,
    writeOffs: writeOffs,
    listChanges: _changesFromWriteOffs(
      writeOffs,
      purchase.date,
    ).values.map(_Draft.build).toIList(),
    capAlerts: capAlerts,
    deletedPurchaseId: null,
    steps: const [
      PurchaseWriteStep.createPurchase,
      PurchaseWriteStep.createItems,
      PurchaseWriteStep.createWriteOffs,
      PurchaseWriteStep.updateListItems,
      PurchaseWriteStep.writeCapAlerts,
    ].lock,
  );

  factory PurchaseWritePlan.forCorrection({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
    required IList<CapAlerts> capAlerts,
  }) {
    final drafts = _restoredDrafts(restored);
    final fresh = _changesFromWriteOffs(writeOffs, purchase.date);
    for (final entry in fresh.entries) {
      final base = drafts[entry.key];
      if (base == null) {
        drafts[entry.key] = entry.value;
        continue;
      }
      // Step 5 then step 6 of the old SQL: the new write-off wins.
      if (entry.value.notFound != null) base.notFound = entry.value.notFound;
      if (entry.value.fulfillment is SetFulfilled) {
        base.fulfillment = entry.value.fulfillment;
      }
    }
    return PurchaseWritePlan._(
      purchase: purchase,
      writeOffs: writeOffs,
      listChanges: drafts.values.map(_Draft.build).toIList(),
      capAlerts: capAlerts,
      deletedPurchaseId: null,
      steps: const [
        PurchaseWriteStep.updatePurchase,
        PurchaseWriteStep.deleteWriteOffs,
        PurchaseWriteStep.deleteItems,
        PurchaseWriteStep.createItems,
        PurchaseWriteStep.createWriteOffs,
        PurchaseWriteStep.updateListItems,
        PurchaseWriteStep.writeCapAlerts,
      ].lock,
    );
  }

  factory PurchaseWritePlan.forDeletion({
    required String purchaseId,
    required IList<RestoredListItem> restored,
    required IList<CapAlerts> capAlerts,
  }) => PurchaseWritePlan._(
    purchase: null,
    writeOffs: const IList.empty(),
    listChanges: _restoredDrafts(restored).values.map(_Draft.build).toIList(),
    capAlerts: capAlerts,
    deletedPurchaseId: purchaseId,
    steps: const [
      PurchaseWriteStep.updateListItems,
      PurchaseWriteStep.deleteWriteOffs,
      PurchaseWriteStep.deleteItems,
      PurchaseWriteStep.deletePurchase,
      PurchaseWriteStep.writeCapAlerts,
    ].lock,
  );

  /// Null only on deletion.
  final Purchase? purchase;

  /// Empty on deletion.
  final IList<ListWriteOff> writeOffs;

  /// One per list line, already with the final state.
  final IList<ListItemChange> listChanges;

  final IList<CapAlerts> capAlerts;

  /// Only on deletion.
  final String? deletedPurchaseId;

  final IList<PurchaseWriteStep> steps;

  String get purchaseId => purchase?.id ?? deletedPurchaseId!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseWritePlan &&
          other.purchase == purchase &&
          other.writeOffs == writeOffs &&
          other.listChanges == listChanges &&
          other.capAlerts == capAlerts &&
          other.deletedPurchaseId == deletedPurchaseId &&
          other.steps == steps);

  @override
  int get hashCode => Object.hash(
    purchase,
    writeOffs,
    listChanges,
    capAlerts,
    deletedPurchaseId,
    steps,
  );

  @override
  String toString() =>
      'PurchaseWritePlan($purchaseId, ${listChanges.length} mudanças na lista)';
}

/// A mutable accumulator, private to this file, so the merge of the old SQL
/// steps stays one line per rule.
final class _Draft {
  _Draft(this.id, this.fulfillment, this.notFound);

  final String id;
  FulfillmentChange fulfillment;
  bool? notFound;

  static ListItemChange build(_Draft d) => ListItemChange(
    shoppingListItemId: d.id,
    fulfillment: d.fulfillment,
    notFound: d.notFound,
  );
}

/// The `create_purchase` rule: one entry per list line with at least one
/// write-off that clears `not_found` or fulfills, in order of first
/// appearance.
Map<String, _Draft> _changesFromWriteOffs(
  IList<ListWriteOff> writeOffs,
  DateTime day,
) {
  final drafts = <String, _Draft>{};
  for (final w in writeOffs) {
    if (!w.clearedNotFound && !w.fulfills) continue;
    final draft = drafts.putIfAbsent(
      w.shoppingListItemId,
      () => _Draft(w.shoppingListItemId, const KeepFulfillment(), null),
    );
    if (w.fulfills) draft.fulfillment = SetFulfilled(day);
    if (w.clearedNotFound) draft.notFound = false;
  }
  return drafts;
}

/// Step 2 of `update_purchase` and the whole of `delete_purchase`.
Map<String, _Draft> _restoredDrafts(IList<RestoredListItem> restored) {
  final drafts = <String, _Draft>{};
  for (final r in restored) {
    if (drafts.containsKey(r.id)) {
      throw ArgumentError.value(r.id, 'restored', 'list item restored twice');
    }
    final on = r.fulfilledOn;
    drafts[r.id] = _Draft(
      r.id,
      on == null ? const ReopenItem() : SetFulfilled(on),
      r.notFound,
    );
  }
  return drafts;
}
