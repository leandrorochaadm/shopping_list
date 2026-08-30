import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'list_write_off.dart';
import 'shopping_list_item.dart';

/// The state one line of the list goes back to when the purchase that touched
/// it is undone. It is what travels in `p_restored` to the SQL (D4).
///
/// A `final class` and not a record: rule 16 makes no exception, and this one
/// travels inside an `IList` a test compares by value — the `==` written by
/// hand is what makes `expect(restored, [RestoredListItem(...)])` mean
/// anything at all.
final class RestoredListItem {
  const RestoredListItem({
    required this.id,
    required this.fulfilledOn,
    required this.notFound,
  });

  final String id;

  /// **Null is an answer**, not an absence: it is what reopens the item. The
  /// [toJson] below sends the key PRESENT with a null value, never omits it —
  /// an omitted key would leave the item closed, and in silence.
  final DateTime? fulfilledOn;

  final bool notFound;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fulfilled_on': fulfilledOn == null ? null : encodeCalendarDay(fulfilledOn!),
    'not_found': notFound,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestoredListItem &&
          other.id == id &&
          other.fulfilledOn == fulfilledOn &&
          other.notFound == notFound);

  @override
  int get hashCode => Object.hash(id, fulfilledOn, notFound);

  @override
  String toString() =>
      'RestoredListItem($id, ${fulfilledOn == null ? 'aberto' : 'fechado'}, '
      'notFound: $notFound)';
}

/// What [undoWriteOffs] produced: the list as it stands again, and the rows
/// the SQL has to write.
///
/// Both are needed, and for different readers. `items` is consumed in memory
/// by `planWriteOffs` right after; `restored` is what crosses the wire.
final class UndoResult {
  const UndoResult({required this.items, required this.restored});

  /// The whole list back in memory, with `writtenOffQuantity` and
  /// `writeOffCount` already DISCOUNTED of this purchase's trail. It is what
  /// `planWriteOffs` receives next, and without the discount a correction of
  /// 6 L to 2 L would compute the balance over a write-off that is about to
  /// stop existing — the item would come back with zero left instead of 4 L.
  final IList<ShoppingListItem> items;

  /// ONLY the items that changed state. Sending the whole list would be
  /// asking Postgres to rewrite identical rows and to overwrite whatever the
  /// other phone touched in between (D4).
  final IList<RestoredListItem> restored;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UndoResult &&
          other.items == items &&
          other.restored == restored);

  @override
  int get hashCode => Object.hash(items, restored);

  @override
  String toString() =>
      'UndoResult(${items.length} itens, ${restored.length} devolvidos)';
}

/// **Undoes what a purchase did to the shopping list**, from the trail that
/// purchase wrote. It is the exact twin of `planWriteOffs` — one file for the
/// way in, one for the way back — and it is pure: no clock, no I/O, no
/// database.
///
/// It does NOT add quantity back: the written-off amount IS the sum of the
/// trail (D5), and the trail dies with the purchase, so deleting it already
/// restores the balance. What this computes are the two columns the write-off
/// touched, and only on the items THIS purchase touched.
///
/// [items] has to arrive with the closed ones inside it — `fetchItemsByIds`
/// over the ids [trail] cites, which is exactly why that method does not
/// filter by open: an item that left the list is the one that needs to come
/// back.
UndoResult undoWriteOffs(
  IList<ShoppingListItem> items,
  IList<ListWriteOff> trail,
) {
  // 1. The trail is grouped by list item. An item the trail does not cite is
  //    NOT touched: "a lista fica como estaria" is not "a lista volta ao
  //    começo".
  final byItem = <String, List<ListWriteOff>>{};
  for (final writeOff in trail) {
    (byItem[writeOff.shoppingListItemId] ??= []).add(writeOff);
  }
  if (byItem.isEmpty) {
    return UndoResult(items: items, restored: const IList.empty());
  }

  final restored = <RestoredListItem>[];
  final updated = <ShoppingListItem>[];

  for (final item in items) {
    final rows = item.id == null ? null : byItem[item.id!];
    if (rows == null) {
      updated.add(item);
      continue;
    }

    // 2. The amount loses the sum of THIS purchase's rows, and the count
    //    loses how many they were. This discount is what stops the re-apply
    //    from being blind.
    var amount = 0;
    var clearedNotFound = false;
    for (final row in rows) {
      amount += row.quantityWrittenOff;
      clearedNotFound = clearedNotFound || row.clearedNotFound;
    }
    final writtenOff = item.writtenOffQuantity - amount;
    final count = item.writeOffCount - rows.length;

    // 4. The "não encontrei" comes back when one of this purchase's rows is
    //    what knocked it down. Two purchases cannot have knocked down the
    //    same mark: the second one read `notFound: false` and never wrote the
    //    flag.
    final notFound = item.notFound || clearedNotFound;

    // 3. The line reopens when it WAS closed and, after the discount, either
    //    no trail row points at it any more OR its balance turned positive
    //    again. Two conditions because they answer for two kinds of item:
    //    the one with no quantity was closed by a row worth ZERO, so the sum
    //    cannot tell and only the count can; the one with a quantity closes
    //    when the sum reaches what was asked, so any deletion drops it below
    //    and it comes back with whatever is left — the "corrigir 6 L para
    //    2 L deixa 4 L" of the acceptance criterion.
    final asked = item.quantity;
    final reopens =
        item.fulfilledOn != null &&
        (count <= 0 || (asked != null && writtenOff < asked));

    final next = item.copyWith(
      writtenOffQuantity: writtenOff < 0 ? 0 : writtenOff,
      writeOffCount: count < 0 ? 0 : count,
      notFound: notFound,
    );
    // 5. `removedOn` is NEVER touched — see [ShoppingListItem.restoredToList],
    //    which is the only transition that reopens a line and which carries
    //    it over. An item this purchase closed and that the person then
    //    removed by hand stays removed (D1).
    updated.add(reopens ? next.restoredToList() : next);

    // 6. Only what CHANGES STATE goes to the SQL.
    if (reopens || notFound != item.notFound) {
      restored.add(
        RestoredListItem(
          id: item.id!,
          fulfilledOn: reopens ? null : item.fulfilledOn,
          notFound: notFound,
        ),
      );
    }
  }

  return UndoResult(items: updated.toIList(), restored: restored.toIList());
}
