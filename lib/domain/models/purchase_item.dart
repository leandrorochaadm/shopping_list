import 'base_unit.dart';
import 'money.dart';
import 'product_option.dart';
import 'shopping_list_item.dart' show InvalidQuantity;
import 'uuid.dart';

/// One line of a purchase: a leaf, how much of it, and what was paid for that
/// much — the TOTAL paid, never a unit price. The receipt carries the total,
/// and the unit price is a division the reports do.
///
/// **It carries the whole [ProductOption], not just the leaf's id**, and that
/// is what makes H8 possible: a draft recovered from Hive in airplane mode
/// has to draw its lines and let them be re-edited with no network at all.
/// Holding an id would mean looking the product up in a catalog that never
/// loaded — which is precisely the situation the story exists for.
final class PurchaseItem {
  factory PurchaseItem({
    String? id,
    required ProductOption option,
    required int quantity,
    required Money paid,
  }) {
    if (quantity <= 0) throw const InvalidQuantity();
    return PurchaseItem._(
      // Born on the phone, like the purchase's own key: the write-offs point
      // at it, and a resend that arrives twice has to find the same rows.
      id: id ?? newUuidV4(),
      option: option,
      quantity: quantity,
      // Here, and ONLY here, is where "1 fardo de 12 × 350 ml" becomes
      // 4200 ml. Both numbers are persisted (decision 7) because the
      // conversion happens before the write and no report may redo it.
      quantityInBaseUnit: option.toBaseUnit(quantity),
      paid: paid,
    );
  }

  const PurchaseItem._({
    required this.id,
    required this.option,
    required this.quantity,
    required this.quantityInBaseUnit,
    required this.paid,
  });

  /// Reads what the DRAFT stored — the leaf comes whole, see the class doc.
  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
    id: json['id'] as String?,
    option: ProductOption.fromJson(json['product'] as Map<String, dynamic>),
    quantity: (json['quantity'] as num).toInt(),
    paid: Money.fromJson(json['total_paid']),
  );

  final String id;

  final ProductOption option;

  /// What was TYPED: a package count when sold by piece, an amount in the
  /// smallest unit when sold by weight.
  final int quantity;

  /// The same amount in the type's base unit, in its smallest unit.
  final int quantityInBaseUnit;

  /// Cents. The total paid for this line.
  final Money paid;

  String get productId => option.product.id!;

  String get productTypeId => option.type.id!;

  BaseUnit get baseUnit => option.baseUnit;

  /// What the row reads: 'Coca-Cola 12 × 350 ml'.
  String get label => option.label;

  /// The Quantidade column of the row: '1' for a crate, '1,5 kg' for
  /// something weighed — where the bare number would say '1500'.
  String get quantityLabel => option.isSoldByWeight
      ? baseUnit.formatQuantity(quantityInBaseUnit)
      : '$quantity';

  /// ONLY the table's columns — this is what travels inside `p_items` to
  /// `create_purchase`. The `purchase_id` is not here: it is the same for
  /// every item and comes from the purchase itself.
  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'quantity_in_base_unit': quantityInBaseUnit,
    'total_paid': paid.toJson(),
  };

  /// What the Hive draft stores: the columns above plus the whole leaf, so
  /// the line survives a closed app with no network.
  Map<String, dynamic> toDraftJson() => {
    ...toJson(),
    'product': option.toJson(),
  };

  PurchaseItem copyWith({
    ProductOption? option,
    int? quantity,
    Money? paid,
  }) => PurchaseItem(
    // The id SURVIVES the edit: `[ed]` corrects a line, it does not create a
    // second one, and the write-off trail points at this id.
    id: id,
    option: option ?? this.option,
    quantity: quantity ?? this.quantity,
    paid: paid ?? this.paid,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseItem &&
          other.id == id &&
          other.option == option &&
          other.quantity == quantity &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.paid == paid);

  @override
  int get hashCode =>
      Object.hash(id, option, quantity, quantityInBaseUnit, paid);

  @override
  String toString() =>
      'PurchaseItem($label, $quantityLabel, ${paid.cents})';
}
