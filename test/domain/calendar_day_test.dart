import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/calendar_day.dart';

void main() {
  group('calendar day', () {
    test('writes a date the way Postgres stores one', () {
      // The two leading zeros: '2026-1-5' is not a date PostgREST accepts.
      expect(encodeCalendarDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(encodeCalendarDay(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('survives the round trip', () {
      final day = DateTime(2026, 8, 28);

      expect(decodeCalendarDay(encodeCalendarDay(day)), day);
    });

    test('reads a full timestamp as the DAY it falls on', () {
      // The column is a `date` today. The day it becomes a timestamptz must
      // not bring the reading of the list down with it.
      expect(
        decodeCalendarDay('2026-08-28T13:45:00'),
        DateTime(2026, 8, 28),
      );
    });

    test('rounds the instant down to its day', () {
      final rounded = dayOf(DateTime(2026, 8, 28, 13, 45, 30, 500));

      expect(rounded, DateTime(2026, 8, 28));
      expect(rounded.hour, 0);
      expect(rounded.minute, 0);
      expect(rounded.second, 0);
      expect(rounded.millisecond, 0);
    });

    test('takes a day back to the 1st of its month', () {
      expect(firstDayOfMonth(DateTime(2026, 8, 1)), DateTime(2026, 8, 1));
      expect(firstDayOfMonth(DateTime(2026, 8, 31)), DateTime(2026, 8, 1));
      // An instant with an hour comes back rounded too: the cap is keyed by
      // this value, and a stray hour would make two months that are the same
      // month compare unequal.
      expect(
        firstDayOfMonth(DateTime(2026, 8, 15, 23, 59)),
        DateTime(2026, 8, 1),
      );
    });

    test('crosses the turn of the year', () {
      expect(firstDayOfMonth(DateTime(2026, 12, 31)), DateTime(2026, 12, 1));
      expect(firstDayOfMonth(DateTime(2027, 1, 1)), DateTime(2027, 1, 1));
    });
  });
}
