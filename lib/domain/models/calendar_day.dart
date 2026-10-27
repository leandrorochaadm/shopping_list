/// A calendar DAY, which is what `entered_on` and `purchase_date` are — a
/// `date` in Postgres, with no time zone and no hour.
///
/// `intl` does NOT come in here: `DateFormat` loads locale data, and this file
/// is read by `fromJson`, which runs before any screen has initialized
/// anything.
///
/// `encodeCalendarDay`/`decodeCalendarDay` are the old date-only format, no longer
/// used by the repositories. PocketBase uses `encodeStoredDay`/`decodeStoredDay`
/// (calendar days) and `encodeInstant`/`decodeInstant` (UTC instants).
library;

final _storedDayPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z)?$',
);
final _instantPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
);

String _two(int n) => n.toString().padLeft(2, '0');

/// The day written the way PocketBase stores a `date` field:
/// 'YYYY-MM-DD 00:00:00.000Z'. The calendar day is what the components say —
/// no `toUtc()`/`toLocal()`, and the hour of [day] is ignored.
String encodeStoredDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-${_two(day.day)}'
    ' 00:00:00.000Z';

/// Reads a stored day. Only the first 10 characters give the day; the rest
/// must be a midnight in UTC (or absent). Returns a LOCAL [DateTime], the same
/// kind as [dayOf], so the entities' `==` does not break on `isUtc`.
DateTime decodeStoredDay(String value) {
  if (!_storedDayPattern.hasMatch(value)) {
    throw FormatException('Not a stored day: "$value"');
  }
  final day = _parseDay(value);
  if (value.length > 10) {
    final time = value.substring(11, value.length - 1);
    if (time.replaceAll(RegExp(r'[0:.]'), '').isNotEmpty) {
      throw FormatException('Stored day is not at midnight: "$value"');
    }
  }
  return day;
}

DateTime _parseDay(String value) {
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final dayOfMonth = int.parse(value.substring(8, 10));
  final check = DateTime.utc(year, month, dayOfMonth);
  if (check.year != year || check.month != month || check.day != dayOfMonth) {
    throw FormatException('Day does not exist: "$value"');
  }
  return DateTime(year, month, dayOfMonth);
}

/// An instant written for a PocketBase `date` field: always UTC,
/// 'YYYY-MM-DD HH:mm:ss.SSSZ' (microseconds are dropped).
String encodeInstant(DateTime instant) {
  final utc = instant.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-${_two(utc.month)}-'
      '${_two(utc.day)} ${_two(utc.hour)}:${_two(utc.minute)}:'
      '${_two(utc.second)}.${utc.millisecond.toString().padLeft(3, '0')}Z';
}

/// Reads an instant back as UTC. The `Z` is required: an instant without a
/// zone would be read as local time.
DateTime decodeInstant(String value) {
  if (!_instantPattern.hasMatch(value)) {
    throw FormatException('Not an instant in UTC: "$value"');
  }
  final parsed = DateTime.parse(value);
  final date = _parseDay(value);
  final hour = int.parse(value.substring(11, 13));
  final minute = int.parse(value.substring(14, 16));
  final second = int.parse(value.substring(17, 19));
  if (parsed.year != date.year ||
      parsed.month != date.month ||
      parsed.day != date.day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    throw FormatException('Instant does not exist: "$value"');
  }
  return parsed;
}

/// The day written the way Postgres stores a `date`: 'yyyy-MM-dd'.
String encodeCalendarDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The way back. It accepts what the server returns for a `date` and also a
/// full timestamp, because a column that turns into a timestamptz one day
/// must not bring the list down with it.
DateTime decodeCalendarDay(String value) => dayOf(DateTime.parse(value));

/// Zeroes the time. It is the rounding of rule 9: a fresh instant on every
/// frame would break the entity's `==` and repaint the whole list.
DateTime dayOf(DateTime instant) =>
    DateTime(instant.year, instant.month, instant.day);

/// Day 1 of the month [day] belongs to. It is what the spending cap is keyed
/// by: the cap is monthly, one row per CHANGE, and a mid-month date would make
/// "the month's total" ambiguous.
DateTime firstDayOfMonth(DateTime day) => DateTime(day.year, day.month, 1);
