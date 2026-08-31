import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/period_report.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/report_period.dart';

/// The reads of screen 5. I/O and nothing else: ordering, dividing and
/// building the tree is the domain's job.
abstract class ReportRepository {
  /// The three aggregations of the interval, in a single instant. The interval
  /// is decided in the ViewModel, off the phone's clock: no `now()` in SQL
  /// (decision 7).
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period);

  /// **H16** — every purchase of the rolling window, flat: one line per
  /// (leaf, store, purchase), with the product, the category and the store
  /// embedded.
  ///
  /// [since] is computed in the ViewModel, off the phone's clock: no `now()`
  /// and no `current_date` in SQL (decision 7).
  ///
  /// **It reduces nothing.** Choosing the most recent purchase of each store
  /// is a rule, and a rule belongs to the domain (`buildComparison`) — the
  /// repository only does I/O (rule 3).
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since);
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => throw UnimplementedError(
    'reportRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);
