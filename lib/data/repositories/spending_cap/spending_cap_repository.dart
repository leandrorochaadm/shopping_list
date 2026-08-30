import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';

/// The cap's I/O — reading where a month stands and writing a new cap.
/// It decides nothing: `evaluateSpendingCap` already decided, in the domain.
abstract class SpendingCapRepository {
  /// The cap in force, the spending and the marks, for each month asked.
  ///
  /// Takes [ReportPeriod] and not a loose pair of dates: a month IS a period,
  /// `ReportPeriod.monthOf` already computes the last day (February of a leap
  /// year included), and a second interval type would be the same rule
  /// written twice.
  ///
  /// Always answers ONE entry per month asked — **ordered by month, not by
  /// the order asked**: `cap_states` closes with `order by m.month`. The
  /// correction, which asks for two, matches by `MonthCapStatus.month` and
  /// never by index.
  Future<IList<MonthCapStatus>> fetchStatuses(IList<ReportPeriod> months);

  /// The new cap and the rearm, in ONE transaction: writing the cap and
  /// clearing the month's marks cannot end up half done.
  Future<void> save({required SpendingCap cap, required CapAlerts alerts});
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final spendingCapRepositoryProvider = Provider<SpendingCapRepository>(
  (ref) => throw UnimplementedError(
    'spendingCapRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);
