import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/report/report_repository.dart';
import 'package:shopping_list/data/repositories/report/report_repository_local.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';

/// The report fake every widget test of screen 5 needs, in ONE place — the
/// same reason `catalog.dart` and `purchase.dart` exist.
///
/// The latency is zero, not the fake's 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay.
Override reportOverride({ReportRepository? repository}) =>
    reportRepositoryProvider.overrideWith(
      (ref) => repository ?? ReportRepositoryLocal(latency: Duration.zero),
    );

/// The written story of requirement 4, as one [PeriodReport] — so the ViewModel
/// test and the widget test count the same numbers instead of two fixtures
/// that drift apart.
///
///   * Carnes  R$ 192,00 (58,5%) — Acém moído, 6 kg at R$ 32,00/kg, no brand
///   * Limpeza R$ 136,00 (41,5%) — Sabão em pó, 6,8 kg at R$ 20,00/kg,
///     splitting into Omo (4,3 kg, R$ 86,00) and Tixan (2,5 kg, R$ 50,00)
///
/// Total do período: R$ 328,00.
final referenceReport = PeriodReport(
  categories: [
    const CategorySpending(
      categoryId: 'cat-2',
      name: 'Carnes',
      spent: Money(19200),
    ),
    const CategorySpending(
      categoryId: 'cat-3',
      name: 'Limpeza',
      spent: Money(13600),
    ),
  ].lock,
  types: [
    TypeSpending(
      productTypeId: 'type-2',
      categoryId: 'cat-2',
      name: 'Acém moído',
      baseUnit: BaseUnit.kilogram,
      quantityInBaseUnit: 6000,
      spent: const Money(19200),
    ),
    TypeSpending(
      productTypeId: 'type-4',
      categoryId: 'cat-3',
      name: 'Sabão em pó',
      baseUnit: BaseUnit.kilogram,
      quantityInBaseUnit: 6800,
      spent: const Money(13600),
    ),
  ].lock,
  brands: [
    // The ground beef has no brand at all — decision D-a: its line offers no
    // expansion, because there would not be a single row to show.
    const BrandSpending(
      productTypeId: 'type-2',
      brandId: null,
      name: null,
      quantityInBaseUnit: 6000,
      spent: Money(19200),
    ),
    const BrandSpending(
      productTypeId: 'type-4',
      brandId: 'brand-2',
      name: 'Omo',
      quantityInBaseUnit: 4300,
      spent: Money(8600),
    ),
    const BrandSpending(
      productTypeId: 'type-4',
      brandId: 'brand-4',
      name: 'Tixan',
      quantityInBaseUnit: 2500,
      spent: Money(5000),
    ),
  ].lock,
);
