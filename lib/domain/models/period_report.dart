import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'money.dart';

/// How much a CATEGORY took out of the period. Money only, and on purpose:
/// adding 6 kg of meat to 12 L of soft drink gives no number at all.
///
/// That is decision D-c, and it diverges from the wording of `handoff §H11`
/// ("o total consumido e o total gasto agrupados por categoria"): the
/// `wireframes §Tela 5` draws "Carnes  R$ 480" with no quantity beside it, and
/// leaving the field out is what makes the mistake unrepresentable.
final class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.name,
    required this.spent,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) =>
      CategorySpending(
        categoryId: json['category_id'] as String,
        name: json['category_name'] as String,
        spent: Money.fromJson(json['total_paid']),
      );

  final String categoryId;

  /// pt-BR: read on screen.
  final String name;

  final Money spent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategorySpending &&
          other.categoryId == categoryId &&
          other.name == name &&
          other.spent == spent);

  @override
  int get hashCode => Object.hash(categoryId, name, spent);

  @override
  String toString() => 'CategorySpending($name, ${spent.cents})';
}

/// The level that SUMS. It carries the three measures of requirement 4:
/// quantity in the base unit, average price of that unit, and total spent.
final class TypeSpending {
  factory TypeSpending({
    required String productTypeId,
    required String categoryId,
    required String name,
    required BaseUnit baseUnit,
    required int quantityInBaseUnit,
    required Money spent,
  }) {
    // The schema refuses `quantity_in_base_unit > 0` and the sum of positives
    // is positive: a zero here is corrupt data or a bug of ours, and it is the
    // same ArgumentError PriceReference throws for the same reason. Silently
    // returning an average price of zero would hide it behind a plausible
    // number.
    if (quantityInBaseUnit <= 0) {
      throw ArgumentError.value(
        quantityInBaseUnit,
        'quantityInBaseUnit',
        'a type total needs a positive quantity',
      );
    }
    return TypeSpending._(
      productTypeId: productTypeId,
      categoryId: categoryId,
      name: name,
      baseUnit: baseUnit,
      quantityInBaseUnit: quantityInBaseUnit,
      spent: spent,
    );
  }

  const TypeSpending._({
    required this.productTypeId,
    required this.categoryId,
    required this.name,
    required this.baseUnit,
    required this.quantityInBaseUnit,
    required this.spent,
  });

  factory TypeSpending.fromJson(Map<String, dynamic> json) => TypeSpending(
    productTypeId: json['product_type_id'] as String,
    categoryId: json['category_id'] as String,
    name: json['product_type_name'] as String,
    baseUnit: BaseUnit.fromJson(json['base_unit'] as String),
    quantityInBaseUnit: (json['quantity_in_base_unit'] as num).toInt(),
    spent: Money.fromJson(json['total_paid']),
  );

  final String productTypeId;
  final String categoryId;

  /// pt-BR: read on screen.
  final String name;

  final BaseUnit baseUnit;

  /// In the SMALLEST unit of the base — grams, millilitres, units.
  final int quantityInBaseUnit;

  final Money spent;

  /// **Average price: total spent ÷ total quantity**, never an average of
  /// averages. 5 kg at R$ 30 plus 1 kg at R$ 42 is R$ 32 a kilo, not R$ 36 —
  /// that is the written acceptance criterion of requirement 4.
  ///
  /// In cents per BASE unit (per kilo, per litre, per unit), rounded half-up
  /// without a single division in floating point — the same arithmetic as
  /// `PriceReference.costPerBaseUnit`, written here because that one takes the
  /// `(paid, quantity)` pair of ONE purchase and this one adds up many.
  int get costPerBaseUnit {
    final smallest = baseUnit.smallestUnits;
    return (spent.cents * smallest * 2 + quantityInBaseUnit) ~/
        (quantityInBaseUnit * 2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TypeSpending &&
          other.productTypeId == productTypeId &&
          other.categoryId == categoryId &&
          other.name == name &&
          other.baseUnit == baseUnit &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.spent == spent);

  @override
  int get hashCode => Object.hash(
    productTypeId,
    categoryId,
    name,
    baseUnit,
    quantityInBaseUnit,
    spent,
  );

  @override
  String toString() =>
      'TypeSpending($name, $quantityInBaseUnit, ${spent.cents})';
}

/// One brand inside a type. [brandId] and [name] are NULL in the group of the
/// product with no brand — what the domain does with that group is rule C2,
/// and it lives in `buildReportSections`, not here.
final class BrandSpending {
  const BrandSpending({
    required this.productTypeId,
    required this.brandId,
    required this.name,
    required this.quantityInBaseUnit,
    required this.spent,
  });

  factory BrandSpending.fromJson(Map<String, dynamic> json) => BrandSpending(
    productTypeId: json['product_type_id'] as String,
    brandId: json['brand_id'] as String?,
    name: json['brand_name'] as String?,
    quantityInBaseUnit: (json['quantity_in_base_unit'] as num).toInt(),
    spent: Money.fromJson(json['total_paid']),
  );

  final String productTypeId;

  /// Null is a VALUE here (decision B2): it is the group of everything bought
  /// with no brand at all.
  final String? brandId;

  /// pt-BR: read on screen. Null exactly when [brandId] is.
  final String? name;

  final int quantityInBaseUnit;
  final Money spent;

  bool get hasBrand => brandId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrandSpending &&
          other.productTypeId == productTypeId &&
          other.brandId == brandId &&
          other.name == name &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.spent == spent);

  @override
  int get hashCode =>
      Object.hash(productTypeId, brandId, name, quantityInBaseUnit, spent);

  @override
  String toString() =>
      'BrandSpending(${name ?? 'sem marca'}, $quantityInBaseUnit, '
      '${spent.cents})';
}

/// The three aggregations of the SAME interval, as the `report_period`
/// function returns them.
///
/// One call, one instant, three answers that agree with each other: three
/// round trips for the same period are three different instants of the
/// database, and what the screen shows has to add up with itself.
final class PeriodReport {
  const PeriodReport({
    required this.categories,
    required this.types,
    required this.brands,
  });

  factory PeriodReport.fromJson(Map<String, dynamic> json) => PeriodReport(
    categories: _rowsOf(json['categories'])
        .map(CategorySpending.fromJson)
        .toIList(),
    types: _rowsOf(json['types']).map(TypeSpending.fromJson).toIList(),
    brands: _rowsOf(json['brands']).map(BrandSpending.fromJson).toIList(),
  );

  /// `const IList.empty()` and not `IListConst([])`: it is the form `lib/`
  /// uses; `IListConst` only shows up in `test/`.
  static const empty = PeriodReport(
    categories: IList.empty(),
    types: IList.empty(),
    brands: IList.empty(),
  );

  final IList<CategorySpending> categories;
  final IList<TypeSpending> types;
  final IList<BrandSpending> brands;

  /// Nothing was bought in this interval — the empty STATE of the screen, and
  /// not an error.
  bool get isEmpty => categories.isEmpty;

  /// The total of the period: the sum of the categories.
  ///
  /// It adds the CATEGORIES and not the types — the two give the same number,
  /// and that is exactly why only one of them can be the definition. The one
  /// H12 divides by was chosen.
  Money get total =>
      categories.fold(Money.zero, (sum, each) => sum + each.spent);

  /// **H12** — the weight of a category in the total of the PERIOD, not of
  /// the month.
  ///
  /// An integer, rounded half-up, never going through a `double`: 40%, as
  /// requirement 7 writes it.
  ///
  /// **A total of zero answers 0 instead of dividing by zero, and that case
  /// REACHES the screen** — it is not only the guard of the empty report. The
  /// schema accepts `total_paid >= 0`, so a period where everything was free
  /// has categories and a zero total: `isEmpty` is false, the screen draws the
  /// lines, "Total do período R$ 0,00" and `(0%)` on each of them.
  int percentageOf(CategorySpending category) {
    final all = total.cents;
    if (all == 0) return 0;
    return (category.spent.cents * 100 * 2 + all) ~/ (all * 2);
  }

  static List<Map<String, dynamic>> _rowsOf(Object? value) =>
      ((value as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodReport &&
          other.categories == categories &&
          other.types == types &&
          other.brands == brands);

  @override
  int get hashCode => Object.hash(categories, types, brands);

  @override
  String toString() =>
      'PeriodReport(${categories.length} categorias, ${types.length} tipos, '
      '${brands.length} marcas)';
}
