import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'name_normalization.dart';
import 'price_quote.dart';
import 'product_option.dart';
import 'store.dart';

/// The two views of the tab, and the difference between them is a different
/// question.
///
/// [thisProduct] is what requirement 6 asks for: brand with brand, packaging
/// with packaging — the 500 g Omo of one store against the 500 g Omo of the
/// other. [wholeType] ignores both and answers only "where does the kilo of
/// washing powder come out cheaper" — it is that one, and only it, that puts
/// the 500 g pack beside the 2,3 kg one and the crate beside the single can.
///
/// **[thisProduct] is always the leaf, the leaf with NO brand included** —
/// decision D-v. In H15 the absence of a brand takes the comparison up to the
/// type, and there it is the only way out: the alert is a single line, and the
/// user has nowhere to go. Here they do — [wholeType] is one tap away, it is
/// what the wireframe draws, and the answer "where is the kilo cheaper" is
/// its. Climbing on its own would make the two views return the SAME result
/// for every leaf with no brand, which is half of the couple's catalog, and
/// leave a button that does nothing.
enum ComparisonScope {
  thisProduct,
  wholeType;

  /// pt-BR: it is the label of the selector.
  String get label => switch (this) {
    ComparisonScope.thisProduct => 'Este produto',
    ComparisonScope.wholeType => 'Tipo inteiro',
  };
}

/// One line of the table: a store, a price per base unit and the day of the
/// purchase that produced it.
final class ComparisonLine {
  const ComparisonLine({
    required this.store,
    required this.costPerBaseUnit,
    required this.baseUnit,
    required this.purchasedOn,
  });

  final Store store;

  /// Cents per base unit.
  final int costPerBaseUnit;

  /// The unit the price is written in — `/kg`, `/L`, `/un`.
  final BaseUnit baseUnit;

  /// **It informs, it does not order** (`requisitos §Regras`). Without it
  /// three prices look simultaneous when one is from yesterday and another
  /// from seven weeks ago, and the cheapest may just be the oldest.
  final DateTime purchasedOn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComparisonLine &&
          other.store == store &&
          other.costPerBaseUnit == costPerBaseUnit &&
          other.baseUnit == baseUnit &&
          other.purchasedOn == purchasedOn);

  @override
  int get hashCode =>
      Object.hash(store, costPerBaseUnit, baseUnit, purchasedOn);

  @override
  String toString() =>
      'ComparisonLine(${store.name}, $costPerBaseUnit, $purchasedOn)';
}

/// The table the tab draws, for one product and one view.
///
/// Four rules, all of them written in the requirements:
///
///   1. **One line per store**, with the price of the **most recent** purchase
///      in that store — never the average (decision D-o for the type view).
///   2. **A store with no purchase in the window does not appear.** It is not
///      filtered here: there simply is no quote of it, because the window
///      already filtered in the `select`.
///   3. **From the cheapest to the dearest.** The date is a caveat, not a
///      criterion.
///   4. **A leaf with no brand does NOT climb to the type here** (decision
///      D-v). Whoever climbs is [ComparisonScope.wholeType], and whoever
///      chooses it is the user.
///
/// Tiebreaks, in this order, so the list does not flicker between two reads:
/// price, then the most recent purchase first, then the normalized name of the
/// store, then the id.
IList<ComparisonLine> buildComparison({
  required IList<PriceQuote> quotes,
  required ProductOption selected,
  required ComparisonScope scope,
}) {
  final key = switch (scope) {
    ComparisonScope.thisProduct => selected.id,
    ComparisonScope.wholeType => selected.type.id,
  };
  if (key == null) return const IList.empty();

  final latestByStore = <String, PriceQuote>{};
  for (final quote in quotes) {
    final matches = switch (scope) {
      ComparisonScope.thisProduct => quote.productId == key,
      ComparisonScope.wholeType => quote.productTypeId == key,
    };
    if (!matches) continue;

    final storeId = quote.store.id;
    if (storeId == null) continue;

    final known = latestByStore[storeId];
    if (known == null || quote.purchasedOn.isAfter(known.purchasedOn)) {
      latestByStore[storeId] = quote;
      continue;
    }
    // Two purchases of the SAME day in the same store — possible in the type
    // view, where the crate and the can may have come in the same purchase.
    // The cheaper one stays, which is the answer the screen promises, and
    // never the order the `select` happened to return.
    if (quote.purchasedOn == known.purchasedOn &&
        quote.costPerBaseUnit < known.costPerBaseUnit) {
      latestByStore[storeId] = quote;
    }
  }

  final lines = [
    for (final quote in latestByStore.values)
      ComparisonLine(
        store: quote.store,
        costPerBaseUnit: quote.costPerBaseUnit,
        baseUnit: quote.option.baseUnit,
        purchasedOn: quote.purchasedOn,
      ),
  ]..sort(_compareLines);

  return lines.lock;
}

int _compareLines(ComparisonLine a, ComparisonLine b) {
  final byPrice = a.costPerBaseUnit.compareTo(b.costPerBaseUnit);
  if (byPrice != 0) return byPrice;

  // A tie on the price: the most recent first — between two equal prices, the
  // one from yesterday is worth more than the one from seven weeks ago.
  final byDay = b.purchasedOn.compareTo(a.purchasedOn);
  if (byDay != 0) return byDay;

  final byName = normalizeName(
    a.store.name,
  ).compareTo(normalizeName(b.store.name));
  if (byName != 0) return byName;

  return (a.store.id ?? '').compareTo(b.store.id ?? '');
}

/// The leaves the picker offers: **only the ones bought within the window**,
/// each of them once, even if it was bought in five stores.
///
/// A product outside the window does not get in because it would have nothing
/// to show — and a DEACTIVATED product does, because it was bought and
/// requirement 16 promises deactivating does not erase the past. That is why
/// this list comes out of the quotes and not out of `fetchProductOptions`.
IList<ProductOption> distinctOptionsOf(IList<PriceQuote> quotes) {
  final byId = <String, ProductOption>{};
  for (final quote in quotes) {
    final id = quote.productId;
    if (id == null) continue;
    byId.putIfAbsent(id, () => quote.option);
  }
  return byId.values.toIList();
}

/// The name of each category, for the group header of the picker.
IMap<String, String> categoryNamesOf(IList<PriceQuote> quotes) {
  final names = <String, String>{};
  for (final quote in quotes) {
    names[quote.categoryId] = quote.categoryName;
  }
  return names.lock;
}

/// The picker of this tab is grouped by **category** and alphabetical inside
/// it (`wireframes §Tela 5`) — unlike the one of screen 3, which is by type
/// and ordered by what gets bought most (C1). They are different questions:
/// there it is "pick fast what I am putting in the trolley", here it is "find
/// a product in a list that keeps growing".
///
/// It reuses [ProductGroup], which since 30/08/2026 carries a text `header`
/// instead of a `ProductType` (decision D-u) — without that there would be two
/// pickers to maintain.
IList<ProductGroup> buildComparisonGroups({
  required IList<ProductOption> options,
  required IMap<String, String> categoryNames,
}) {
  final byCategory = <String, List<ProductOption>>{};
  for (final option in options) {
    // A leaf whose type points at no category is not representable in the
    // schema; the `?? ''` only exists so the grouping does not lose anybody
    // in silence if one day it is.
    (byCategory[option.type.categoryId] ??= []).add(option);
  }

  for (final group in byCategory.values) {
    group.sort(
      (a, b) => normalizeName(a.label).compareTo(normalizeName(b.label)),
    );
  }

  final keys = byCategory.keys.toList()
    ..sort(
      (a, b) => normalizeName(
        categoryNames[a] ?? '',
      ).compareTo(normalizeName(categoryNames[b] ?? '')),
    );

  return [
    for (final key in keys)
      ProductGroup(
        header: categoryNames[key] ?? '',
        options: byCategory[key]!.toIList(),
      ),
  ].toIList();
}
