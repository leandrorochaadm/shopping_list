import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';
import '../../services/supabase_error.dart';
import 'spending_cap_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// of PostgREST arrives as "status 23505", falls into the `>= 500` arm of
/// AppFailure and tells the user the server is down.
final class SpendingCapRepositoryRemote implements SpendingCapRepository {
  SpendingCapRepositoryRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(
    IList<ReportPeriod> months,
  ) async {
    try {
      // ONE call for every month asked. The correction that moves a purchase
      // from August to September has to re-evaluate both, and two calls would
      // be two different instants of the database.
      //
      // Both dates go up from the phone's clock: no `now()` and no
      // `current_date` in SQL (decision 7).
      final response = await _client.rpc<List<dynamic>>(
        'cap_states',
        params: {
          'p_months': [
            for (final month in months)
              {
                'month': encodeCalendarDay(month.from),
                'last_day': encodeCalendarDay(month.to),
              },
          ],
        },
      );

      return response
          .cast<Map<String, dynamic>>()
          .map(MonthCapStatus.fromJson)
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> save({
    required SpendingCap cap,
    required CapAlerts alerts,
  }) async {
    try {
      // ONE transaction: the cap row, the month's two marks cleared, and the
      // state `evaluateSpendingCap` decided written over them. Half of that
      // done would leave a month that can never warn again.
      await _client.rpc<void>(
        'save_spending_cap',
        params: {
          'p_amount': cap.amount.toJson(),
          'p_effective_from': encodeCalendarDay(cap.effectiveFrom),
          'p_alerts': [alerts.toJson()],
        },
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
