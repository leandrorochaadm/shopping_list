import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'money.dart';
import 'period_report.dart';

/// One raw purchase line of the interval, with category, type and brand
/// already resolved. A null brand is a VALUE (decision B2), not a gap.
final class PeriodLine {
  const PeriodLine({
    required this.categoryId,
    required this.categoryName,
    required this.productTypeId,
    required this.productTypeName,
    required this.baseUnit,
    required this.brandId,
    required this.brandName,
    required this.quantityInBaseUnit,
    required this.paid,
  });

  final String categoryId;

  /// pt-BR: read on screen.
  final String categoryName;

  final String productTypeId;

  /// pt-BR: read on screen.
  final String productTypeName;

  final BaseUnit baseUnit;

  /// Null = the product with no brand.
  final String? brandId;

  /// Null exactly when [brandId] is.
  final String? brandName;

  /// In the smallest unit of the base.
  final int quantityInBaseUnit;

  /// The item's total paid.
  final Money paid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodLine &&
          other.categoryId == categoryId &&
          other.categoryName == categoryName &&
          other.productTypeId == productTypeId &&
          other.productTypeName == productTypeName &&
          other.baseUnit == baseUnit &&
          other.brandId == brandId &&
          other.brandName == brandName &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.paid == paid);

  @override
  int get hashCode => Object.hash(
    categoryId,
    categoryName,
    productTypeId,
    productTypeName,
    baseUnit,
    brandId,
    brandName,
    quantityInBaseUnit,
    paid,
  );

  @override
  String toString() =>
      'PeriodLine($categoryName, $productTypeName, '
      '${brandName ?? 'sem marca'}, $quantityInBaseUnit, ${paid.cents})';
}

/// Sums the lines of an interval into the three aggregations of
/// [PeriodReport], in a single pass.
///
/// The interval is already filtered by the read, and `active` is not looked
/// at: a deactivated registration still reports. Groups are keyed by id,
/// never by name, and come out in the order of their first appearance — the
/// sorting belongs to `buildReportSections`.
PeriodReport summarizePeriod(IList<PeriodLine> lines) {
  if (lines.isEmpty) return PeriodReport.empty;

  final categories = <String, CategorySpending>{};
  final types = <String, _TypeSum>{};
  final brands = <(String, String?), _BrandSum>{};

  for (final line in lines) {
    final category = categories[line.categoryId];
    categories[line.categoryId] = CategorySpending(
      categoryId: line.categoryId,
      name: category?.name ?? line.categoryName,
      spent: (category?.spent ?? Money.zero) + line.paid,
    );

    final type = types.putIfAbsent(line.productTypeId, () => _TypeSum(line));
    type.add(line);

    final brand = brands.putIfAbsent((
      line.productTypeId,
      line.brandId,
    ), () => _BrandSum(line));
    brand.add(line);
  }

  return PeriodReport(
    categories: categories.values.toIList(),
    types: types.values.map((sum) => sum.build()).toIList(),
    brands: brands.values.map((sum) => sum.build()).toIList(),
  );
}

class _TypeSum {
  _TypeSum(PeriodLine first)
    : productTypeId = first.productTypeId,
      categoryId = first.categoryId,
      name = first.productTypeName,
      baseUnit = first.baseUnit;

  final String productTypeId;
  final String categoryId;
  final String name;
  final BaseUnit baseUnit;
  int quantity = 0;
  Money spent = Money.zero;

  void add(PeriodLine line) {
    quantity += line.quantityInBaseUnit;
    spent += line.paid;
  }

  TypeSpending build() => TypeSpending(
    productTypeId: productTypeId,
    categoryId: categoryId,
    name: name,
    baseUnit: baseUnit,
    quantityInBaseUnit: quantity,
    spent: spent,
  );
}

class _BrandSum {
  _BrandSum(PeriodLine first)
    : productTypeId = first.productTypeId,
      brandId = first.brandId,
      name = first.brandName;

  final String productTypeId;
  final String? brandId;
  final String? name;
  int quantity = 0;
  Money spent = Money.zero;

  void add(PeriodLine line) {
    quantity += line.quantityInBaseUnit;
    spent += line.paid;
  }

  BrandSpending build() => BrandSpending(
    productTypeId: productTypeId,
    brandId: brandId,
    name: name,
    quantityInBaseUnit: quantity,
    spent: spent,
  );
}
