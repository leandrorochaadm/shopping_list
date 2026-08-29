import 'base_unit.dart';
import 'money.dart';

/// What the LAST purchase of a product paid, and for how much content — the
/// two numbers the pre-filled value of screen 3 is a rule of three over.
///
/// **It is kept as the PAIR, and not as a rounded price per base unit**, and
/// that is the whole reason the class exists: 12 L bought for R$ 62,00 is
/// R$ 5,1667 a litre, which rounded to 517 cents a litre gives R$ 62,04 back
/// for the very same purchase. Whoever bought twelve litres again would see a
/// value four cents off the one on the receipt they are holding.
final class PriceReference {
  factory PriceReference({
    required Money paid,
    required int quantityInBaseUnit,
    required DateTime purchasedOn,
  }) {
    // The schema refuses it (`quantity_in_base_unit > 0`), so a zero here is
    // corrupt data or a bug of ours — an Error, which AppFailure classifies
    // as AppBug and the screen reports as an application problem. Silently
    // returning zero would hide it behind a wrong pre-filled value.
    if (quantityInBaseUnit <= 0) {
      throw ArgumentError.value(
        quantityInBaseUnit,
        'quantityInBaseUnit',
        'a price reference needs a positive quantity',
      );
    }
    return PriceReference._(
      paid: paid,
      quantityInBaseUnit: quantityInBaseUnit,
      purchasedOn: purchasedOn,
    );
  }

  const PriceReference._({
    required this.paid,
    required this.quantityInBaseUnit,
    required this.purchasedOn,
  });

  /// The total paid on that purchase, in cents. Not a unit price: the receipt
  /// carries the total, and the unit price is a division.
  final Money paid;

  /// How much content that money bought, in the smallest unit of the type's
  /// base — grams, millilitres, units.
  final int quantityInBaseUnit;

  /// The calendar day of that purchase.
  final DateTime purchasedOn;

  /// The value screen 3 pre-fills: `paid × newQuantity ÷ oldQuantity`,
  /// rounded half-up, with every step in integers.
  ///
  /// **This diverges from the wording of `handoff §H7`**, which says
  /// "quantidade convertida × preço da unidade base da última compra". The
  /// two formulas are the same before the rounding, and only this one does
  /// not accumulate the error of a rounded unit price — buying the same
  /// twelve litres again returns exactly what was paid.
  Money estimateFor(int quantityInBaseUnit) {
    if (quantityInBaseUnit <= 0) return Money.zero;
    // Half-up without a single division in floating point:
    // floor(v + 0.5) == (2·numerator + denominator) ~/ (2·denominator).
    return Money(
      (paid.cents * quantityInBaseUnit * 2 + this.quantityInBaseUnit) ~/
          (this.quantityInBaseUnit * 2),
    );
  }

  /// Cents per BASE unit — per kilo, per litre, per unit — ROUNDED.
  ///
  /// For display and comparison only, which is why the rounding is acceptable
  /// here and not in [estimateFor]. H15 (the price-increase alert) and H19
  /// (the `#3a` cost panel) are its real callers; screen 3 does not show it.
  ///
  /// It takes the unit instead of being a getter because [quantityInBaseUnit]
  /// is in the SMALLEST unit: without knowing that a litre is a thousand
  /// millilitres, "cents per litre" cannot be computed here.
  int costPerBaseUnit(BaseUnit baseUnit) {
    final smallest = baseUnit.smallestUnits;
    return (paid.cents * smallest * 2 + quantityInBaseUnit) ~/
        (quantityInBaseUnit * 2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceReference &&
          other.paid == paid &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.purchasedOn == purchasedOn);

  @override
  int get hashCode => Object.hash(paid, quantityInBaseUnit, purchasedOn);

  @override
  String toString() =>
      'PriceReference(${paid.cents} for $quantityInBaseUnit on '
      '${purchasedOn.toIso8601String()})';
}
