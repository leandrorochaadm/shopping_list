import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/reference_window.dart';

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
}
