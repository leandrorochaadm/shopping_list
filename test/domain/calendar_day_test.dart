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
      expect(decodeCalendarDay('2026-08-28T13:45:00'), DateTime(2026, 8, 28));
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

  group('stored day', () {
    test('writes the day at UTC midnight', () {
      expect(encodeStoredDay(DateTime(2026, 1, 5)), '2026-01-05 00:00:00.000Z');
    });

    test('ignores the hour instead of shifting the day', () {
      expect(
        encodeStoredDay(DateTime(2026, 12, 31, 23, 30)),
        '2026-12-31 00:00:00.000Z',
      );
    });

    test('reads what PocketBase stores', () {
      final day = decodeStoredDay('2026-08-28 00:00:00.000Z');

      expect(day, DateTime(2026, 8, 28));
      expect(day.isUtc, isFalse);
    });

    test('accepts T or a space', () {
      expect(
        decodeStoredDay('2026-08-28T00:00:00.000Z'),
        DateTime(2026, 8, 28),
      );
      expect(decodeStoredDay('2026-08-28T00:00:00Z'), DateTime(2026, 8, 28));
      expect(
        decodeStoredDay('2026-08-28 00:00:00.000000Z'),
        DateTime(2026, 8, 28),
      );
    });

    test('accepts the bare day of old drafts', () {
      expect(decodeStoredDay('2026-08-28'), DateTime(2026, 8, 28));
    });

    test('refuses an hour that is not midnight', () {
      expect(
        () => decodeStoredDay('2026-08-28 13:45:00.000Z'),
        throwsFormatException,
      );
      expect(
        () => decodeStoredDay('2026-08-28 00:00:00.001Z'),
        throwsFormatException,
      );
    });

    test('refuses a suffix other than Z', () {
      expect(
        () => decodeStoredDay('2026-08-28 00:00:00.000'),
        throwsFormatException,
      );
      expect(
        () => decodeStoredDay('2026-08-28T00:00:00+00:00'),
        throwsFormatException,
      );
    });

    test('refuses empty and malformed text', () {
      expect(() => decodeStoredDay(''), throwsFormatException);
      expect(() => decodeStoredDay('2026-8-28'), throwsFormatException);
      expect(() => decodeStoredDay('28/08/2026'), throwsFormatException);
    });

    test('refuses a day that does not exist', () {
      expect(() => decodeStoredDay('2026-02-30'), throwsFormatException);
      expect(() => decodeStoredDay('2026-13-01'), throwsFormatException);
      expect(() => decodeStoredDay('2026-01-00'), throwsFormatException);
    });

    test('survives the round trip across the turn of the year', () {
      for (final day in [DateTime(2026, 12, 31), DateTime(2027, 1, 1)]) {
        final back = decodeStoredDay(encodeStoredDay(day));

        expect(back, day);
        expect(back.isUtc, isFalse);
      }
    });
  });

  group('instant', () {
    test('writes the instant in UTC', () {
      final instant = DateTime.utc(2026, 1, 5, 7, 8, 9, 45);

      expect(encodeInstant(instant), '2026-01-05 07:08:09.045Z');
      expect(encodeInstant(instant.toLocal()), '2026-01-05 07:08:09.045Z');
    });

    test('reads the instant back in UTC', () {
      final expected = DateTime.utc(2026, 8, 28, 13, 45, 0, 123);

      expect(decodeInstant('2026-08-28 13:45:00.123Z'), expected);
      expect(decodeInstant('2026-08-28T13:45:00.123Z'), expected);
      expect(decodeInstant('2026-08-28 13:45:00.123Z').isUtc, isTrue);
    });

    test('refuses an instant without Z or that does not exist', () {
      expect(() => decodeInstant(''), throwsFormatException);
      expect(() => decodeInstant('2026-08-28'), throwsFormatException);
      expect(
        () => decodeInstant('2026-08-28 13:45:00.000'),
        throwsFormatException,
      );
      expect(
        () => decodeInstant('2026-02-30 10:00:00.000Z'),
        throwsFormatException,
      );
      expect(
        () => decodeInstant('2026-08-28 25:00:00.000Z'),
        throwsFormatException,
      );
    });

    test('survives the round trip across the turn of the year', () {
      for (final x in [
        DateTime.utc(2026, 12, 31, 23, 59, 59, 999),
        DateTime.utc(2027, 1, 1),
      ]) {
        expect(decodeInstant(encodeInstant(x)), x);
      }
    });
  });
}
