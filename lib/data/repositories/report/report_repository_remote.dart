import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/period_report.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/price_reference.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/store.dart';
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

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    try {
      // **No migration for this** (decision D-q). The `handoff §fronteira SQL`
      // asks for "preço mais recente por mercado no intervalo", and a
      // `distinct on (product_id, store_id)` would do it in SQL — but the
      // precedent is `fetchRecentItems`, which picks the most recent purchase
      // of each leaf in Dart for the very same reason; the "Tipo inteiro"
      // view then comes free out of the same `IList`; and this runs today,
      // without waiting for a hosted database.
      //
      // ONE select. The product embed is EXACTLY the nested shape
      // `ProductOption.fromJson` already reads — the same as `fetchDetail` —,
      // and it is what brings every line back complete without a second trip
      // to the catalog.
      //
      // `category!inner ( id, name )` goes one level deeper than the embed of
      // screen 3 because the picker of this tab groups by CATEGORY, and
      // `ProductType` carries the `category_id` but not the name. The extra
      // key is ignored by `ProductType.fromJson` and read here, beside it.
      //
      // And the store comes with `active` ALONGSIDE, which is no detail:
      // `Store.fromJson` does `json['active'] as bool? ?? true`, so a
      // `store ( id, name )` brings every shop back as active. The fake has
      // the Mercearia do Zé deactivated on purpose, and without this column
      // the SAME shop would come back with a different `==` from the fake and
      // from the database — the asymmetry no test catches, because the screen
      // only writes the name.
      //
      // No `active` filter anywhere: a leaf, a registration or a store
      // deactivated after the purchase stays in the report (requirement 16).
      // And no `order`: `order` over an embedded table orders the CHILDREN,
      // not the parents — whoever orders is `buildComparison`, in Dart.
      final rows = await _client
          .from('purchase_item')
          .select('''
quantity_in_base_unit, total_paid,
purchase!inner ( purchase_date, store!inner ( id, name, active ) ),
product!inner (
  *, product_registration!inner (
    *, product_type!inner ( *, category!inner ( id, name ) ), brand ( * )
  )
)
''')
          .gte('purchase.purchase_date', encodeCalendarDay(since));

      return rows.map((row) {
        final purchase = row['purchase'] as Map<String, dynamic>;
        final product = row['product'] as Map<String, dynamic>;
        final type =
            (product['product_registration']
                    as Map<String, dynamic>)['product_type']
                as Map<String, dynamic>;
        final category = type['category'] as Map<String, dynamic>;

        return PriceQuote(
          option: ProductOption.fromJson(product),
          categoryId: category['id'] as String,
          categoryName: category['name'] as String,
          store: Store.fromJson(purchase['store'] as Map<String, dynamic>),
          price: PriceReference(
            paid: Money.fromJson(row['total_paid']),
            quantityInBaseUnit: (row['quantity_in_base_unit'] as num).toInt(),
            purchasedOn: decodeCalendarDay(
              purchase['purchase_date'] as String,
            ),
          ),
        );
      }).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
