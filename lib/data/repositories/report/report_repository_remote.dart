import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/period_report.dart';
import '../../../domain/models/report_period.dart';
import '../../services/supabase_error.dart';
import 'report_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// of PostgREST arrives as "status 23505", falls into the `>= 500` arm of
/// AppFailure and tells the user the server is down.
final class ReportRepositoryRemote implements ReportRepository {
  ReportRepositoryRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    try {
      // ONE call for the three aggregations. Three calls would be three
      // different instants of the database, and the total of the period would
      // stop matching the categories it is supposed to be the sum of.
      final response = await _client.rpc<Map<String, dynamic>>(
        'report_period',
        params: {
          'p_from': encodeCalendarDay(period.from),
          'p_to': encodeCalendarDay(period.to),
        },
      );

      return PeriodReport.fromJson(response);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
