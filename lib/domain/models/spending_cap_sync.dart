import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'money.dart';
import 'spending_cap.dart';

/// What the batch does with one month's alert row. `none` never reaches it.
enum CapAlertWrite { none, create, update, delete }

/// The stored `spending_cap_alert` row: id + month + the two stamps. A null
/// stamp is "not crossed".
final class StoredCapAlert {
  StoredCapAlert({
    required this.id,
    required DateTime month,
    this.warned80At,
    this.warned100At,
  }) : month = firstDayOfMonth(month);

  final String id;
  final DateTime month;
  final DateTime? warned80At;
  final DateTime? warned100At;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredCapAlert &&
          other.id == id &&
          other.month == month &&
          other.warned80At == warned80At &&
          other.warned100At == warned100At);

  @override
  int get hashCode => Object.hash(id, month, warned80At, warned100At);

  @override
  String toString() =>
      'StoredCapAlert($id, ${encodeCalendarDay(month)}, '
      '80: $warned80At, 100: $warned100At)';
}

/// One month of the alert plan: the FINAL state of both stamps, written as
/// they are (null = empty field), and what to do with the row.
final class CapAlertStep {
  CapAlertStep({
    required DateTime month,
    required this.recordId,
    required this.warned80At,
    required this.warned100At,
    required this.write,
  }) : month = firstDayOfMonth(month);

  final DateTime month;

  /// The id of the stored row of the month; null when there is none.
  final String? recordId;
  final DateTime? warned80At;
  final DateTime? warned100At;
  final CapAlertWrite write;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapAlertStep &&
          other.month == month &&
          other.recordId == recordId &&
          other.warned80At == warned80At &&
          other.warned100At == warned100At &&
          other.write == write);

  @override
  int get hashCode =>
      Object.hash(month, recordId, warned80At, warned100At, write);

  @override
  String toString() =>
      'CapAlertStep(${encodeCalendarDay(month)}, $write, id: $recordId, '
      '80: $warned80At, 100: $warned100At)';
}

/// What `apply_cap_alerts` decided in SQL: one step per month of [wanted], in
/// its order. A crossed cut keeps the stored stamp or takes [stampedAt]; an
/// uncrossed one clears it. A row with no stamp left is deleted, and a month
/// with no row and nothing crossed writes nothing.
///
/// [rearm] is `save_spending_cap`: the stored stamps of the wanted months are
/// ignored, but the row is still reused.
///
/// Months of [existing] that are not in [wanted] are never touched. A repeated
/// month in either list is an invariant broken, and throws [ArgumentError].
IList<CapAlertStep> planCapAlertWrites({
  required IList<CapAlerts> wanted,
  required IList<StoredCapAlert> existing,
  required DateTime stampedAt,
  bool rearm = false,
}) {
  final stored = <DateTime, StoredCapAlert>{};
  for (final row in existing) {
    if (stored.containsKey(row.month)) {
      throw ArgumentError(
        'Month stored twice: ${encodeCalendarDay(row.month)}',
      );
    }
    stored[row.month] = row;
  }
  final seen = <DateTime>{};
  final steps = <CapAlertStep>[];
  for (final alerts in wanted) {
    if (!seen.add(alerts.month)) {
      throw ArgumentError(
        'Month wanted twice: ${encodeCalendarDay(alerts.month)}',
      );
    }
    final row = stored[alerts.month];
    final old80 = rearm ? null : row?.warned80At;
    final old100 = rearm ? null : row?.warned100At;
    final new80 = alerts.warned80 ? (old80 ?? stampedAt) : null;
    final new100 = alerts.warned100 ? (old100 ?? stampedAt) : null;
    final CapAlertWrite write;
    if (row == null) {
      write = new80 == null && new100 == null
          ? CapAlertWrite.none
          : CapAlertWrite.create;
    } else if (new80 == null && new100 == null) {
      write = CapAlertWrite.delete;
    } else if (new80 == row.warned80At && new100 == row.warned100At) {
      write = CapAlertWrite.none;
    } else {
      write = CapAlertWrite.update;
    }
    steps.add(
      CapAlertStep(
        month: alerts.month,
        recordId: row?.id,
        warned80At: new80,
        warned100At: new100,
        write: write,
      ),
    );
  }
  return steps.toIList();
}

/// What `cap_states` answered: one status per DISTINCT month of [months],
/// ordered by month. The cap in force is the one with the greatest
/// `effectiveFrom` not after the month; none means no cap. [spentByMonth] keys
/// of any day of the month count toward it.
IList<MonthCapStatus> buildMonthCapStatuses({
  required IList<DateTime> months,
  required IList<SpendingCap> caps,
  required IMap<DateTime, Money> spentByMonth,
  required IList<StoredCapAlert> alerts,
}) {
  final distinct = months.map(firstDayOfMonth).toSet().toList()
    ..sort((a, b) => a.compareTo(b));
  return distinct.map((month) {
    SpendingCap? cap;
    for (final candidate in caps) {
      if (candidate.effectiveFrom.isAfter(month)) continue;
      if (cap == null || candidate.effectiveFrom.isAfter(cap.effectiveFrom)) {
        cap = candidate;
      }
    }
    var spent = Money.zero;
    for (final entry in spentByMonth.entries) {
      if (firstDayOfMonth(entry.key) == month) spent = spent + entry.value;
    }
    StoredCapAlert? stored;
    for (final row in alerts) {
      if (row.month == month) stored = row;
    }
    return MonthCapStatus(
      month: month,
      cap: cap,
      spent: spent,
      alerts: CapAlerts(
        month: month,
        warned80: stored?.warned80At != null,
        warned100: stored?.warned100At != null,
      ),
    );
  }).toIList();
}
