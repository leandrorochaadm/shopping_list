import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/report_period.dart';
import '../../../domain/models/type_consumption.dart';

/// The single read behind screens 2 and 6. I/O and nothing else: the divisor,
/// the division, the rounding and the ordering are the domain's job.
///
/// A contract of its own and not a third method of `ReportRepository`: the
/// question is one of CONSUMPTION, not of price; the window is the closed one,
/// not the rolling one; and one file per question is what the seven other
/// repositories do.
abstract class ConsumptionRepository {
  /// Consumption per type in the two intervals, plus the day each type was
  /// first ever bought — in ONE call, at ONE instant of the database.
  ///
  /// Two calls would be two instants, and a purchase registered in between
  /// would make "falta comprar" disagree with the average it is subtracted
  /// from. Both intervals are decided in the ViewModel, off the phone's clock:
  /// no `now()` in SQL (decision 7).
  ///
  /// Takes [ReportPeriod] twice and not four loose dates: a month IS a period,
  /// the closed window IS a period, and `ReportPeriod` already refuses an
  /// inverted interval.
  ///
  /// **It filters nothing and divides nothing.** A deactivated type comes back
  /// flagged, and whoever discards it is `monthlyAverages`, in the domain
  /// (decision E-e).
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  });
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final consumptionRepositoryProvider = Provider<ConsumptionRepository>(
  (ref) => throw UnimplementedError(
    'consumptionRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);
