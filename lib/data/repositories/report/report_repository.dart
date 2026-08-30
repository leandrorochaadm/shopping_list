import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/period_report.dart';
import '../../../domain/models/report_period.dart';

/// The reads of screen 5. I/O and nothing else: ordering, dividing and
/// building the tree is the domain's job.
abstract class ReportRepository {
  /// The three aggregations of the interval, in a single instant. The interval
  /// is decided in the ViewModel, off the phone's clock: no `now()` in SQL
  /// (decision 7).
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period);
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => throw UnimplementedError(
    'reportRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);
