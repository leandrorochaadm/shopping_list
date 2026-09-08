import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/type_consumption.dart';
import 'consumption_repository.dart';

/// One purchase line, flattened the way `type_consumption` flattens it: the
/// day, the type it belongs to, and the quantity that gets summed.
///
/// A `final class` and not a record (rule 16): this is the shape the whole
/// fake is written against, and a record would have no name to say so. It
/// carries no price — the price of the very same purchases is
/// `ReportRepositoryLocal`'s job, and duplicating it here would be two numbers
/// to keep in step instead of one.
final class ConsumptionLine {
  const ConsumptionLine({
    required this.day,
    required this.typeId,
    required this.quantityInBaseUnit,
  });

  final DateTime day;
  final String typeId;

  /// In the SMALLEST unit of the type's base — grams, millilitres, units.
  final int quantityInBaseUnit;
}

/// In-memory fake: debug without --dart-define, and every test.
///
/// **It filters by the two intervals for real, and aggregates in Dart** — a
/// fake that always answered the same rows would hide the empty state and the
/// turn of the month, which are half of what these two screens are.
///
/// The seed is **the same history `ReportRepositoryLocal` holds**, month by
/// month and without the prices (decision E-l). The two fakes answer different
/// questions about the same purchases, and two seeds telling different stories
/// would make screen 5 say "Acém moído 6 kg em agosto" while screen 6 said
/// "faltam 2 kg de uma média de 6" — two answers about one type, in one month,
/// in debug. **The sync is manual and no test defends it**: whoever adds a
/// line there adds it here.
///
/// The types are the ones `CatalogRepositoryLocal` has, with the same ids —
/// naming a type screen 3 does not offer would make screens 2 and 6 look
/// wrong in debug for a reason that is only the fake's.
///
/// With a clock on 15/08/2026 — closed window 01/05 → 31/07, month 01/08 →
/// 31/08 — this is the story it tells:
///
/// | Tipo | Janela | Agosto | 1ª compra | Divisor | Média | Tela 6 |
/// |---|---|---|---|---|---|---|
/// | Acém moído | 24 kg | 6 kg | 12/05 | 3 | 8 kg | faltam 2 kg |
/// | Sabão em pó | 16 kg | 6,8 kg | 05/06 | 2 | 8 kg | faltam 1,2 kg |
/// | Café | 2 kg | — | 10/03 | 3 | 0,7 kg | faltam 0,7 kg |
/// | Refrigerante | 12,6 L | 4,2 L | 05/05 | 3 | 4,2 L | 4,2 de 4,2 L |
/// | Papel higiênico | — | 12 un | 05/08 | 0 | 12 un | 12 de 12 un |
///
/// **The honest limitation, and it is the fake of the report's too:** the days
/// are fixed in 2026 and the `today` of debug is the real clock. From
/// September 2026 the window walks and the numbers change on their own — which
/// is a fake that filters for real behaving correctly, not a defect — and in
/// 2027 the screens open empty. Re-anchoring now costs double: it is the dates
/// of BOTH seeds, which walk together from H17 on.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class ConsumptionRepositoryLocal implements ConsumptionRepository {
  ConsumptionRepositoryLocal({
    Iterable<ConsumptionLine>? lines,
    this.latency = const Duration(milliseconds: 400),
  }) : _lines = [...lines ?? _seed()];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<ConsumptionLine> _lines;

  /// The same purchases of `ReportRepositoryLocal._seed()`, in the same order,
  /// with the price dropped. Every line here has a twin there.
  static List<ConsumptionLine> _seed() => [
    // March, deliberately OUTSIDE both windows of a 15/08/2026 clock: it is
    // what makes the coffee divide by three with a single purchase inside the
    // closed window.
    _line(DateTime(2026, 3, 10), 'type-5', 1000),
    // The closed window: May, June and July.
    _line(DateTime(2026, 5, 5), 'type-1', 4200),
    _line(DateTime(2026, 5, 12), 'type-2', 12000),
    _line(DateTime(2026, 6, 5), 'type-1', 4200),
    // The FIRST purchase of the washing powder: it is what makes its divisor
    // two instead of three.
    _line(DateTime(2026, 6, 5), 'type-4', 8000),
    _line(DateTime(2026, 6, 10), 'type-2', 10000),
    // The only coffee inside the closed window — 2 kg over three months, which
    // is the 0,7 kg of `wireframes §Tela 2`.
    _line(DateTime(2026, 6, 20), 'type-5', 2000),
    _line(DateTime(2026, 7, 10), 'type-4', 8000),
    _line(DateTime(2026, 7, 15), 'type-2', 2000),
    _line(DateTime(2026, 7, 30), 'type-1', 4200),
    // The month in progress. The toilet paper is bought HERE for the first
    // time: no closed month at all, so its average is its own purchase and it
    // never shows up as missing.
    _line(DateTime(2026, 8, 5), 'type-3', 12),
    _line(DateTime(2026, 8, 10), 'type-2', 5000),
    _line(DateTime(2026, 8, 12), 'type-4', 4300),
    _line(DateTime(2026, 8, 18), 'type-1', 4200),
    _line(DateTime(2026, 8, 18), 'type-2', 1000),
    _line(DateTime(2026, 8, 20), 'type-4', 2500),
  ];

  static ConsumptionLine _line(DateTime day, String typeId, int quantity) =>
      ConsumptionLine(day: day, typeId: typeId, quantityInBaseUnit: quantity);

  /// The catalog the lines hang from, with the SAME ids
  /// `CatalogRepositoryLocal` gives them.
  static final _categories = <String, Category>{
    'cat-1': Category(id: 'cat-1', name: 'Bebidas'),
    'cat-2': Category(id: 'cat-2', name: 'Carnes'),
    'cat-3': Category(id: 'cat-3', name: 'Limpeza'),
    'cat-4': Category(id: 'cat-4', name: 'Mercearia'),
  };

  static final _types = <String, ProductType>{
    'type-1': ProductType(
      id: 'type-1',
      name: 'Refrigerante',
      categoryId: 'cat-1',
      baseUnit: BaseUnit.milliliter,
    ),
    'type-2': ProductType(
      id: 'type-2',
      name: 'Acém moído',
      categoryId: 'cat-2',
      baseUnit: BaseUnit.gram,
    ),
    'type-3': ProductType(
      id: 'type-3',
      name: 'Papel higiênico',
      categoryId: 'cat-3',
      baseUnit: BaseUnit.unit,
    ),
    'type-4': ProductType(
      id: 'type-4',
      name: 'Sabão em pó',
      categoryId: 'cat-3',
      baseUnit: BaseUnit.gram,
    ),
    'type-5': ProductType(
      id: 'type-5',
      name: 'Café',
      categoryId: 'cat-4',
      baseUnit: BaseUnit.gram,
    ),
  };

  @override
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  }) async {
    await Future<void>.delayed(latency);

    final inWindow = <String, int>{};
    final inMonth = <String, int>{};
    final firstPurchase = <String, DateTime>{};

    for (final line in _lines) {
      // The oldest purchase of each type, with NO interval filter: it is what
      // says whether the product predates the window, and so what the divisor
      // is. Filtering it by the window would answer June for the coffee and
      // make its average wrong by a third, in silence.
      final known = firstPurchase[line.typeId];
      if (known == null || line.day.isBefore(known)) {
        firstPurchase[line.typeId] = line.day;
      }
      if (_within(line.day, window)) {
        inWindow[line.typeId] =
            (inWindow[line.typeId] ?? 0) + line.quantityInBaseUnit;
      }
      if (_within(line.day, month)) {
        inMonth[line.typeId] =
            (inMonth[line.typeId] ?? 0) + line.quantityInBaseUnit;
      }
    }

    // Only the types with a purchase in at least ONE of the two intervals —
    // the same `or` the query's `where` has. A type bought only outside both
    // has nothing to suggest and nothing to be missing.
    final ids = {...inWindow.keys, ...inMonth.keys};

    return [
      for (final id in ids)
        if (_types[id] case final type?)
          TypeConsumption(
            type: type,
            category: _categories[type.categoryId]!,
            consumedInWindow: inWindow[id] ?? 0,
            consumedInMonth: inMonth[id] ?? 0,
            firstPurchaseOn: firstPurchase[id]!,
          ),
    ].toIList();
  }

  /// Closed at both ends, exactly like `between` in the query.
  static bool _within(DateTime day, ReportPeriod period) =>
      !day.isBefore(period.from) && !day.isAfter(period.to);
}
