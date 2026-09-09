import 'base_unit.dart';
import 'money.dart';

/// The two-way rule between what was PAID and the price of one PRICING unit —
/// the "R$ 39,90 o kg" on the shelf tag.
///
/// It lives here, and not on screen 3, because it is arithmetic over money and
/// a quantity: the screen asks, it never divides cents inside a `build()`
/// (rule 11). Every step is in integers and rounded half-up, like
/// `PriceReference.estimateFor` — a cent lost in a double is a cent off the
/// receipt (`R15`).
///
/// **The pair never round-trips exactly, and that is expected.** Two roundings
/// over the same pair can differ by a cent, so each function is called only
/// when the OTHER field was the one typed: whoever typed a number keeps it,
/// and only the derived one is rewritten.

/// Cents per pricing unit — per kilo, per litre, per unit, per metre.
///
/// `null` is "there is nothing to divide": no quantity, or nothing paid. The
/// screen reads that as "leave the field empty", never as zero.
Money? pricePerLargeUnitOf({
  required Money paid,
  required int quantityInBaseUnit,
  required BaseUnit unit,
}) {
  if (quantityInBaseUnit <= 0 || paid.cents <= 0) return null;
  final perLarge = unit.unitsPerLargeUnit;
  return Money(
    (paid.cents * perLarge * 2 + quantityInBaseUnit) ~/
        (quantityInBaseUnit * 2),
  );
}

/// The way back: what a quantity costs at a given price per pricing unit.
///
/// `null` on the same two grounds, and for the same reason.
Money? paidAtPricePerLargeUnit({
  required Money pricePerLargeUnit,
  required int quantityInBaseUnit,
  required BaseUnit unit,
}) {
  if (quantityInBaseUnit <= 0 || pricePerLargeUnit.cents <= 0) return null;
  final perLarge = unit.unitsPerLargeUnit;
  return Money(
    (pricePerLargeUnit.cents * quantityInBaseUnit * 2 + perLarge) ~/
        (perLarge * 2),
  );
}
