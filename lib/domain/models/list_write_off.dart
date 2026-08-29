/// One line of the trail decision 20 asks for: what a purchase took off the
/// shopping list, and how much of it.
///
/// It is born with H7 and not with H9 for one reason: what a purchase cleared
/// off the list cannot be reconstructed afterwards, so if it is not written at
/// the same moment, it is lost.
final class ListWriteOff {
  const ListWriteOff({
    required this.purchaseItemId,
    required this.shoppingListItemId,
    required this.quantityWrittenOff,
    this.clearedNotFound = false,
    this.fulfills = false,
  });

  /// Which line of the purchase paid for this write-off. It is what lets H9
  /// give back exactly what THAT line took.
  final String purchaseItemId;

  final String shoppingListItemId;

  /// In the smallest unit of the type's base. **Zero is a value here**: an
  /// item that never asked for a quantity has none to consume, and the row
  /// worth zero is what records that this purchase is the one that closed it.
  final int quantityWrittenOff;

  /// Whether this write-off is what cleared a `[!]` — so deleting the
  /// purchase can put the mark back.
  final bool clearedNotFound;

  /// Whether this write-off is what takes the item OFF the list.
  ///
  /// **It is not a column.** It travels inside the same JSON object and
  /// `create_purchase` reads it to fill `fulfilled_on`, then drops it. The
  /// consequence is written down in the migration: H9 does not read "foi esta
  /// baixa que fechou o item" from the trail, it DERIVES it — with the
  /// write-offs of that purchase gone, the item is open again when no
  /// write-off points at it any more, or when the balance turned positive.
  final bool fulfills;

  Map<String, dynamic> toJson() => {
    'purchase_item_id': purchaseItemId,
    'shopping_list_item_id': shoppingListItemId,
    'quantity_written_off': quantityWrittenOff,
    'cleared_not_found': clearedNotFound,
    // Not a column — the flag the function reads and does not store.
    'fulfills': fulfills,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListWriteOff &&
          other.purchaseItemId == purchaseItemId &&
          other.shoppingListItemId == shoppingListItemId &&
          other.quantityWrittenOff == quantityWrittenOff &&
          other.clearedNotFound == clearedNotFound &&
          other.fulfills == fulfills);

  @override
  int get hashCode => Object.hash(
    purchaseItemId,
    shoppingListItemId,
    quantityWrittenOff,
    clearedNotFound,
    fulfills,
  );

  @override
  String toString() =>
      'ListWriteOff($shoppingListItemId, $quantityWrittenOff, '
      'fulfills: $fulfills, clearedNotFound: $clearedNotFound)';
}
