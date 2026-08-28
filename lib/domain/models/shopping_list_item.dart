import 'brand.dart';
import 'calendar_day.dart';
import 'category.dart';
import 'product.dart';
import 'product_type.dart';

/// One line of the shopping list — and an AGGREGATE, not a row of ids.
///
/// It carries the whole [ProductType], the whole [Category] and, when they
/// exist, the whole [Brand] and [Product], because the line on screen needs
/// the type's name, the category's name (that is what groups it), the base
/// unit (that is what the quantity is written in), the brand's name and the
/// packaging's label. The alternative — loading the catalog and crossing it in
/// memory — would mean fetching EVERY product in the database just to find the
/// label of one preferred packaging.
///
/// **`fromJson` reads the PostgREST embed, `toJson` writes only the table's
/// own columns.** The asymmetry is deliberate: it is the real contract of the
/// API underneath.
final class ShoppingListItem {
  factory ShoppingListItem({
    String? id,
    required ProductType type,
    required Category category,
    Brand? preferredBrand,
    Product? preferredProduct,
    int? quantity,
    required DateTime enteredOn,
    bool picked = false,
    bool notFound = false,
  }) {
    // Null is an answer; zero and negative are not.
    if (quantity != null && quantity <= 0) throw const InvalidQuantity();
    return ShoppingListItem._(
      id: id,
      type: type,
      category: category,
      preferredBrand: preferredBrand,
      preferredProduct: preferredProduct,
      quantity: quantity,
      // Rule 9: the day is rounded here, so an instant that carries an hour
      // never breaks the `==` of a line that did not change.
      enteredOn: dayOf(enteredOn),
      picked: picked,
      notFound: notFound,
    );
  }

  const ShoppingListItem._({
    this.id,
    required this.type,
    required this.category,
    this.preferredBrand,
    this.preferredProduct,
    this.quantity,
    required this.enteredOn,
    required this.picked,
    required this.notFound,
  });

  /// Reads the embed of `_selection`: `product_type` comes nested, and the
  /// category comes nested inside it.
  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    final type = json['product_type'] as Map<String, dynamic>;
    final brand = json['preferred_brand'] as Map<String, dynamic>?;
    final product = json['preferred_product'] as Map<String, dynamic>?;

    return ShoppingListItem(
      id: json['id'] as String?,
      type: ProductType.fromJson(type),
      category: Category.fromJson(type['category'] as Map<String, dynamic>),
      preferredBrand: brand == null ? null : Brand.fromJson(brand),
      preferredProduct: product == null ? null : Product.fromJson(product),
      quantity: (json['quantity'] as num?)?.toInt(),
      enteredOn: decodeCalendarDay(json['entered_on'] as String),
      picked: json['picked'] as bool? ?? false,
      notFound: json['not_found'] as bool? ?? false,
    );
  }

  /// Null before the line exists — it is born on the phone in the ViewModel.
  final String? id;

  /// The level that sums; it carries the base unit.
  final ProductType type;

  /// The type's category, always the CURRENT one — it is what groups the list.
  final Category category;

  /// A reminder, and it does NOT command the write-off.
  final Brand? preferredBrand;

  /// The wanted packaging; same thing.
  final Product? preferredProduct;

  /// In the smallest unit of the type's base. **Null is an answer**: an item
  /// with no quantity leaves the list on the first purchase of the type.
  final int? quantity;

  /// The calendar day the item entered the list (decision 25).
  final DateTime enteredOn;

  /// The checkbox.
  final bool picked;

  /// The `[!]`, which only the item dialog can reach.
  final bool notFound;

  /// Only the table's own columns — the embedded entities go back as ids.
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_type_id': type.id,
    'preferred_brand_id': preferredBrand?.id,
    'preferred_product_id': preferredProduct?.id,
    'quantity': quantity,
    'entered_on': encodeCalendarDay(enteredOn),
    'picked': picked,
    'not_found': notFound,
  };

  /// The checkbox flips TWO states and never passes through "não encontrei"
  /// (decision of 26/08/2026): picking something up is the gesture of almost
  /// every purchase and has to survive a distracted tap. Note that [notFound]
  /// is not touched.
  ShoppingListItem togglePicked() => copyWith(picked: !picked);

  /// The `[!]`, which is a deliberate gesture and lives in the dialog.
  ShoppingListItem markedNotFound() => copyWith(notFound: true);

  ShoppingListItem clearedNotFound() => copyWith(notFound: false);

  /// The rule of decision 25, written here even though its caller only
  /// arrives with H7: a purchase only clears an item that entered BEFORE it or
  /// ON THE SAME DAY. Without it, a purchase registered late erases what the
  /// other person has just asked for.
  bool canBeClearedBy(DateTime purchaseDay) =>
      !enteredOn.isAfter(dayOf(purchaseDay));

  /// An item with no quantity leaves on the first purchase of the type; one
  /// with a quantity leaves by balance. H7 decides what to do about it — what
  /// the list needs to know is which of the two this is.
  bool get hasQuantity => quantity != null;

  /// '6 kg', '2,5 L', '3 un' — or null when there is no quantity.
  String? get quantityLabel =>
      quantity == null ? null : type.baseUnit.formatQuantity(quantity!);

  /// What the line writes: 'Leite Italac 1 L', 'Sabão em pó'. Brand and
  /// packaging come in only when they exist, in this order.
  String get label => [
    type.name,
    if (preferredBrand != null) preferredBrand!.name,
    if (preferredProduct?.packaging != null) preferredProduct!.packaging!.label,
  ].join(' ');

  /// `clearBrand`/`clearProduct` exist because `copyWith` cannot tell "keep
  /// what is there" from "set it back to null" — and the item dialog's
  /// "Qualquer uma" is precisely the second one.
  ShoppingListItem copyWith({
    String? id,
    ProductType? type,
    Category? category,
    Brand? preferredBrand,
    Product? preferredProduct,
    int? quantity,
    DateTime? enteredOn,
    bool? picked,
    bool? notFound,
    bool clearBrand = false,
    bool clearProduct = false,
    bool clearQuantity = false,
  }) => ShoppingListItem(
    id: id ?? this.id,
    type: type ?? this.type,
    category: category ?? this.category,
    preferredBrand: clearBrand ? null : preferredBrand ?? this.preferredBrand,
    preferredProduct: clearProduct
        ? null
        : preferredProduct ?? this.preferredProduct,
    quantity: clearQuantity ? null : quantity ?? this.quantity,
    enteredOn: enteredOn ?? this.enteredOn,
    picked: picked ?? this.picked,
    notFound: notFound ?? this.notFound,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingListItem &&
          other.id == id &&
          other.type == type &&
          other.category == category &&
          other.preferredBrand == preferredBrand &&
          other.preferredProduct == preferredProduct &&
          other.quantity == quantity &&
          other.enteredOn == enteredOn &&
          other.picked == picked &&
          other.notFound == notFound);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    category,
    preferredBrand,
    preferredProduct,
    quantity,
    enteredOn,
    picked,
    notFound,
  );

  @override
  String toString() =>
      'ShoppingListItem($label, ${quantityLabel ?? 'sem quantidade'}, '
      'picked: $picked, notFound: $notFound)';
}

/// A quantity that is not a quantity. pt-BR: it is read on screen.
final class InvalidQuantity implements Exception {
  const InvalidQuantity();

  String get message => 'Informe uma quantidade maior que zero.';

  @override
  String toString() => 'InvalidQuantity: $message';
}
