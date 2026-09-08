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
    int writtenOffQuantity = 0,
    int writeOffCount = 0,
    DateTime? fulfilledOn,
    DateTime? removedOn,
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
      writtenOffQuantity: writtenOffQuantity,
      writeOffCount: writeOffCount,
      fulfilledOn: fulfilledOn == null ? null : dayOf(fulfilledOn),
      removedOn: removedOn == null ? null : dayOf(removedOn),
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
    required this.writtenOffQuantity,
    required this.writeOffCount,
    required this.fulfilledOn,
    required this.removedOn,
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
      // The balance is DERIVED (P5), never a column: H9 undoes a purchase by
      // deleting its write-offs, and a stored `remaining_quantity` would be a
      // second number to recompute — two sources for one figure diverge on
      // the first mistake. Summing dozens of rows in Dart is not a cost;
      // `handoff §7` sizes the whole list in the dozens.
      writtenOffQuantity: _sumWriteOffs(json['list_write_off']),
      // The SIZE of the same embed the line above sums. Two numbers out of
      // one read, because H9 needs both — see [writeOffCount].
      writeOffCount: _countWriteOffs(json['list_write_off']),
      fulfilledOn: _dayOrNull(json['fulfilled_on']),
      removedOn: _dayOrNull(json['removed_on']),
    );
  }

  static DateTime? _dayOrNull(Object? value) =>
      value == null ? null : decodeCalendarDay(value as String);

  static int _countWriteOffs(Object? embed) => embed is List ? embed.length : 0;

  static int _sumWriteOffs(Object? embed) {
    if (embed is! List) return 0;
    var total = 0;
    for (final row in embed.cast<Map<String, dynamic>>()) {
      total += (row['quantity_written_off'] as num?)?.toInt() ?? 0;
    }
    return total;
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

  /// The sum of `list_write_off.quantity_written_off` for this line, read
  /// from the embed. It is what [remainingQuantity] subtracts.
  final int writtenOffQuantity;

  /// How many trail rows point at this line — the SIZE of the embed
  /// [writtenOffQuantity] takes its sum from.
  ///
  /// It exists because of the item with NO quantity: it is closed by a row
  /// worth zero (rule 3a of `planWriteOffs`), so the sum does not move when
  /// that row is deleted and only the COUNT can say the item has to reopen.
  /// That is half of the derivation H9 does instead of reading a `fulfills`
  /// flag that was never stored (D6).
  final int writeOffCount;

  /// The day a PURCHASE closed this line (decision B6). Null is "still on the
  /// list". It is a date and not a DELETE because `list_write_off` has a
  /// foreign key here with no `on delete` — the trail is what H9 undoes, and
  /// a deleted row would take it with it.
  final DateTime? fulfilledOn;

  /// The day someone removed this line BY HAND, from the item dialog. A
  /// different act from being bought, and it needs its own column for the
  /// same reason: an item that already took a partial write-off cannot be
  /// deleted, and H9 has to tell the two apart when it undoes a purchase.
  final DateTime? removedOn;

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
    // Both are columns; `writtenOffQuantity` is not — it is the sum of
    // another table, and writing it back would invent a column.
    'fulfilled_on': fulfilledOn == null
        ? null
        : encodeCalendarDay(fulfilledOn!),
    'removed_on': removedOn == null ? null : encodeCalendarDay(removedOn!),
  };

  /// The checkbox flips TWO states and never passes through "não encontrei"
  /// (decision of 26/08/2026): picking something up is the gesture of almost
  /// every purchase and has to survive a distracted tap. Note that [notFound]
  /// is not touched.
  ShoppingListItem togglePicked() => copyWith(picked: !picked);

  /// The `[!]`, which is a deliberate gesture and lives in the dialog.
  ShoppingListItem markedNotFound() => copyWith(notFound: true);

  ShoppingListItem clearedNotFound() => copyWith(notFound: false);

  /// Removing by hand, and it is a TRANSITION on the entity (rule 7) rather
  /// than a DELETE in a repository. [day] is the phone's today, which enters
  /// the system in the ViewModel and travels as a parameter.
  ShoppingListItem markedRemoved(DateTime day) =>
      copyWith(removedOn: dayOf(day));

  /// A purchase closed this line, on the day printed on the receipt — never
  /// on today's (decision 25).
  ShoppingListItem fulfilledBy(DateTime purchaseDay) =>
      copyWith(fulfilledOn: dayOf(purchaseDay));

  /// The way back: H9 undoing the purchase that had closed it.
  ///
  /// `copyWith` cannot express this — `fulfilledOn ?? this.fulfilledOn` keeps
  /// what is there — so the transition is written against the factory, which
  /// is also why it is a method and not a `copyWith` spread around a
  /// ViewModel (rule 7). **`removedOn` is deliberately carried over**: a line
  /// this purchase closed and that someone then removed by hand stays
  /// removed, and that is the whole reason the two columns are separate (D1).
  ShoppingListItem restoredToList() => ShoppingListItem(
    id: id,
    type: type,
    category: category,
    preferredBrand: preferredBrand,
    preferredProduct: preferredProduct,
    quantity: quantity,
    enteredOn: enteredOn,
    picked: picked,
    notFound: notFound,
    writtenOffQuantity: writtenOffQuantity,
    writeOffCount: writeOffCount,
    removedOn: removedOn,
  );

  /// Still on the list: neither bought nor removed by hand. It is the filter
  /// every read of the list uses, and the partial index in the schema mirrors
  /// it — a query that forgets one half makes a bought item reappear in the
  /// aisle.
  bool get isOpen => fulfilledOn == null && removedOn == null;

  /// The balance — 'restam 4 de 6 L'. Null when the line never asked for a
  /// quantity, and never negative: a purchase bigger than what was asked for
  /// closes the line, it does not owe it anything.
  int? get remainingQuantity {
    final asked = quantity;
    if (asked == null) return null;
    final left = asked - writtenOffQuantity;
    return left < 0 ? 0 : left;
  }

  /// The rule of decision 25, written here even though its caller only
  /// arrives with H7: a purchase only clears an item that entered BEFORE it or
  /// ON THE SAME DAY. Without it, a purchase registered late erases what the
  /// other person has just asked for.
  bool canBeClearedBy(DateTime purchaseDay) =>
      !enteredOn.isAfter(dayOf(purchaseDay));

  /// The preference falls SILENTLY when its catalog row is deactivated
  /// (requirement 16) — on the READ, with no second write to undo, and it
  /// comes back on its own the day the brand is reactivated (D7).
  Brand? get effectivePreferredBrand =>
      preferredBrand?.active == true ? preferredBrand : null;

  /// The same for the packaging, and it looks at the LEAF's own flag only.
  ///
  /// `handoff §H10` also says deactivating a registration takes its leaves
  /// with it, and that half is `Product.isEffectivelyActiveIn` — it needs the
  /// registration, which this line does not carry and has no reason to: the
  /// maintenance screen (H10) is where both are in hand, and there the write
  /// deactivates the leaves along with the registration.
  Product? get effectivePreferredProduct =>
      preferredProduct?.active == true ? preferredProduct : null;

  /// What the line writes once the deactivated preferences have fallen: it is
  /// [label] asked of the EFFECTIVE preferences, so "Leite Italac 1 L"
  /// becomes "Leite" the moment the Italac is deactivated.
  String get effectiveLabel => [
    type.name,
    if (effectivePreferredBrand != null) effectivePreferredBrand!.name,
    if (effectivePreferredProduct?.packaging != null)
      effectivePreferredProduct!.packaging!.label,
  ].join(' ');

  /// An item with no quantity leaves on the first purchase of the type; one
  /// with a quantity leaves by balance. H7 decides what to do about it — what
  /// the list needs to know is which of the two this is.
  bool get hasQuantity => quantity != null;

  /// '6 kg', '2,5 L', '3 un' — or null when there is no quantity.
  String? get quantityLabel =>
      quantity == null ? null : type.baseUnit.formatQuantity(quantity!);

  /// What screen 6 writes UNDER the line: what the list is asking for, and how.
  ///
  /// It is pt-BR in the domain for the same reason `CapThreshold.message` and
  /// `SameDayAlert.messageFor` are: the four cases ARE the rule, and a
  /// compound `if` over three fields of this entity inside a `build()` is the
  /// architecture bug rule 11 names.
  ///
  /// The four shapes of `wireframes §Tela 6`, plus the combination (E-h):
  ///
  ///   * 'na lista: restam 2 de 6 kg' — asked for, partially bought
  ///   * 'na lista: pedindo 6 L'      — asked for, untouched
  ///   * 'na lista, sem quantidade'   — leaves on the first purchase of the
  ///     type
  ///   * '…, "não encontrei"'         — appended to whichever of the three
  ///
  /// The suffix is APPENDED and does not replace: no line of the wireframe has
  /// both at once, so combining contradicts none of them — and losing the
  /// "não encontrei" of an item that also has a quantity would lose the
  /// message the other person left in the aisle.
  String get listStatusLabel {
    final asked = quantity;
    final base = asked == null
        ? 'na lista, sem quantidade'
        : writtenOffQuantity > 0
        ? 'na lista: restam '
              '${type.baseUnit.formatQuantityPair(remainingQuantity!, asked)}'
        : 'na lista: pedindo ${type.baseUnit.formatQuantity(asked)}';
    return notFound ? '$base, "não encontrei"' : base;
  }

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
    int? writtenOffQuantity,
    int? writeOffCount,
    DateTime? fulfilledOn,
    DateTime? removedOn,
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
    writtenOffQuantity: writtenOffQuantity ?? this.writtenOffQuantity,
    writeOffCount: writeOffCount ?? this.writeOffCount,
    fulfilledOn: fulfilledOn ?? this.fulfilledOn,
    removedOn: removedOn ?? this.removedOn,
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
          other.notFound == notFound &&
          other.writtenOffQuantity == writtenOffQuantity &&
          other.writeOffCount == writeOffCount &&
          other.fulfilledOn == fulfilledOn &&
          other.removedOn == removedOn);

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
    writtenOffQuantity,
    writeOffCount,
    fulfilledOn,
    removedOn,
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
