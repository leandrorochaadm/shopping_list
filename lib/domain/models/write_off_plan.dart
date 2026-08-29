import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'list_write_off.dart';
import 'purchase.dart' show PurchasedAmount;
import 'shopping_list_item.dart';

/// How much of ONE line of the purchase is still unspent, as [planWriteOffs]
/// consumes the lines of a type in the order they were typed.
///
/// It lives and dies inside that function — but rule 16 says "no records
/// anywhere in the project", and a named type is also what keeps
/// `available[cursor].id` readable at the call site.
final class AvailableAmount {
  const AvailableAmount({required this.id, required this.left});

  /// The purchase item this amount came from — the id H9 gives back to.
  final String id;

  /// What is left of it, in the base unit.
  final int left;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailableAmount && other.id == id && other.left == left;

  @override
  int get hashCode => Object.hash(id, left);
}

/// **What the purchase does to the shopping list.** Every acceptance
/// criterion of the write-off lives in this one function, and it is pure: no
/// system clock, no I/O, no database. The SQL that follows it only inserts
/// what it decided.
///
/// [purchased] are the lines of the purchase reduced to type and amount;
/// [listItems] is the list as it was read a moment before the write; and
/// [purchaseDate] is the day on the receipt, which is what decision 25
/// compares against — never today.
IList<ListWriteOff> planWriteOffs({
  required IList<PurchasedAmount> purchased,
  required IList<ShoppingListItem> listItems,
  required DateTime purchaseDate,
}) {
  // 1. A purchase only touches lines that are still on the list AND entered
  //    before it, or on the same day (decision 25). Without the second half a
  //    purchase registered late erases what the other person just asked for.
  final eligible = listItems
      .where((item) => item.isOpen && item.canBeClearedBy(purchaseDate))
      .toList();
  if (eligible.isEmpty || purchased.isEmpty) return const IList.empty();

  // 2. The write-off happens at the level of the TYPE — brand and packaging
  //    are preferences and filter nothing. Buying Piracanjuba clears the line
  //    that asked for Italac.
  final amountsByType = <String, List<PurchasedAmount>>{};
  for (final amount in purchased) {
    (amountsByType[amount.productTypeId] ??= []).add(amount);
  }

  final plan = <ListWriteOff>[];

  for (final entry in amountsByType.entries) {
    final items = eligible.where((item) => item.type.id == entry.key).toList()
      // Oldest first, and the id breaks the tie so the outcome of the same
      // purchase never depends on the order the rows came back in.
      ..sort((a, b) {
        final byDay = a.enteredOn.compareTo(b.enteredOn);
        return byDay != 0 ? byDay : (a.id ?? '').compareTo(b.id ?? '');
      });
    if (items.isEmpty) continue;

    // The amount this purchase brought home for this type, line by line, in
    // the order the lines were typed. Consuming them in order is what lets H9
    // give back exactly what each line took.
    final available = [
      for (final amount in entry.value)
        AvailableAmount(
          id: amount.purchaseItemId,
          left: amount.quantityInBaseUnit,
        ),
    ];
    var cursor = 0;
    var leftOnCursor = available.isEmpty ? 0 : available.first.left;

    // The line that gets a zero write-off: the first of this type, so the
    // row H9 undoes belongs to a purchase item that really exists.
    final firstItemId = available.first.id;

    for (final item in items) {
      final remaining = item.remainingQuantity;

      // 3a. An item with NO quantity does not compete for the amount. It
      //     never asked for one, so there is nothing to consume: it takes a
      //     row worth zero and is closed by it — "item sem quantidade sai na
      //     primeira compra daquele tipo".
      //
      //     Giving it "all the amount available" instead would inflate the
      //     trail and steal from the quantified lines of the same type; giving
      //     it no row at all would leave it on the list forever, because
      //     `fulfilled_on` is set from the write-offs.
      if (remaining == null || remaining == 0) {
        plan.add(
          ListWriteOff(
            purchaseItemId: firstItemId,
            shoppingListItemId: item.id!,
            quantityWrittenOff: 0,
            clearedNotFound: item.notFound,
            fulfills: true,
          ),
        );
        continue;
      }

      // 3b. An item WITH a quantity consumes the purchase, line by line.
      var wanted = remaining;
      var applied = 0;

      while (wanted > 0 && cursor < available.length) {
        if (leftOnCursor == 0) {
          cursor++;
          if (cursor == available.length) break;
          leftOnCursor = available[cursor].left;
          continue;
        }

        final taken = wanted < leftOnCursor ? wanted : leftOnCursor;
        plan.add(
          ListWriteOff(
            purchaseItemId: available[cursor].id,
            shoppingListItemId: item.id!,
            quantityWrittenOff: taken,
            // "Não encontrei" falls on the first purchase of the type, even a
            // partial one — so it is set on every row, not only on the
            // closing one.
            clearedNotFound: item.notFound,
            // A partial purchase writes off and does NOT close the line.
            fulfills: applied + taken == remaining,
          ),
        );
        applied += taken;
        wanted -= taken;
        leftOnCursor -= taken;
      }

      // 4/5. When nothing was left for this line, the loop above wrote no
      //      row about it at all — which is exactly why it "continua na
      //      lista", and why an item marked as picked whose type nobody
      //      bought is never mentioned in the plan.
    }
  }

  return plan.toIList();
}
