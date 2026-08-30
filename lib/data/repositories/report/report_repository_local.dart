import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/period_report.dart';
import '../../../domain/models/report_period.dart';
import 'report_repository.dart';

/// One purchase line, flattened the way the `report_period` query flattens it:
/// the day, the whole chain from category to brand, and the two numbers that
/// get summed.
///
/// A `final class` and not a record (rule 16): this is the shape the whole
/// fake is written against, and a record would have no name to say so.
final class ReportLine {
  const ReportLine({
    required this.day,
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

  final DateTime day;
  final String categoryId;
  final String categoryName;
  final String productTypeId;
  final String productTypeName;
  final BaseUnit baseUnit;

  /// Null is a VALUE: the product with no brand (decision B2).
  final String? brandId;
  final String? brandName;

  final int quantityInBaseUnit;
  final Money paid;
}

/// In-memory fake: debug without --dart-define, and every test.
///
/// **It filters by the period for real, and aggregates in Dart** — a fake that
/// always answered the same report would hide both the empty state and the two
/// month shortcuts, which are precisely what this screen is made of.
///
/// The seed is the written story of requirement 4, over the SAME catalog
/// `CatalogRepositoryLocal` holds: 6 kg of ground beef for R$ 192,00 at
/// R$ 32,00/kg, and 6,8 kg of washing powder for R$ 136,00 at R$ 20,00/kg
/// splitting into Omo and Tixan. Two fakes telling different stories would
/// make screen 3 and screen 5 disagree in debug for a reason that is only the
/// fake's.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class ReportRepositoryLocal implements ReportRepository {
  ReportRepositoryLocal({
    Iterable<ReportLine>? lines,
    this.latency = const Duration(milliseconds: 400),
  }) : _lines = [...lines ?? _seed()];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<ReportLine> _lines;

  static List<ReportLine> _seed() => [
    // ── Requirement 4, first example: 5 kg at R$ 30 and 1 kg at R$ 42 make
    //    6 kg at R$ 32,00/kg — and NOT the R$ 36 an average of averages gives.
    _line(DateTime(2026, 8, 10), _beef, quantity: 5000, cents: 15000),
    _line(DateTime(2026, 8, 18), _beef, quantity: 1000, cents: 4200),
    // ── Requirement 4, second example: one type adding up two brands.
    _line(
      DateTime(2026, 8, 12),
      _powder,
      brandId: 'brand-2',
      brandName: 'Omo',
      quantity: 4300,
      cents: 8600,
    ),
    _line(
      DateTime(2026, 8, 20),
      _powder,
      brandId: 'brand-4',
      brandName: 'Tixan',
      quantity: 2500,
      cents: 5000,
    ),
    _line(
      DateTime(2026, 8, 18),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 6200,
    ),
    // A type with no brand in a category that also holds a branded one: it is
    // what makes decision D-a visible while developing.
    _line(DateTime(2026, 8, 5), _paper, quantity: 12, cents: 3600),
    // ── The month before, so `‹ Julho` answers something different instead of
    //    looking broken.
    _line(
      DateTime(2026, 7, 30),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 5990,
    ),
    _line(DateTime(2026, 7, 15), _beef, quantity: 2000, cents: 6000),
  ];

  static const _softDrink = _Type(
    'type-1',
    'Refrigerante',
    'cat-1',
    'Bebidas',
    BaseUnit.liter,
  );
  static const _beef = _Type(
    'type-2',
    'Acém moído',
    'cat-2',
    'Carnes',
    BaseUnit.kilogram,
  );
  static const _paper = _Type(
    'type-3',
    'Papel higiênico',
    'cat-3',
    'Limpeza',
    BaseUnit.unit,
  );
  static const _powder = _Type(
    'type-4',
    'Sabão em pó',
    'cat-3',
    'Limpeza',
    BaseUnit.kilogram,
  );

  static ReportLine _line(
    DateTime day,
    _Type type, {
    String? brandId,
    String? brandName,
    required int quantity,
    required int cents,
  }) => ReportLine(
    day: day,
    categoryId: type.categoryId,
    categoryName: type.categoryName,
    productTypeId: type.id,
    productTypeName: type.name,
    baseUnit: type.baseUnit,
    brandId: brandId,
    brandName: brandName,
    quantityInBaseUnit: quantity,
    paid: Money(cents),
  );

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    await Future<void>.delayed(latency);

    // Closed at both ends, exactly like `between` in the query.
    final lines = _lines
        .where(
          (line) =>
              !line.day.isBefore(period.from) && !line.day.isAfter(period.to),
        )
        .toList();

    final categories = <String, CategorySpending>{};
    for (final line in lines) {
      final current = categories[line.categoryId];
      categories[line.categoryId] = CategorySpending(
        categoryId: line.categoryId,
        name: line.categoryName,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    final types = <String, TypeSpending>{};
    for (final line in lines) {
      final current = types[line.productTypeId];
      types[line.productTypeId] = TypeSpending(
        productTypeId: line.productTypeId,
        categoryId: line.categoryId,
        name: line.productTypeName,
        baseUnit: line.baseUnit,
        quantityInBaseUnit:
            (current?.quantityInBaseUnit ?? 0) + line.quantityInBaseUnit,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    final brands = <String, BrandSpending>{};
    for (final line in lines) {
      // The null brand groups with itself, and it is the query's null group:
      // what to do with it is rule C2, and it is decided in the domain.
      final key = '${line.productTypeId}/${line.brandId ?? ''}';
      final current = brands[key];
      brands[key] = BrandSpending(
        productTypeId: line.productTypeId,
        brandId: line.brandId,
        name: line.brandName,
        quantityInBaseUnit:
            (current?.quantityInBaseUnit ?? 0) + line.quantityInBaseUnit,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    // No ordering here either, for the same reason the query has none: whoever
    // orders is `buildReportSections`, and a second ordering is a second thing
    // to diverge.
    return PeriodReport(
      categories: categories.values.toIList(),
      types: types.values.toIList(),
      brands: brands.values.toIList(),
    );
  }
}

/// The chain a line hangs from, written once so the seed above reads as a
/// list of purchases and not as a list of ids.
final class _Type {
  const _Type(
    this.id,
    this.name,
    this.categoryId,
    this.categoryName,
    this.baseUnit,
  );

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final BaseUnit baseUnit;
}
