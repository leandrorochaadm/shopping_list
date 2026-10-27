import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'category.dart';
import 'product_type.dart';
import 'report_period.dart';
import 'type_consumption.dart';

/// One row of `purchase_item`, flattened: the type and category of the
/// purchased product, the day of the purchase and the quantity in the base
/// unit. It is what [buildTypeConsumption] adds up.
final class ConsumptionLine {
  /// **May throw [ArgumentError]**: the sum is per type id, so a type without
  /// id has nowhere to go, and a negative quantity is corrupt data.
  ConsumptionLine({
    required this.type,
    required this.category,
    required DateTime purchaseDate,
    required this.quantityInBaseUnit,
    // Rule 9: rounded here, so an hour never breaks the `==`.
  }) : purchaseDate = dayOf(purchaseDate) {
    if (type.id == null) {
      throw ArgumentError.value(type, 'type', 'must have an id');
    }
    if (quantityInBaseUnit < 0) {
      throw ArgumentError.value(
        quantityInBaseUnit,
        'quantityInBaseUnit',
        'must not be negative',
      );
    }
  }

  final ProductType type;
  final Category category;
  final DateTime purchaseDate;
  final int quantityInBaseUnit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsumptionLine &&
          other.type == type &&
          other.category == category &&
          other.purchaseDate == purchaseDate &&
          other.quantityInBaseUnit == quantityInBaseUnit);

  @override
  int get hashCode =>
      Object.hash(type, category, purchaseDate, quantityInBaseUnit);

  @override
  String toString() =>
      'ConsumptionLine(${type.name}, ${encodeCalendarDay(purchaseDate)}, '
      '$quantityInBaseUnit)';
}

/// Since when the repository reads `purchase_item`: the start of the older of
/// the two intervals. The repository never computes a date.
DateTime consumptionReadStart({
  required ReportPeriod window,
  required ReportPeriod month,
}) => window.from.isBefore(month.from) ? window.from : month.from;

/// What the `type_consumption` RPC computed in SQL: per product type, the sum
/// in each of the two intervals (both ends closed) and the first purchase.
///
/// **First purchase:** [allTimeCountByType] counts ALL the items of a type
/// ever bought; if it is larger than the lines read, something was bought
/// before the read, and the day is `consumptionReadStart − 1`. Otherwise it is
/// the oldest line read. The divisor is the same either way.
///
/// **May throw [ArgumentError]** for a line before [consumptionReadStart].
IList<TypeConsumption> buildTypeConsumption({
  required IList<ConsumptionLine> windowLines,
  required IMap<String, int> allTimeCountByType,
  required ReportPeriod window,
  required ReportPeriod month,
}) {
  final readStart = consumptionReadStart(window: window, month: month);
  final order = <String>[];
  final linesByType = <String, List<ConsumptionLine>>{};

  for (final line in windowLines) {
    if (line.purchaseDate.isBefore(readStart)) {
      throw ArgumentError.value(line, 'windowLines', 'predates the read start');
    }
    final id = line.type.id!;
    final bucket = linesByType[id];
    if (bucket == null) {
      order.add(id);
      linesByType[id] = [line];
    } else {
      bucket.add(line);
    }
  }

  bool within(DateTime day, ReportPeriod period) =>
      !day.isBefore(period.from) && !day.isAfter(period.to);

  final result = <TypeConsumption>[];
  for (final id in order) {
    final lines = linesByType[id]!;
    var inWindow = 0;
    var inMonth = 0;
    var touched = false;
    var oldest = lines.first.purchaseDate;
    for (final line in lines) {
      if (line.purchaseDate.isBefore(oldest)) oldest = line.purchaseDate;
      if (within(line.purchaseDate, window)) {
        inWindow += line.quantityInBaseUnit;
        touched = true;
      }
      if (within(line.purchaseDate, month)) {
        inMonth += line.quantityInBaseUnit;
        touched = true;
      }
    }
    if (!touched) continue;

    final history = allTimeCountByType[id] ?? 0;
    final firstPurchaseOn = history > lines.length
        ? DateTime(readStart.year, readStart.month, readStart.day - 1)
        : oldest;

    result.add(
      TypeConsumption(
        type: lines.first.type,
        category: lines.first.category,
        consumedInWindow: inWindow,
        consumedInMonth: inMonth,
        firstPurchaseOn: firstPurchaseOn,
      ),
    );
  }
  return result.toIList();
}
