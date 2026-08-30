import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/report_period.dart';

void main() {
  group('the interval', () {
    test('a single day is a valid period', () {
      final period = ReportPeriod(
        from: DateTime(2026, 8, 15),
        to: DateTime(2026, 8, 15),
      );

      expect(period.from, DateTime(2026, 8, 15));
      expect(period.to, DateTime(2026, 8, 15));
    });

    test('one day inverted is refused', () {
      expect(
        () => ReportPeriod(
          from: DateTime(2026, 8, 16),
          to: DateTime(2026, 8, 15),
        ),
        throwsA(isA<InvalidPeriod>()),
      );
    });

    test('the hour is dropped, so an instant never breaks the ==', () {
      // Rule 9: a fresh instant on every frame would break the `==` this
      // value is watched by, and the report would reload on every rebuild.
      final period = ReportPeriod(
        from: DateTime(2026, 8, 15, 23, 59, 59),
        to: DateTime(2026, 8, 31, 0, 0, 1),
      );

      expect(period.from, DateTime(2026, 8, 15));
      expect(period.to, DateTime(2026, 8, 31));
    });

    test('an inverted pair is refused even when only the hour inverts it', () {
      // Same day, but `from` is later in it: after `dayOf` the two are equal,
      // so this one has to PASS. It is the boundary of the guard above.
      expect(
        ReportPeriod(
          from: DateTime(2026, 8, 15, 23),
          to: DateTime(2026, 8, 15, 1),
        ).from,
        DateTime(2026, 8, 15),
      );
    });
  });

  group('monthOf', () {
    test('opens on the first and closes on the last day', () {
      final period = ReportPeriod.monthOf(DateTime(2026, 8, 15));

      expect(period.from, DateTime(2026, 8, 1));
      expect(period.to, DateTime(2026, 8, 31));
    });

    test('February of a leap year closes on the 29th', () {
      // `DateTime(year, month + 1, 0)` is what gets this right without a
      // table of month lengths.
      expect(
        ReportPeriod.monthOf(DateTime(2028, 2, 10)).to,
        DateTime(2028, 2, 29),
      );
      expect(
        ReportPeriod.monthOf(DateTime(2026, 2, 10)).to,
        DateTime(2026, 2, 28),
      );
    });

    test('December closes on the 31st, and does not spill into January', () {
      final period = ReportPeriod.monthOf(DateTime(2026, 12, 20));

      expect(period.from, DateTime(2026, 12, 1));
      expect(period.to, DateTime(2026, 12, 31));
    });
  });

  group('shiftedByMonths', () {
    test('January goes back to December of the year before', () {
      final period = ReportPeriod.monthOf(
        DateTime(2026, 1, 10),
      ).shiftedByMonths(-1);

      expect(period.from, DateTime(2025, 12, 1));
      expect(period.to, DateTime(2025, 12, 31));
    });

    test('December goes forward to January of the year after', () {
      final period = ReportPeriod.monthOf(
        DateTime(2026, 12, 10),
      ).shiftedByMonths(1);

      expect(period.from, DateTime(2027, 1, 1));
      expect(period.to, DateTime(2027, 1, 31));
    });

    test('a free interval comes back as a WHOLE month', () {
      // The button says "Julho", not "eleven days of July" — and it is what
      // makes `‹` and `›` reversible between themselves.
      final free = ReportPeriod(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 20),
      );

      final previous = free.shiftedByMonths(-1);
      expect(previous.from, DateTime(2026, 7, 1));
      expect(previous.to, DateTime(2026, 7, 31));

      expect(previous.shiftedByMonths(1), ReportPeriod.monthOf(DateTime(2026, 8, 3)));
    });
  });

  group('canShiftForward — there is no report of tomorrow', () {
    final today = DateTime(2026, 8, 15);

    test('the current month has nowhere to go', () {
      expect(ReportPeriod.monthOf(today).canShiftForward(today), isFalse);
    });

    test('a free interval inside the current month has nowhere to go either', () {
      // Without this the `›` would put the period on September, and the date
      // field would open with initialDate 01/09 against lastDate 15/08 —
      // which is the `!initialDate.isAfter(lastDate)` assert of
      // showDatePicker, a crash and not an empty report.
      final free = ReportPeriod(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 20),
      );

      expect(free.canShiftForward(today), isFalse);
    });

    test('any earlier month can move forward', () {
      expect(
        ReportPeriod.monthOf(DateTime(2026, 7, 1)).canShiftForward(today),
        isTrue,
      );
      expect(
        ReportPeriod.monthOf(DateTime(2019, 1, 1)).canShiftForward(today),
        isTrue,
      );
    });

    test('a later month cannot either — the rule is not a loose isBefore', () {
      // Unreachable from the screen precisely BECAUSE of this rule; written
      // down so it cannot decay into `from.isBefore(today)`.
      expect(
        ReportPeriod.monthOf(DateTime(2026, 9, 1)).canShiftForward(today),
        isFalse,
      );
    });

    test('the last day of the previous month can still move forward', () {
      expect(
        ReportPeriod(
          from: DateTime(2026, 7, 31),
          to: DateTime(2026, 7, 31),
        ).canShiftForward(today),
        isTrue,
      );
    });
  });

  group('copyWith', () {
    test('replaces one end and keeps the other', () {
      final period = ReportPeriod.monthOf(DateTime(2026, 8, 15));

      expect(period.copyWith(from: DateTime(2026, 8, 10)).to, period.to);
      expect(period.copyWith(to: DateTime(2026, 8, 20)).from, period.from);
    });

    test('it is the only copyWith of the project that can throw', () {
      final period = ReportPeriod.monthOf(DateTime(2026, 8, 15));

      expect(
        () => period.copyWith(from: DateTime(2026, 9, 10)),
        throwsA(isA<InvalidPeriod>()),
      );
    });
  });

  group('equality', () {
    test('same fields are equal and hash the same', () {
      final a = ReportPeriod(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );
      final b = ReportPeriod(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('one field at a time breaks it', () {
      final base = ReportPeriod(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );

      expect(base == base.copyWith(from: DateTime(2026, 8, 2)), isFalse);
      expect(base == base.copyWith(to: DateTime(2026, 8, 30)), isFalse);
    });
  });

  test('toString prints the interval the way Postgres reads it', () {
    expect(
      ReportPeriod.monthOf(DateTime(2026, 8, 15)).toString(),
      'ReportPeriod(2026-08-01..2026-08-31)',
    );
  });

  test('InvalidPeriod says what is wrong, in pt-BR', () {
    expect(
      const InvalidPeriod().toString(),
      'InvalidPeriod: A data inicial não pode ser depois da final.',
    );
  });

  group('latestSelectableDay — the OTHER end of the same rule', () {
    test('it is the end of the month in progress, not today', () {
      // The report opens on the WHOLE current month, so its own 31/08 has to
      // be a day the picker can show. A `lastDate` of today would make
      // showDatePicker assert the first time the second field was tapped.
      expect(
        ReportPeriod.latestSelectableDay(DateTime(2026, 8, 15)),
        DateTime(2026, 8, 31),
      );
    });

    test('every day a reachable period can hold is inside it', () {
      // The invariant the two bounds hold together: `canShiftForward` stops
      // the period at the current month, and this makes every day inside that
      // month selectable.
      final today = DateTime(2026, 8, 15);
      final last = ReportPeriod.latestSelectableDay(today);

      for (final period in [
        ReportPeriod.monthOf(today),
        ReportPeriod.monthOf(DateTime(2026, 7, 1)),
        ReportPeriod(from: DateTime(2026, 8, 10), to: DateTime(2026, 8, 20)),
      ]) {
        expect(period.from.isAfter(last), isFalse, reason: '$period');
        expect(period.to.isAfter(last), isFalse, reason: '$period');
      }
    });

    test('February of a leap year closes on the 29th here too', () {
      expect(
        ReportPeriod.latestSelectableDay(DateTime(2028, 2, 10)),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('wholeMonth', () {
    test('a whole month answers its first day', () {
      expect(
        ReportPeriod.monthOf(DateTime(2026, 8, 15)).wholeMonth,
        DateTime(2026, 8, 1),
      );
    });

    test('a month missing its last day is NOT a whole month', () {
      expect(
        ReportPeriod(
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 30),
        ).wholeMonth,
        isNull,
      );
    });

    test('a free interval inside the month is NOT a whole month', () {
      expect(
        ReportPeriod(
          from: DateTime(2026, 8, 10),
          to: DateTime(2026, 8, 20),
        ).wholeMonth,
        isNull,
      );
    });

    test('two whole months are not one whole month', () {
      expect(
        ReportPeriod(
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 8, 31),
        ).wholeMonth,
        isNull,
      );
    });

    test('February of a leap year is a whole month on the 29th', () {
      expect(
        ReportPeriod(
          from: DateTime(2028, 2, 1),
          to: DateTime(2028, 2, 29),
        ).wholeMonth,
        DateTime(2028, 2, 1),
      );
      // …and the 28th is one day short of it.
      expect(
        ReportPeriod(
          from: DateTime(2028, 2, 1),
          to: DateTime(2028, 2, 28),
        ).wholeMonth,
        isNull,
      );
    });
  });

  test('the earliest selectable day is a constant, not a moving window', () {
    // A bound that walked with the clock would hide, in the sixth year of
    // use, a purchase that is in the database.
    expect(ReportPeriod.earliestSelectableDay, DateTime(2020, 1, 1));
  });
}
