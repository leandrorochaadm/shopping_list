import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/type_consumption.dart';
import '../../services/supabase_error.dart';
import 'consumption_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// of PostgREST arrives as "status 23505", falls into the `>= 500` arm of
/// AppFailure and tells the user the server is down.
final class ConsumptionRepositoryRemote implements ConsumptionRepository {
  ConsumptionRepositoryRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  }) async {
    try {
      // ONE call for both intervals. Two calls would be two different instants
      // of the database, and a purchase registered in between would make
      // "falta comprar" disagree with the average it is subtracted from.
      //
      // A function and not a `select` with an embed: the filter falls on
      // `product_registration.product_type_id`, THREE levels down the chain,
      // and the answer holds two conditional aggregations plus a `min()` with
      // no date filter at all — PostgREST expresses none of the three. It is
      // the same reason H14 became `same_day_types`.
      //
      // The four dates come from the ViewModel, off the phone's clock: no
      // `now()` and no `current_date` in SQL (decision 7).
      final response = await _client.rpc<List<dynamic>>(
        'type_consumption',
        params: {
          'p_window_from': encodeCalendarDay(window.from),
          'p_window_to': encodeCalendarDay(window.to),
          'p_month_from': encodeCalendarDay(month.from),
          'p_month_to': encodeCalendarDay(month.to),
        },
      );

      // No ordering and no filtering here: whoever orders is
      // `groupAveragesByCategory` and whoever drops the deactivated type is
      // `monthlyAverages` — both in the domain (rule 3 and decision E-e).
      return response
          .cast<Map<String, dynamic>>()
          .map(TypeConsumption.fromJson)
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
