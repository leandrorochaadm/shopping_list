/// A calendar DAY, which is what `entered_on` and `purchase_date` are — a
/// `date` in Postgres, with no time zone and no hour.
///
/// `intl` does NOT come in here: `DateFormat` loads locale data, and this file
/// is read by `fromJson`, which runs before any screen has initialized
/// anything.
library;

/// The day written the way Postgres stores a `date`: 'yyyy-MM-dd'.
String encodeCalendarDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The way back. It accepts what PostgREST returns for a `date` and also a
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
