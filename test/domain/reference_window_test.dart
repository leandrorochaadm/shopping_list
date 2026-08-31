import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/reference_window.dart';
import 'package:shopping_list/domain/models/report_period.dart';

void main() {
  group('rollingWindowStart', () {
    test('walks back three CALENDAR months, not ninety days', () {
      expect(rollingWindowStart(DateTime(2026, 8, 28)), DateTime(2026, 5, 28));
      expect(rollingWindowStart(DateTime(2026, 2, 15)), DateTime(2025, 11, 15));
    });

    test('a day the target month does not have normalizes forward', () {
      expect(rollingWindowStart(DateTime(2026, 5, 31)), DateTime(2026, 3, 3));
    });

    test('the month in progress is INSIDE the window', () {
      // The rolling window ends today, so every purchase of this month is in
      // it — that is the whole difference from the closed window of H17.
      final today = DateTime(2026, 8, 15);
      expect(rollingWindowStart(today).isBefore(DateTime(2026, 8, 1)), isTrue);
    });

    test('the window is three months wide, and the number is the constant', () {
      // The sentence of no screen repeats the 3: it derives from here
      // (rule 6).
      expect(referenceWindowMonths, 3);
      final today = DateTime(2026, 8, 15);
      expect(
        rollingWindowStart(today),
        DateTime(today.year, today.month - referenceWindowMonths, today.day),
      );
    });
  });

  group('closedWindow', () {
    test('is the three CLOSED months before the one in progress', () {
      // August 2026: May, June and July. It is the written confirmation of
      // 26/08/2026 — "em agosto, a média vem de maio, junho e julho".
      expect(
        closedWindow(DateTime(2026, 8, 15)),
        ReportPeriod(from: DateTime(2026, 5, 1), to: DateTime(2026, 7, 31)),
      );
    });

    test('crosses the turn of the year backwards', () {
      expect(
        closedWindow(DateTime(2026, 1, 20)),
        ReportPeriod(from: DateTime(2025, 10, 1), to: DateTime(2025, 12, 31)),
      );
    });

    test('ends on the real last day of February, never on the 31st', () {
      // `DateTime(y, m, 0)` is day ZERO of the month, which Dart normalizes
      // into the last day of the previous one — that is what gets February
      // right with no table.
      expect(
        closedWindow(DateTime(2026, 3, 31)),
        ReportPeriod(from: DateTime(2025, 12, 1), to: DateTime(2026, 2, 28)),
      );
      // And the leap year, which is the case a table would get wrong.
      expect(closedWindow(DateTime(2024, 3, 10)).to, DateTime(2024, 2, 29));
    });

    test('the month in progress is OUTSIDE it — the whole point', () {
      // If August entered August's own average, every purchase would raise
      // its own target and "falta comprar" would never reach zero.
      final today = DateTime(2026, 8, 15);
      final window = closedWindow(today);
      expect(window.to.isBefore(DateTime(2026, 8, 1)), isTrue);
      expect(window.to.isBefore(today), isTrue);
    });

    test('the day of the month does not move it', () {
      // It is built from `firstDayOfMonth`, so the 1st and the 31st of the
      // same month answer the same window — a window that walked with the day
      // would change the average mid-month.
      expect(
        closedWindow(DateTime(2026, 8, 1)),
        closedWindow(DateTime(2026, 8, 31)),
      );
    });

    test('is three months wide, and the number is the constant', () {
      final window = closedWindow(DateTime(2026, 8, 15));
      final months =
          (window.to.year - window.from.year) * 12 +
          (window.to.month - window.from.month) +
          1;
      expect(months, referenceWindowMonths);
    });

    test('the two windows never mix: the closed one ends before the rolling '
        'one starts is NOT true — they overlap, and only the month in '
        'progress separates them', () {
      // Written as a case because the temptation is to think one is a subset
      // of the other. In August 2026 the rolling window is 15/05 → hoje and
      // the closed one is 01/05 → 31/07: they share May, June and July, and
      // the ONLY difference that matters is August.
      final today = DateTime(2026, 8, 15);
      expect(rollingWindowStart(today), DateTime(2026, 5, 15));
      expect(closedWindow(today).from, DateTime(2026, 5, 1));
      expect(closedWindow(today).to, DateTime(2026, 7, 31));
    });
  });
}
