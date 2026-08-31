import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'money.dart';

// **No import of `product_option.dart` here, and it is deliberate.** It is
// the leaf that imports this file (for the `baseline` field and for
// `priceIncreaseFor`), never the other way round — Dart tolerates a cycle
// between libraries, but a cycle between two entities of the same package is
// where nobody can say any more who depends on whom. That is why
// `PriceBaselines.forLeaf` takes the three fields that DECIDE and not the
// entity: the same precedent as `compareBySpending`, in `report_section.dart`.

/// The cut of the alert: **10% or more** over the average (`requisitos
/// §Regras`, confirmed on 18/08/2026). Below that the price is normal
/// variation, and without the cut almost every purchase would fire an alert —
/// and the alert would stop being looked at.
///
/// It is `const` in the domain (rule 6), and the sentence of the warning
/// DERIVES from the computed percentage; it never repeats the value in text.
const int priceIncreaseThreshold = 10;

/// What the rolling window paid for a thing — the **pair**, and not a price
/// per base unit already rounded.
///
/// It is the same reason written in the header of [PriceReference], and it is
/// worth more here than there: an average IS a division, and comparing
/// against a rounded average makes the same entry answer 9% or 10% depending
/// on the cent that was lost.
///
/// The average is **weighted** — total paid ÷ total quantity — which is the
/// definition of average price of requirement 4: 5 kg at R$ 30 plus 1 kg at
/// R$ 42 is R$ 32 a kilo, not R$ 36.
final class PriceBaseline {
  factory PriceBaseline({
    required Money paid,
    required int quantityInBaseUnit,
  }) {
    // The schema refuses `quantity_in_base_unit > 0`, so a zero here is
    // corrupt data or a bug of ours — the same ArgumentError PriceReference
    // and TypeSpending throw for the same reason. Returning a zero average in
    // silence would hide it behind a plausible number.
    if (quantityInBaseUnit <= 0) {
      throw ArgumentError.value(
        quantityInBaseUnit,
        'quantityInBaseUnit',
        'a price baseline needs a positive quantity',
      );
    }
    return PriceBaseline._(paid: paid, quantityInBaseUnit: quantityInBaseUnit);
  }

  const PriceBaseline._({required this.paid, required this.quantityInBaseUnit});

  /// Everything paid for the thing within the window.
  final Money paid;

  /// All the quantity that money bought, in the SMALLEST unit of the base.
  final int quantityInBaseUnit;

  /// Cents per base unit — to display and to check in a test, never to
  /// compare: whoever compares is [evaluatePriceIncrease], in integers and
  /// without coming through here.
  int costPerBaseUnit(BaseUnit baseUnit) {
    final smallest = baseUnit.smallestUnits;
    return (paid.cents * smallest * 2 + quantityInBaseUnit) ~/
        (quantityInBaseUnit * 2);
  }

  /// One more purchase into the average. A method and not a `+`: adding two
  /// baselines is not the operation that exists — what exists is accumulating
  /// a line.
  PriceBaseline plus(Money morePaid, int moreQuantity) => PriceBaseline(
    paid: paid + morePaid,
    quantityInBaseUnit: quantityInBaseUnit + moreQuantity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceBaseline &&
          other.paid == paid &&
          other.quantityInBaseUnit == quantityInBaseUnit);

  @override
  int get hashCode => Object.hash(paid, quantityInBaseUnit);

  @override
  String toString() => 'PriceBaseline(${paid.cents} for $quantityInBaseUnit)';
}

/// The warning of screen 3, already resolved. Existing IS the alert: whoever
/// did not rise 10% gets `null` back, and the screen draws nothing.
final class PriceIncrease {
  const PriceIncrease({required this.percentage, required this.baseline});

  /// An integer, rounded half-up over the FULL value. Always
  /// >= [priceIncreaseThreshold]: the cut is applied before the rounding
  /// (decision D-s), so +9,6% does not become a 10% alert.
  final int percentage;

  /// The average the sum was made against — carried so the test can say what
  /// it compared with, and so a future screen can show it.
  final PriceBaseline baseline;

  /// pt-BR: it is read on screen. The sentence DERIVES from the percentage
  /// (rule 6) — there is no "10" written anywhere in here.
  String get message => 'Subiu $percentage% sobre a média';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceIncrease &&
          other.percentage == percentage &&
          other.baseline == baseline);

  @override
  int get hashCode => Object.hash(percentage, baseline);

  @override
  String toString() => 'PriceIncrease($percentage%)';
}

/// The whole rule of H15, in integers and without a single division in
/// floating point.
///
/// The price per base unit on both sides is `paid × smallestUnit ÷ quantity`,
/// and the `smallestUnit` **cancels out** in the ratio — which is why
/// [BaseUnit] does not appear here. Comparing `current/base` becomes a cross
/// multiplication:
///
///     rise% = 100 × (paid·qBase − paidBase·q) ÷ (paidBase·q)
///
/// **The cut is over the full value** (decision D-s): `rise% >= 10` is tested
/// with the whole fraction, and only then does the display round. A +9,6%
/// rounded to 10 before the test would alert over a tenth that does not
/// exist.
///
/// It returns `null` — the system **stays quiet** — in four cases, and all
/// four are written acceptance criteria:
///   * no base: a product (or type) with no purchase in the window;
///   * a quantity not typed yet, or not positive;
///   * a value not typed yet, or zero;
///   * a rise below the threshold, a fall included.
PriceIncrease? evaluatePriceIncrease({
  required PriceBaseline? baseline,
  required Money paid,
  required int quantityInBaseUnit,
}) {
  if (baseline == null) return null;
  if (quantityInBaseUnit <= 0 || paid.cents <= 0) return null;

  final current = paid.cents * baseline.quantityInBaseUnit;
  final reference = baseline.paid.cents * quantityInBaseUnit;
  if (reference <= 0) return null;

  final excess = current - reference;
  // The cut, over the full value: 100·excess >= threshold·reference.
  if (excess * 100 < priceIncreaseThreshold * reference) return null;

  // Half-up without a single division in floating point:
  // floor(v + 0.5) == (2·numerator + denominator) ~/ (2·denominator).
  final percentage = (excess * 100 * 2 + reference) ~/ (reference * 2);
  return PriceIncrease(percentage: percentage, baseline: baseline);
}

/// The averages of the window, at the two levels the rule uses — and the rule
/// of which of them applies to each leaf.
final class PriceBaselines {
  const PriceBaselines({required this.byProduct, required this.byType});

  static const empty = PriceBaselines(
    byProduct: IMap.empty(),
    byType: IMap.empty(),
  );

  final IMap<String, PriceBaseline> byProduct;
  final IMap<String, PriceBaseline> byType;

  /// **The rule of the product with no brand** (`requisitos §Regras`,
  /// confirmed on 18/08/2026): a leaf with a brand compares against itself; a
  /// leaf with NO brand climbs to the type, because ground beef has nobody to
  /// compare itself with and without this the most bought product of the
  /// house would have no alert.
  ///
  /// It is the ABSENCE OF THE BRAND that rules, not "sold by weight": the
  /// Tirolez mozzarella off the counter is compared against itself.
  ///
  /// It takes the three fields that decide and not the `ProductOption`, for
  /// the same reason as `compareBySpending`: this file then does not have to
  /// import the leaf, which is the one importing it.
  ///
  /// **The key is unlocked before the `[]`, and that is not style:**
  /// `IMap<String, V>.operator []` is `V? operator [](K k)` with
  /// `K = String` (`fast_immutable_collections-11.2.0/lib/src/imap/imap.dart:1115`),
  /// so passing a `String?` straight in is `argument_type_not_assignable` —
  /// it does not compile. A leaf with no id has not been written yet and has
  /// no history.
  PriceBaseline? forLeaf({
    required String? productId,
    required String? productTypeId,
    required bool hasBrand,
  }) {
    final key = hasBrand ? productId : productTypeId;
    if (key == null) return null;
    return hasBrand ? byProduct[key] : byType[key];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceBaselines &&
          other.byProduct == byProduct &&
          other.byType == byType);

  @override
  int get hashCode => Object.hash(byProduct, byType);

  @override
  String toString() =>
      'PriceBaselines(${byProduct.length} leaves, ${byType.length} types)';
}

/// Sums the whole window at both levels, in a single pass.
///
/// Pure and public so the ViewModel test can exercise it without a
/// container — the same reason as `rankOptions`.
PriceBaselines buildPriceBaselines(Iterable<PurchaseBaselineLine> history) {
  final byProduct = <String, PriceBaseline>{};
  final byType = <String, PriceBaseline>{};

  for (final line in history) {
    if (line.quantityInBaseUnit <= 0) continue;
    byProduct[line.productId] =
        byProduct[line.productId]?.plus(line.paid, line.quantityInBaseUnit) ??
        PriceBaseline(
          paid: line.paid,
          quantityInBaseUnit: line.quantityInBaseUnit,
        );
    byType[line.productTypeId] =
        byType[line.productTypeId]?.plus(line.paid, line.quantityInBaseUnit) ??
        PriceBaseline(
          paid: line.paid,
          quantityInBaseUnit: line.quantityInBaseUnit,
        );
  }

  return PriceBaselines(byProduct: byProduct.lock, byType: byType.lock);
}

/// What [buildPriceBaselines] needs of a purchase line, and nothing more.
///
/// An interface and not the entity of `data/`: `PurchaseHistoryEntry` lives in
/// `data/repositories/`, and the domain does not import `data/` (rule 1 and
/// the unidirectional flow). `PurchaseHistoryEntry` implements it — it gains
/// `implements PurchaseBaselineLine` and nothing else, because it already has
/// the four fields.
abstract interface class PurchaseBaselineLine {
  String get productId;
  String get productTypeId;
  int get quantityInBaseUnit;
  Money get paid;
}
