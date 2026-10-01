import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'list_write_off.dart';
import 'purchase.dart' show PurchasedAmount;
import 'shopping_list_item.dart';

/// How much of ONE line of the purchase is still unspent, and of which
/// registration, as [planWriteOffs] consumes the lines of a type in the order
/// they were typed.
///
/// It lives and dies inside that function — but rule 16 says "no records
/// anywhere in the project", and a named type is also what keeps
/// `available[index].id` readable at the call site.
final class AvailableAmount {
  const AvailableAmount({
    required this.id,
    required this.registrationId,
    required this.left,
  });

  /// The purchase item this amount came from — the id H9 gives back to.
  final String id;

  /// The registration that line bought. A list line that asks for one only
  /// consumes from the amounts that carry it (decision M-a).
  final String registrationId;

  /// What the line brought, in the base unit. The function keeps what is
  /// still unspent in a list beside it, because two passes consume it.
  final int left;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailableAmount &&
          other.id == id &&
          other.registrationId == registrationId &&
          other.left == left;

  @override
  int get hashCode => Object.hash(id, registrationId, left);
}

/// **What the purchase does to the shopping list.** Every acceptance
/// criterion of the write-off lives in this one function, and it is pure: no
/// system clock, no I/O, no database. The SQL that follows it only inserts
/// what it decided.
///
/// [purchased] are the lines of the purchase reduced to type, registration
/// and amount; [listItems] is the list as it was read a moment before the
/// write; and [purchaseDate] is the day on the receipt, which is what
/// decision 25 compares against — never today.
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

  // 2. The write-off happens at the level of the TYPE, narrowed by the
  //    registration only for a line that asks for one (decision M-a). A line
  //    with no registration is cleared by any purchase of its type.
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
          registrationId: amount.productRegistrationId,
          left: amount.quantityInBaseUnit,
        ),
    ];
    // What is still unspent of each line above. Not a single cursor any
    // more: the first pass takes slices of some lines and the second pass
    // takes what it left, from any of them.
    final left = [for (final amount in available) amount.left];

    // 3. The lines that ask for a registration go FIRST, whatever their age.
    //    Bought 6 L of Italac with "Leite Italac 6 L" and an older "Leite 2 L"
    //    on the list: if the generic line ate first, the Italac one would be
    //    left owing 4 L although exactly what it asked for came home.
    final specific = items.where(
      (item) => item.effectivePreferredRegistration != null,
    );
    final generic = items.where(
      (item) => item.effectivePreferredRegistration == null,
    );

    for (final item in [...specific, ...generic]) {
      _writeOff(item, available, left, plan);
    }
  }

  return plan.toIList();
}

/// What ONE line of the list takes from the amounts of its type. It only
/// looks at the amounts the line accepts — the question is the entity's
/// (rule 11), and a line with no registration accepts them all.
void _writeOff(
  ShoppingListItem item,
  List<AvailableAmount> available,
  List<int> left,
  List<ListWriteOff> plan,
) {
  final remaining = item.remainingQuantity;

  // 3a. An item with NO quantity does not compete for the amount. It never
  //     asked for one, so there is nothing to consume: it takes a row worth
  //     zero and is closed by it — "item sem quantidade sai na primeira
  //     compra" que ele aceita.
  //
  //     The row points at the first line of the purchase the item ACCEPTS, so
  //     the row H9 undoes belongs to a purchase item that really exists and
  //     really bought what the line asked for. No such line: no row, and the
  //     item stays on the list.
  //
  //     Giving it "all the amount available" instead would inflate the trail
  //     and steal from the quantified lines of the same type; giving it no row
  //     at all would leave it on the list forever, because `fulfilled_on` is
  //     set from the write-offs.
  if (remaining == null || remaining == 0) {
    for (final amount in available) {
      if (!item.acceptsRegistration(amount.registrationId)) continue;
      plan.add(
        ListWriteOff(
          purchaseItemId: amount.id,
          shoppingListItemId: item.id!,
          quantityWrittenOff: 0,
          clearedNotFound: item.notFound,
          fulfills: true,
        ),
      );
      return;
    }
    return;
  }

  // 3b. An item WITH a quantity consumes the purchase, line by line.
  var wanted = remaining;
  var applied = 0;

  for (var index = 0; index < available.length && wanted > 0; index++) {
    if (left[index] == 0) continue;
    if (!item.acceptsRegistration(available[index].registrationId)) continue;

    final taken = wanted < left[index] ? wanted : left[index];
    plan.add(
      ListWriteOff(
        purchaseItemId: available[index].id,
        shoppingListItemId: item.id!,
        quantityWrittenOff: taken,
        // "Não encontrei" falls on the first purchase the line accepts, even
        // a partial one — so it is set on every row, not only on the closing
        // one.
        clearedNotFound: item.notFound,
        // A partial purchase writes off and does NOT close the line.
        fulfills: applied + taken == remaining,
      ),
    );
    applied += taken;
    wanted -= taken;
    left[index] -= taken;
  }

  // 4/5. When nothing was left for this line, the loop above wrote no row
  //      about it at all — which is exactly why it "continua na lista", and
  //      why an item marked as picked whose type nobody bought is never
  //      mentioned in the plan.
}
