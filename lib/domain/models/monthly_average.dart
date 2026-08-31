import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'calendar_day.dart';
import 'category.dart';
import 'name_normalization.dart';
import 'product_type.dart';
import 'reference_window.dart';
import 'report_period.dart';
import 'type_consumption.dart';

/// How many DECIMAL PLACES a suggested quantity is worth showing — and it is a
/// number of a rule, so it lives here (rule 6).
///
/// One: `wireframes §Tela 2` writes `Café — 0,7 kg` and `§Tela 6` writes
/// `faltam 1,5 L` and `0,5 de 0,4 kg`. The exact average of the coffee is
/// 666,66… g, and `MeasureUnit.format` would answer `0,667` — three decimals
/// of precision a three-month average does not have, and a screen
/// contradicting the document the client reads.
const int averageDecimalPlaces = 1;

/// The step the average is rounded to, in the SMALLEST unit of [unit]: 100 g,
/// 100 ml, 1 un.
///
/// The `unit` base counts whole things — there is no 0,5 roll of toilet paper
/// — so its step is 1 and the rounding is a no-op there.
int averageStepOf(BaseUnit unit) {
  var step = unit.smallestUnits;
  for (var i = 0; i < averageDecimalPlaces; i++) {
    if (step < 10) return 1;
    step ~/= 10;
  }
  return step;
}

/// Rounds half-up to [averageStepOf], **in integers** — no division in
/// floating point anywhere (decision 24, `R15`).
///
/// It NEVER turns a POSITIVE amount into zero (decision E-d): `requisitos §8`
/// says nothing is filtered for being a rare purchase, and a line offering
/// `0 kg` is not an offer. 49 g of something bought once in three months comes
/// out as 100 g, which is honest about being small.
///
/// **A zero stays zero**, and that is not the same case (decision E-j): it is
/// the product bought in March and again in August, whose consumption inside
/// the closed window really is nothing. Rounding it up would be the system
/// claiming a consumption nobody had.
int roundToAverageStep(int amount, BaseUnit unit) {
  if (amount <= 0) return 0;
  final step = averageStepOf(unit);
  // Half-up without a single division in floating point:
  // floor(v + 0.5) == (2·numerator + denominator) ~/ (2·denominator).
  final rounded = ((amount * 2 + step) ~/ (step * 2)) * step;
  return rounded == 0 ? step : rounded;
}

/// How many CLOSED months of life the product has inside [window] — 0 to
/// [referenceWindowMonths].
///
/// Three for whoever was already being bought before the window, two for the
/// one that started in the middle of it, one for the one that started in the
/// last closed month, and **zero for the one whose first purchase is in the
/// month in progress** — that last one is the single exception of
/// `requisitos §8`, and it is what [monthlyAverageAmount] reads to divide
/// nothing at all.
///
/// A month with no purchase INSIDE the product's life still counts, and counts
/// zero: the coffee, bought once in June but already bought before the window,
/// divides by three.
int closedMonthsOfLife(DateTime firstPurchaseOn, ReportPeriod window) {
  final first = firstDayOfMonth(firstPurchaseOn);
  final start = firstDayOfMonth(window.from);
  final end = firstDayOfMonth(window.to);

  // Born after the window closed: no closed month at all.
  if (first.isAfter(end)) return 0;

  final from = first.isBefore(start) ? start : first;
  final months = (end.year - from.year) * 12 + (end.month - from.month) + 1;
  // The clamp is belt and braces: the window is three months wide by
  // construction, and the day someone widens it this stops lying.
  return months > referenceWindowMonths ? referenceWindowMonths : months;
}

/// The monthly average of one row, in the smallest unit of its base.
///
/// **The whole rule of requirement 8, in four lines:** the consumption of the
/// closed window divided by the closed months of life, rounded half-up — or,
/// for the product with no closed month, the amount bought in the month in
/// progress, with no division whatsoever.
int monthlyAverageAmount(TypeConsumption row, ReportPeriod window) {
  final divisor = closedMonthsOfLife(row.firstPurchaseOn, window);
  final raw = divisor == 0
      ? row.consumedInMonth
      // Half-up in integers, the same arithmetic as `TypeSpending`.
      : (row.consumedInWindow * 2 + divisor) ~/ (divisor * 2);
  return roundToAverageStep(raw, row.type.baseUnit);
}

/// What both screens read: one product type, how much of it they usually
/// consume in a month, and how much of that has already been bought.
///
/// **The type born in this month needs no flag** (decision E-g): its average
/// IS what it bought, so [remainingForMonth] is zero on its own and the
/// criterion "nunca aparece como faltando" stops being an `if` anyone can
/// forget.
final class MonthlyAverage {
  factory MonthlyAverage({
    required ProductType type,
    required Category category,
    required int average,
    required int consumedInMonth,
  }) {
    // Zero IS an answer (decision E-j) — the product bought before the window
    // and again this month consumed nothing inside it. Negative is not, and it
    // is the same ArgumentError `TypeSpending` throws for the same reason:
    // silently answering a plausible number would hide the bug.
    if (average < 0) {
      throw ArgumentError.value(
        average,
        'average',
        'a monthly average cannot be negative',
      );
    }
    return MonthlyAverage._(
      type: type,
      category: category,
      average: average,
      consumedInMonth: consumedInMonth,
    );
  }

  const MonthlyAverage._({
    required this.type,
    required this.category,
    required this.average,
    required this.consumedInMonth,
  });

  final ProductType type;
  final Category category;

  /// Already rounded, in the smallest unit of the base.
  final int average;

  final int consumedInMonth;

  /// **"Falta comprar no mês"** — the average minus what has been bought, and
  /// never negative: buying more than the average is not a debt.
  int get remainingForMonth {
    final left = average - consumedInMonth;
    return left < 0 ? 0 : left;
  }

  /// Which of the two bands of screen 6 this line belongs to.
  bool get hasShortage => remainingForMonth > 0;

  /// Whether there is an average to show at all — false only in the E-j case.
  bool get hasAverage => average > 0;

  /// What screen 2 puts in the new item's quantity, and **null when there is
  /// no average**: `ShoppingListItem` refuses a quantity of zero, and an item
  /// with no quantity is a valid line that leaves the list on the first
  /// purchase of the type — exactly what the `#1a` panel creates.
  int? get suggestedQuantity => hasAverage ? average : null;

  /// What screen 6 pre-fills the dialog with, and **null when nothing is
  /// missing**: the bottom band opens the dialog too, and a prefilled `0`
  /// would make saving throw `InvalidQuantity`.
  int? get prefillQuantity => hasShortage ? remainingForMonth : null;

  /// '6 kg', '0,7 kg', '12 un' — what screen 2 suggests.
  String get averageLabel => type.baseUnit.formatQuantity(average);

  /// 'faltam 2 kg' is composed by the screen; this is the '2 kg' of it.
  String get remainingLabel => type.baseUnit.formatQuantity(remainingForMonth);

  /// '4,2 de 4,2 L' — the bottom band of screen 6: what was consumed over the
  /// average. The first number carries no unit because the second one does.
  ///
  /// With no average there is nothing to be "de" (E-j), and the sentence says
  /// only what was bought: '5 kg comprados'.
  String get consumedOverAverageLabel => hasAverage
      ? '${type.baseUnit.typedMeasure.format(consumedInMonth)} de $averageLabel'
      : '${type.baseUnit.formatQuantity(consumedInMonth)} comprados';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyAverage &&
          other.type == type &&
          other.category == category &&
          other.average == average &&
          other.consumedInMonth == consumedInMonth);

  @override
  int get hashCode => Object.hash(type, category, average, consumedInMonth);

  @override
  String toString() =>
      'MonthlyAverage(${type.name}, average: $average, '
      'month: $consumedInMonth)';
}

/// The rows the two screens draw, out of the rows the query answered.
///
/// It DROPS the deactivated type (H10, and `handoff §H17` says so in as many
/// words) — the flag comes from SQL and the decision is here (decision E-e).
IList<MonthlyAverage> monthlyAverages(
  IList<TypeConsumption> rows,
  ReportPeriod window,
) => [
  for (final row in rows)
    if (row.type.active)
      MonthlyAverage(
        type: row.type,
        category: row.category,
        average: monthlyAverageAmount(row, window),
        consumedInMonth: row.consumedInMonth,
      ),
].lock;

/// One category and its lines, in the order the two screens draw them.
final class MonthlyAverageGroup {
  const MonthlyAverageGroup({required this.category, required this.lines});

  final Category category;
  final IList<MonthlyAverage> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyAverageGroup &&
          other.category == category &&
          other.lines == lines);

  @override
  int get hashCode => Object.hash(category, lines);

  @override
  String toString() => 'MonthlyAverageGroup(${category.name}, ${lines.length})';
}

/// Grouped by category, alphabetically, and inside each one by the type's name
/// — the same organization screens 1 and `#1a` use, so the eye does not have
/// to relearn it (`requisitos §8`, `wireframes §Tela 2` and `§Tela 6`).
///
/// **It is the THIRD grouping of the project and it is not a duplicate:**
/// `groupByCategory` takes `ShoppingListItem`, `groupTypesByCategory` takes
/// `ProductType`, and this one takes [MonthlyAverage]. It serves BOTH screens
/// of this delivery, which is why it is written once here and not twice in
/// `ui/`.
///
/// It compares by the NORMALIZED name, like the other two:
/// `'Açougue'.compareTo('Bebidas')` in Dart compares code units and the 'ç'
/// would land after the 'z'.
IList<MonthlyAverageGroup> groupAveragesByCategory(
  IList<MonthlyAverage> lines,
) {
  final byCategory = <String, List<MonthlyAverage>>{};
  final categories = <String, Category>{};

  for (final line in lines) {
    // A category with no id has not been written yet, and cannot be the one a
    // row points at — the name is the fallback so nothing is dropped.
    final key = line.category.id ?? line.category.name;
    categories[key] = line.category;
    (byCategory[key] ??= []).add(line);
  }

  final keys = categories.keys.toList()
    ..sort((a, b) => _compare(categories[a]!.name, categories[b]!.name, a, b));

  return [
    for (final key in keys)
      MonthlyAverageGroup(
        category: categories[key]!,
        lines:
            (byCategory[key]!..sort(
                  // The id breaks the tie so the order is STABLE across
                  // fetches: two types with the same name do not exist, but
                  // without a tiebreak the order of a tie changes on every
                  // read.
                  (a, b) => _compare(
                    a.type.name,
                    b.type.name,
                    a.type.id ?? '',
                    b.type.id ?? '',
                  ),
                ))
                .toIList(),
      ),
  ].toIList();
}

int _compare(String name, String otherName, String tie, String otherTie) {
  final byName = normalizeName(name).compareTo(normalizeName(otherName));
  return byName != 0 ? byName : tie.compareTo(otherTie);
}
