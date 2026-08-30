import 'calendar_day.dart';
import 'money.dart';

/// One line of the purchase history — and it is NOT a [Purchase].
///
/// It carries the store's NAME, which the purchase holds by key, and the
/// total already added up from the items (D9); and it carries no item at all,
/// because a page of twenty purchases is not twenty purchases opened.
///
/// `==` covers all six fields (rule 8): it travels inside the `T` of an
/// AsyncNotifier, and without it the `IList` of the state compares its
/// elements by reference — the history would repaint whole on every
/// `loadMore`, with the scroll jumping back to the top and no error anywhere.
final class PurchaseSummary {
  const PurchaseSummary({
    required this.id,
    required this.purchaseDate,
    required this.storeName,
    required this.registeredBy,
    required this.total,
    required this.itemCount,
  });

  /// Reads the embed of the history query: `store(name)` for the name and
  /// `purchase_item(total_paid)` for the two numbers.
  ///
  /// The sum happens HERE, in Dart, and not in a view (D9): twenty purchases
  /// of up to twenty items are four hundred integers, and a view of sums
  /// would be new structure to save one addition.
  factory PurchaseSummary.fromJson(Map<String, dynamic> json) {
    final items = (json['purchase_item'] as List?) ?? const [];
    var total = 0;
    for (final row in items.cast<Map<String, dynamic>>()) {
      total += (row['total_paid'] as num?)?.toInt() ?? 0;
    }

    // A left join: a purchase whose store was somehow not embedded still has
    // to draw a line, because the alternative is a history that ends at the
    // first odd row.
    final store = json['store'] as Map<String, dynamic>?;

    return PurchaseSummary(
      id: json['id'] as String,
      purchaseDate: decodeCalendarDay(json['purchase_date'] as String),
      storeName: store?['name'] as String? ?? '',
      registeredBy: json['registered_by'] as String? ?? '',
      total: Money(total),
      itemCount: items.length,
    );
  }

  final String id;

  /// The day printed on the receipt (decision 13) — a calendar day.
  final DateTime purchaseDate;

  /// Resolved from the key at read time, never copied at write time: renaming
  /// a store has to hold for the whole history.
  final String storeName;

  /// Who registered it — the Hive label, copied when the purchase began.
  final String registeredBy;

  final Money total;

  final int itemCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseSummary &&
          other.id == id &&
          other.purchaseDate == purchaseDate &&
          other.storeName == storeName &&
          other.registeredBy == registeredBy &&
          other.total == total &&
          other.itemCount == itemCount);

  @override
  int get hashCode => Object.hash(
    id,
    purchaseDate,
    storeName,
    registeredBy,
    total,
    itemCount,
  );

  @override
  String toString() =>
      'PurchaseSummary(${encodeCalendarDay(purchaseDate)}, $storeName, '
      '${total.cents}, $itemCount itens)';
}
