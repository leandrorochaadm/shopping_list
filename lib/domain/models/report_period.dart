import 'calendar_day.dart';

/// The interval the report adds up — two calendar days, with no hour and no
/// time zone, exactly as `purchase_date` is in Postgres.
///
/// It is an entity and not a loose pair of `DateTime` because it carries
/// THREE rules: the first day never comes after the last, the current month is
/// a named case, and "the previous month" is a calendar computation the screen
/// must not redo.
final class ReportPeriod {
  /// **May throw [InvalidPeriod]** — this is the only validation gate, and
  /// [copyWith] goes through it too.
  factory ReportPeriod({required DateTime from, required DateTime to}) {
    final start = dayOf(from);
    final end = dayOf(to);
    if (start.isAfter(end)) throw const InvalidPeriod();
    return ReportPeriod._(from: start, to: end);
  }

  const ReportPeriod._({required this.from, required this.to});

  /// The calendar month [day] belongs to, from the 1st to the last day.
  ///
  /// `DateTime(year, month + 1, 0)` is day ZERO of the next month, which Dart
  /// normalizes into the last day of this one — that is how February of a leap
  /// year gets itself right without a table.
  factory ReportPeriod.monthOf(DateTime day) => ReportPeriod(
    from: DateTime(day.year, day.month, 1),
    to: DateTime(day.year, day.month + 1, 0),
  );

  /// The first day the two date fields offer.
  ///
  /// `showDatePicker` REQUIRES `firstDate` and `lastDate`, and the honest
  /// bound — the day of the oldest purchase — would cost one more query before
  /// the screen could draw. So it is a constant, and being a rule's number it
  /// lives here and not inside the widget (rule 6). The `lastDate` is the
  /// "today" the `ReportPeriodNotifier` already holds: there is no report of
  /// tomorrow.
  ///
  /// 2020 and not "today − 5 years": a bound that walks with the clock would
  /// hide, in the sixth year of use, a purchase that is in the database.
  static final earliestSelectableDay = DateTime(2020, 1, 1);

  /// The last day the two date fields offer: **the end of the month in
  /// progress**, not [today].
  ///
  /// It is not "no report of tomorrow" contradicting itself. The report OPENS
  /// on the whole month in progress, which by definition runs past today, so
  /// its own `to` — 31/08 with a today of 15/08 — has to be a day the picker
  /// can show. [canShiftForward] is what stops the period from ever leaving
  /// this month; this is what makes every day INSIDE it reachable.
  ///
  /// And it is not cosmetic either: `showDatePicker` asserts
  /// `!initialDate.isAfter(lastDate)`, so a `lastDate` of today would bring
  /// the screen down the first time someone tapped the second field.
  static DateTime latestSelectableDay(DateTime today) =>
      ReportPeriod.monthOf(today).to;

  final DateTime from;
  final DateTime to;

  /// The whole month [delta] months away from the month of [from].
  /// `DateTime(2026, 13, 1)` is January 2027 — Dart normalizes it.
  ///
  /// **It always returns a WHOLE month, even starting from a free interval**:
  /// from 10/08 to 20/08, `shiftedByMonths(-1)` is July, the 1st to the 31st.
  /// That is what the button promises — it says "Julho", not "eleven days of
  /// July" — and it is what makes `‹` and `›` always reversible.
  ReportPeriod shiftedByMonths(int delta) =>
      ReportPeriod.monthOf(DateTime(from.year, from.month + delta, 1));

  /// Whether `›` has anywhere to go: **there is no report of tomorrow**.
  ///
  /// The View ASKS this (rule 11); it does not write
  /// `from.year == today.year && from.month == today.month` inside `build()`,
  /// which is a compound `if` over an entity's fields and is the architecture
  /// bug that rule names.
  ///
  /// And it is not cosmetic: it is what guarantees `from <= today`, which is
  /// the precondition of `showDatePicker` — without it the date field opens
  /// with `initialDate` after `lastDate` and the assert brings the screen
  /// down.
  bool canShiftForward(DateTime today) =>
      from.isBefore(ReportPeriod.monthOf(today).from);

  /// **May throw [InvalidPeriod]** — the factory above is what validates, and
  /// this is the only `copyWith` in the project that is not total. Its two
  /// callers are `setFrom` and `setTo`, and both already wrap it in a `try`;
  /// whoever writes a third has to do the same.
  ReportPeriod copyWith({DateTime? from, DateTime? to}) =>
      ReportPeriod(from: from ?? this.from, to: to ?? this.to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportPeriod && other.from == from && other.to == to);

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() =>
      'ReportPeriod(${encodeCalendarDay(from)}..${encodeCalendarDay(to)})';
}

/// The first day comes after the last one. pt-BR: it is read on screen.
final class InvalidPeriod implements Exception {
  const InvalidPeriod();

  String get message => 'A data inicial não pode ser depois da final.';

  @override
  String toString() => 'InvalidPeriod: $message';
}
