import 'calendar_day.dart';

/// A type of product this purchase brought home that SOMEONE ELSE also bought
/// on the same day.
///
/// It carries the day and not a "today" flag: the sentence changes with the
/// date ("hoje" × "no dia 25/08") and the instant is a PARAMETER (rule 9) — a
/// field computed at construction time would be a clock inside an entity.
final class SameDayAlert {
  SameDayAlert({
    required this.productTypeId,
    required this.typeName,
    required DateTime purchasedOn,
  }) : purchasedOn = dayOf(purchasedOn);

  factory SameDayAlert.fromJson(
    Map<String, dynamic> json,
    DateTime purchasedOn,
  ) => SameDayAlert(
    productTypeId: json['product_type_id'] as String,
    typeName: json['name'] as String,
    purchasedOn: purchasedOn,
  );

  final String productTypeId;
  final String typeName;
  final DateTime purchasedOn;

  /// pt-BR — read on screen. [shortDate] arrives already formatted from the
  /// View (`formatShortDate`, "25/08"): `intl` does not belong in the domain.
  ///
  /// The text is NEUTRAL on purpose — the alert is retroactive and does not
  /// know who bought first.
  String messageFor({required DateTime today, required String shortDate}) =>
      purchasedOn == dayOf(today)
      ? 'Vocês dois compraram $typeName hoje.'
      : 'Vocês dois compraram $typeName no dia $shortDate.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SameDayAlert &&
          other.productTypeId == productTypeId &&
          other.typeName == typeName &&
          other.purchasedOn == purchasedOn);

  @override
  int get hashCode => Object.hash(productTypeId, typeName, purchasedOn);

  @override
  String toString() =>
      'SameDayAlert($typeName, ${encodeCalendarDay(purchasedOn)})';
}

/// Whether the purchase being registered is recent enough for the alert:
/// **today or yesterday, and nothing older** (decision of 26/08/2026).
///
/// Calendar arithmetic, never `subtract(Duration(days: 1))`: on a day the
/// clock shifts, subtracting 24 hours lands at 23:00 of the previous day, and
/// the comparison would answer the wrong thing once a year, in silence.
bool isWithinRepeatWindow(DateTime purchaseDate, DateTime today) {
  final day = dayOf(purchaseDate);
  final now = dayOf(today);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  return day == now || day == yesterday;
}
