import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../services/supabase_error.dart';
import 'purchase_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// of PostgREST arrives as "status 23505", falls into the `>= 500` arm of
/// AppFailure and tells the user the server is down.
final class PurchaseRepositoryRemote implements PurchaseRepository {
  PurchaseRepositoryRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    try {
      // The embeds give the picker the product's NAME without one round trip
      // per leaf. `!inner` on the registration and on the type because every
      // leaf has both, and a left join would bring a null where `fromJson`
      // expects an object — but `brand(*)` WITHOUT it, because a null brand
      // is a value (decision B2) and `!inner` would make the ground beef
      // disappear from the picker.
      final rows = await _client
          .from('product')
          .select(
            '*, product_registration!inner('
            '*, product_type!inner ( * ), brand ( * ))',
          )
          .eq('active', true)
          // A deactivated registration takes its leaves with it: they are not
          // on the shelf any more, and screen 3 is not the place to find that
          // out.
          .eq('product_registration.active', true);

      return rows.map(ProductOption.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<PurchaseHistoryEntry>> fetchRecentItems(DateTime since) async {
    try {
      // The date filter is on the PARENT table, which is what `!inner` makes
      // possible. And there is no `order` here on purpose: `order` over an
      // embedded table orders the CHILDREN, not the parents — the ordering by
      // date happens in Dart, while the PriceReference of each leaf is built.
      final rows = await _client
          .from('purchase_item')
          .select(
            'product_id, quantity_in_base_unit, total_paid, '
            'purchase!inner ( purchase_date )',
          )
          .gte('purchase.purchase_date', encodeCalendarDay(since));

      return rows.map((row) {
        final purchase = row['purchase'] as Map<String, dynamic>;
        return (
          productId: row['product_id'] as String,
          quantityInBaseUnit: (row['quantity_in_base_unit'] as num).toInt(),
          paid: Money.fromJson(row['total_paid']),
          purchasedOn: decodeCalendarDay(purchase['purchase_date'] as String),
        );
      }).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<bool> save(PurchaseSubmission submission) async {
    try {
      // ONE call, ONE transaction. A purchase of twenty items is a `purchase`
      // row, twenty `purchase_item` rows, up to twenty `list_write_off` rows
      // and two updates on the list — and PostgREST cannot write that
      // atomically.
      final response = await _client.rpc<Map<String, dynamic>>(
        'create_purchase',
        params: {
          'p_purchase': submission.purchase.toJson(),
          'p_items': [
            for (final item in submission.purchase.items) item.toJson(),
          ],
          'p_write_offs': [
            for (final writeOff in submission.writeOffs) writeOff.toJson(),
          ],
        },
      );

      // True means the purchase was already registered — H8's resend that
      // arrived twice. Not an error, and not a second purchase.
      return response['already_registered'] as bool? ?? false;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
