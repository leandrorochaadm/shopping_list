import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'money.dart';
import 'purchase_item.dart';
import 'uuid.dart';

/// A registered purchase: a day, a store, who registered it, and the lines.
///
/// The **key is born on the phone**. It is not a whim: without it the resend
/// of H8 that arrives twice would become a second purchase and would write
/// the list off a second time. `create_purchase` closes that with an
/// `on conflict (id) do nothing`, and this is the id it conflicts on.
final class Purchase {
  factory Purchase({
    String? id,
    required DateTime date,
    required String storeId,
    required String registeredBy,
    IList<PurchaseItem> items = const IList.empty(),
  }) => Purchase._(
    id: id ?? newUuidV4(),
    // Rule 9: rounded here, so an instant carrying an hour never breaks the
    // `==` of a purchase that did not change.
    date: dayOf(date),
    storeId: storeId,
    registeredBy: registeredBy,
    items: items,
  );

  const Purchase._({
    required this.id,
    required this.date,
    required this.storeId,
    required this.registeredBy,
    required this.items,
  });

  final String id;

  /// The day printed on the receipt (decision 13) — a calendar day, never an
  /// instant, and never `now()` decided in SQL.
  final DateTime date;

  final String storeId;

  /// The Hive label, COPIED at the moment the purchase began. It is not an
  /// account and there is nothing to reference — see `PurchaseDraft`.
  final String registeredBy;

  final IList<PurchaseItem> items;

  /// A purchase cannot be in the future. The date picker blocks it at the
  /// source, and this is the rule that says so — the screen may never be the
  /// only guard (rule 11).
  static void checkDate(DateTime date, DateTime today) {
    if (dayOf(date).isAfter(dayOf(today))) throw const FutureDate();
  }

  Money get total =>
      items.fold(Money.zero, (sum, item) => sum + item.paid);

  /// What the write-off planner works over: the type, the amount in the base
  /// unit, and which line of the purchase it came from.
  IList<PurchasedAmount> get amounts => [
    for (final item in items)
      PurchasedAmount(
        purchaseItemId: item.id,
        productTypeId: item.productTypeId,
        quantityInBaseUnit: item.quantityInBaseUnit,
      ),
  ].toIList();

  /// Correcting the header and the lines (H9), and it is a TRANSITION on the
  /// entity rather than a `copyWith(storeId: ...)` spread around a ViewModel
  /// (rule 7). The id and [registeredBy] are the two things it cannot touch:
  /// the id is what the trail points at, and who registered a purchase is a
  /// historical fact a correction never rewrites.
  ///
  /// The future-date rule is still [checkDate], asked before this is called —
  /// a transition is not the place for a clock (rule 9).
  Purchase correctedTo({
    DateTime? date,
    String? storeId,
    IList<PurchaseItem>? items,
  }) => Purchase(
    id: id,
    date: date ?? this.date,
    storeId: storeId ?? this.storeId,
    registeredBy: registeredBy,
    items: items ?? this.items,
  );

  /// ONLY the three columns the correction writes. `registered_by` is left
  /// out on purpose — see [correctedTo] — and the items travel apart, in
  /// `p_items`, because `update_purchase` takes them as its second argument.
  Map<String, dynamic> toCorrectionJson() => {
    'id': id,
    'purchase_date': encodeCalendarDay(date),
    'store_id': storeId,
  };

  /// ONLY the four columns of the `purchase` table — the items travel apart,
  /// in `p_items`, because the transactional function takes them as its
  /// second argument. The date leaves through `encodeCalendarDay`, never
  /// through a screen's DateFormat.
  Map<String, dynamic> toJson() => {
    'id': id,
    'purchase_date': encodeCalendarDay(date),
    'store_id': storeId,
    'registered_by': registeredBy,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Purchase &&
          other.id == id &&
          other.date == date &&
          other.storeId == storeId &&
          other.registeredBy == registeredBy &&
          other.items == items);

  @override
  int get hashCode => Object.hash(id, date, storeId, registeredBy, items);

  @override
  String toString() =>
      'Purchase(${encodeCalendarDay(date)}, ${items.length} itens, '
      '${total.cents})';
}

/// How much of a type one line of the purchase brought home. It is what
/// `planWriteOffs` reads: three fields, no rules, no identity — a projection
/// of [Purchase], which is why it is a plain class and not an entity.
final class PurchasedAmount {
  const PurchasedAmount({
    required this.purchaseItemId,
    required this.productTypeId,
    required this.quantityInBaseUnit,
  });

  final String purchaseItemId;
  final String productTypeId;
  final int quantityInBaseUnit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchasedAmount &&
          other.purchaseItemId == purchaseItemId &&
          other.productTypeId == productTypeId &&
          other.quantityInBaseUnit == quantityInBaseUnit;

  @override
  int get hashCode =>
      Object.hash(purchaseItemId, productTypeId, quantityInBaseUnit);
}

/// pt-BR: every message below is read on screen.
final class FutureDate implements Exception {
  const FutureDate();

  String get message => 'A compra não pode ter data futura.';

  @override
  String toString() => 'FutureDate: $message';
}

final class MissingStore implements Exception {
  const MissingStore();

  String get message => 'Escolha o mercado desta compra.';

  @override
  String toString() => 'MissingStore: $message';
}

final class EmptyPurchase implements Exception {
  const EmptyPurchase();

  String get message => 'Acrescente ao menos um item à compra.';

  @override
  String toString() => 'EmptyPurchase: $message';
}
