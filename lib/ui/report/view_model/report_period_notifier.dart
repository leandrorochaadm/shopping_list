import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/report_period.dart';

/// The interval screen 5 is reading — and **the one place in this feature
/// where the clock enters the system** (rule 9 and decision 13).
///
/// A `Notifier<ReportPeriod>` and not a piece of the report's own state: the
/// report is what the period PRODUCES, and merging the two would make every
/// change of a date field pass through the loading state of the query it has
/// not made yet.
///
/// [today] is not decoration: it is the same seam
/// `ShoppingListViewModel.add(..., today)` and `EditPurchaseViewModel` already
/// have, and it is what lets a test pin the instant with
/// `reportPeriodProvider.overrideWith(() => ReportPeriodNotifier(today: …))`.
/// Without it the cases that read `‹ Julho` and `Agosto/2026` pass in August
/// and fail in September, on a CI nobody touched.
final class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  ReportPeriodNotifier({DateTime? today})
    : today = dayOf(today ?? DateTime.now());

  /// The phone's day, rounded (rule 9), kept as a field because the state
  /// itself does not carry it.
  ///
  /// The [PeriodBar] needs it twice — for the `lastDate` of both date fields
  /// and to disable the `›` — and the public state is the [ReportPeriod],
  /// which does not know what day it is. A provider of its own was considered
  /// and refused: it would be one more override in every test, and H13 can
  /// read this same getter.
  final DateTime today;

  @override
  ReportPeriod build() => ReportPeriod.monthOf(today);

  /// The first date field. Returns null on success, or the pt-BR sentence for
  /// the SnackBar — two outcomes with no payload, so `String?` (rule 16).
  String? setFrom(DateTime from) => _write(() => state.copyWith(from: from));

  /// The second date field, same shape.
  String? setTo(DateTime to) => _write(() => state.copyWith(to: to));

  /// `‹` and `›`. It cannot produce an inverted interval — the shift always
  /// returns a whole month — so it has nothing to report.
  void shiftMonth(int delta) => state = state.shiftedByMonths(delta);

  /// The only `copyWith` of the project that can throw is wrapped exactly
  /// here, in the two places that call it.
  String? _write(ReportPeriod Function() build) {
    try {
      state = build();
      return null;
    } on InvalidPeriod catch (e) {
      return e.message;
    }
  }
}

/// No `retry`: there is no future here to repeat.
final reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
      ReportPeriodNotifier.new,
    );
