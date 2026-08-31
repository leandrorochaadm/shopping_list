import 'money.dart';
import 'price_reference.dart';
import 'product_option.dart';
import 'store.dart';

/// **One purchase of one leaf in one store** — the raw material of the
/// Comparação de preço tab, flat, as the `select` returns it.
///
/// It is not the line of the screen: the screen shows the MOST RECENT
/// purchase of each store, and choosing which one that is is
/// `buildComparison`, in the domain. The repository brings every purchase of
/// the window and decides nothing (rule 3).
///
/// It CONTAINS a [PriceReference] instead of repeating its three fields: it is
/// exactly the pair (paid, quantity) plus the day, with `costPerBaseUnit`
/// already written and already tested.
final class PriceQuote {
  const PriceQuote({
    required this.option,
    required this.categoryId,
    required this.categoryName,
    required this.store,
    required this.price,
  });

  /// The leaf with its registration, its type and its brand — the same
  /// `ProductOption` of screen 3, read from the same embed.
  ///
  /// Its **history comes empty** (`purchaseCount` 0, `priceReference` and
  /// `baseline` null): here it is identity and label, not ranking.
  final ProductOption option;

  /// The category, which `ProductType` does not carry by name — and the
  /// picker of this tab groups by it.
  final String categoryId;

  /// pt-BR: read on screen.
  final String categoryName;

  final Store store;

  /// What that purchase paid, for how much content, on what day.
  final PriceReference price;

  String? get productId => option.id;
  String? get productTypeId => option.type.id;
  DateTime get purchasedOn => price.purchasedOn;
  Money get paid => price.paid;

  /// Cents per base unit — per kilo, per litre, per unit. It is what the list
  /// is ordered by, and it is the number the screen writes.
  int get costPerBaseUnit => price.costPerBaseUnit(option.baseUnit);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceQuote &&
          other.option == option &&
          other.categoryId == categoryId &&
          other.categoryName == categoryName &&
          other.store == store &&
          other.price == price);

  @override
  int get hashCode =>
      Object.hash(option, categoryId, categoryName, store, price);

  @override
  String toString() =>
      'PriceQuote(${option.label} @ ${store.name}, $costPerBaseUnit)';
}
