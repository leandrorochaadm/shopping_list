import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'money.dart';
import 'name_normalization.dart';
import 'period_report.dart';

/// One brand inside a type, and the weight it had in that type.
final class ReportBrandLine {
  const ReportBrandLine({required this.brand, required this.percentageInTenths});

  final BrandSpending brand;

  /// The share of the TYPE's total, in tenths of a point — decision G-a: the
  /// number written on the line right above, on the same screen; and decision
  /// G-e: an integer, 0 to 1000.
  ///
  /// **The lines of a type can add up to LESS than 100%** (decision G-b), and
  /// that silence is information: rule C2 keeps the null-brand group out of
  /// the breakdown, while the type's total goes on counting what it spent. A
  /// type showing 66,7% is a type where a third of the money was spent with
  /// no brand at all.
  final int percentageInTenths;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportBrandLine &&
          other.brand == brand &&
          other.percentageInTenths == percentageInTenths);

  @override
  int get hashCode => Object.hash(brand, percentageInTenths);

  @override
  String toString() => 'ReportBrandLine(${brand.name}, $percentageInTenths)';
}

/// One type line with its brands already resolved.
final class ReportTypeLine {
  const ReportTypeLine({
    required this.type,
    required this.percentageInTenths,
    required this.brands,
  });

  final TypeSpending type;

  /// The share of the CATEGORY's total this type took, in tenths of a point —
  /// decisions G-a and G-e.
  final int percentageInTenths;

  /// Already FILTERED by rule C2, already ordered, and each one already
  /// carrying its share of THIS type. Empty when the type has no purchase
  /// carrying a brand.
  final IList<ReportBrandLine> brands;

  /// The screen only offers the arrow when there is something to open
  /// (decision D-a). The View asks this; it does not write
  /// `brands.isNotEmpty` inside `build()` (rule 11).
  bool get hasBrandBreakdown => brands.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportTypeLine &&
          other.type == type &&
          other.percentageInTenths == percentageInTenths &&
          other.brands == brands);

  @override
  int get hashCode => Object.hash(type, percentageInTenths, brands);

  @override
  String toString() =>
      'ReportTypeLine(${type.name}, $percentageInTenths, '
      '${brands.length} marcas)';
}

/// One category, its weight in the period, and the types under it.
final class ReportSection {
  const ReportSection({
    required this.category,
    required this.percentageInTenths,
    required this.types,
  });

  final CategorySpending category;

  /// The share of the PERIOD H12 computed, in tenths of a point, carried
  /// along so the screen does not divide again.
  final int percentageInTenths;

  final IList<ReportTypeLine> types;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportSection &&
          other.category == category &&
          other.percentageInTenths == percentageInTenths &&
          other.types == types);

  @override
  int get hashCode => Object.hash(category, percentageInTenths, types);

  @override
  String toString() =>
      'ReportSection(${category.name}, $percentageInTenths, '
      '${types.length} tipos)';
}

/// The comparison of all THREE levels, written once. It takes the three fields
/// that decide — and not the entity — because category, type and brand share
/// no supertype, and inventing one just to sort would be an interface added to
/// solve a `compareTo`.
int compareBySpending({
  required Money spent,
  required String name,
  required String id,
  required Money otherSpent,
  required String otherName,
  required String otherId,
}) {
  // Descending: the screen's question is where the money went, and the answer
  // starts with whoever took the most.
  final byMoney = otherSpent.compareTo(spent);
  if (byMoney != 0) return byMoney;

  // A tie in value: alphabetical by the NORMALIZED name, so "Água" does not
  // fall after "Bebidas" because of the accent.
  final byName = normalizeName(name).compareTo(normalizeName(otherName));
  if (byName != 0) return byName;

  // And the id closes the order, so it does not oscillate between two reads of
  // the same period — two equal names do exist: not "Sem marca", but two
  // categories renamed to the same thing, yes.
  return id.compareTo(otherId);
}

/// The tree screen 5 draws, built and ORDERED out of the three flat
/// aggregations.
///
/// It is a pure function in the domain, and not a `for` inside `build()`, for
/// the same reason as `groupTypesByCategory`: it is rule — the order, the
/// percentage and C2 —, and rule inside `build()` is an architecture bug
/// (rule 11).
///
/// **Order, on three levels, always the same:** from what took the most money
/// to what took the least; a tie in value goes to the normalized name in
/// alphabetical order; and the id closes the order so it does not oscillate
/// between two reads of the same period.
///
/// **Rule C2 lives here:** the null-brand group the query returns is DISCARDED
/// from the breakdown (decision of 30/08/2026). The type's total still counts
/// what it spent, so the sum of the open lines may be smaller than the total
/// right above it — that is accepted, and it is why a type with no brand at
/// all offers no expansion: there would not be a single line to show.
///
/// **The percentage of each level is against the level right above it**
/// (decision G-a): the category against the period, the type against its
/// category, the brand against its type. All three in tenths of a point
/// (decision G-e). The brands of a type can add up to less than 100% — see
/// [ReportBrandLine.percentageInTenths].
IList<ReportSection> buildReportSections(PeriodReport report) {
  final brandsByType = <String, List<BrandSpending>>{};
  for (final brand in report.brands) {
    // C2: the group with no brand is not a line. The type's total already
    // counts what it spent — this only decides what the breakdown shows.
    if (!brand.hasBrand) continue;
    (brandsByType[brand.productTypeId] ??= []).add(brand);
  }
  for (final brands in brandsByType.values) {
    brands.sort(
      (a, b) => compareBySpending(
        spent: a.spent,
        name: a.name!,
        id: a.brandId!,
        otherSpent: b.spent,
        otherName: b.name!,
        otherId: b.brandId!,
      ),
    );
  }

  final typesByCategory = <String, List<TypeSpending>>{};
  for (final type in report.types) {
    (typesByCategory[type.categoryId] ??= []).add(type);
  }
  for (final types in typesByCategory.values) {
    types.sort(
      (a, b) => compareBySpending(
        spent: a.spent,
        name: a.name,
        id: a.productTypeId,
        otherSpent: b.spent,
        otherName: b.name,
        otherId: b.productTypeId,
      ),
    );
  }

  final categories = report.categories.toList()
    ..sort(
      (a, b) => compareBySpending(
        spent: a.spent,
        name: a.name,
        id: a.categoryId,
        otherSpent: b.spent,
        otherName: b.name,
        otherId: b.categoryId,
      ),
    );

  return [
    for (final category in categories)
      ReportSection(
        category: category,
        percentageInTenths: report.percentageInTenthsOf(category),
        types: [
          for (final type in typesByCategory[category.categoryId] ?? const [])
            ReportTypeLine(
              type: type,
              // G-a: against the category right above, never against the
              // period.
              percentageInTenths: spendingShareInTenths(
                part: type.spent,
                whole: category.spent,
              ),
              brands: [
                for (final brand
                    in brandsByType[type.productTypeId] ?? const [])
                  ReportBrandLine(
                    brand: brand,
                    // G-a again, one level down. G-b: this can add up to less
                    // than 100%, and that is the money spent with no brand.
                    percentageInTenths: spendingShareInTenths(
                      part: brand.spent,
                      whole: type.spent,
                    ),
                  ),
              ].lock,
            ),
        ].lock,
      ),
  ].lock;
}
