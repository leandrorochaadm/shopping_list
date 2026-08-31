import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/purchase_summary.dart';
import '../../../domain/models/same_day_alert.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/write_off_undo.dart';
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
            'purchase!inner ( purchase_date ), '
            // The type of each line, with NO filter on `active`: a leaf
            // deactivated in the middle of the window KEEPS counting towards
            // the type's average — deactivating takes it off the shelf, it
            // does not rewrite the history (requirement 16). Crossing with
            // the catalog would not do: `fetchProductOptions` filters
            // `active = true`.
            'product!inner ( product_registration!inner ( product_type_id ) )',
          )
          .gte('purchase.purchase_date', encodeCalendarDay(since));

      return rows.map((row) {
        final purchase = row['purchase'] as Map<String, dynamic>;
        final registration =
            (row['product'] as Map<String, dynamic>)['product_registration']
                as Map<String, dynamic>;
        return PurchaseHistoryEntry(
          productId: row['product_id'] as String,
          productTypeId: registration['product_type_id'] as String,
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
          // The month's two marks, written INSIDE this same transaction: a
          // second write after it could commit the purchase and lose the
          // mark, and the alert would then fire twice.
          'p_cap_alerts': [
            for (final alerts in submission.capAlerts) alerts.toJson(),
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

  @override
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  }) async {
    try {
      // `range` in PostgREST is INCLUSIVE at both ends — it becomes
      // `offset=<from>&limit=<to − from + 1>` — so asking for `offset + limit`
      // brings `limit + 1` rows. The extra one is dropped, and its existence
      // IS the answer to "há próxima?" with no second query.
      final rows = await _client
          .from('purchase')
          .select(
            'id, purchase_date, registered_by, store ( name ), '
            'purchase_item ( total_paid )',
          )
          .order('purchase_date', ascending: false)
          // The tiebreaker, and it is what the new index is for: two
          // purchases of the same day with no stable order swap places
          // between one page and the next.
          .order('created_at', ascending: false)
          .range(offset, offset + limit);

      final all = rows.map(PurchaseSummary.fromJson).toIList();
      return PurchaseHistoryPage(
        purchases: all.length > limit ? all.sublist(0, limit) : all,
        hasMore: all.length > limit,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<PurchaseDetail> fetchDetail(String purchaseId) async {
    try {
      // ONE select, with the trail embedded INSIDE the item. Not two:
      // `list_write_off` has no purchase column, so filtering it by purchase
      // would mean building an `in.(…)` out of the ids the first select
      // returned — a second round trip that depends on the first, in the
      // middle of opening a screen.
      //
      // `fulfills` does not come back (it is not a column) and the undo does
      // not need it: it DERIVES it (D6).
      final row = await _client
          .from('purchase')
          .select('''
id, purchase_date, store_id, registered_by,
purchase_item (
  id, product_id, quantity, quantity_in_base_unit, total_paid,
  product ( *, product_registration ( *, product_type ( * ), brand ( * ) ) ),
  list_write_off ( * )
)
''')
          .eq('id', purchaseId)
          .single();

      final rawItems =
          (row['purchase_item'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];

      final items = <PurchaseItem>[];
      final trail = <ListWriteOff>[];
      for (final raw in rawItems) {
        final id = raw['id'] as String;
        items.add(
          PurchaseItem(
            id: id,
            // The embed is exactly the nested shape `ProductOption.fromJson`
            // reads, which is what makes every line come back complete —
            // with no view around it, and with no second query to the catalog.
            option: ProductOption.fromJson(
              raw['product'] as Map<String, dynamic>,
            ),
            quantity: (raw['quantity'] as num).toInt(),
            paid: Money.fromJson(raw['total_paid']),
          ),
        );
        for (final off
            in (raw['list_write_off'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[]) {
          trail.add(
            ListWriteOff(
              purchaseItemId: id,
              shoppingListItemId: off['shopping_list_item_id'] as String,
              quantityWrittenOff:
                  (off['quantity_written_off'] as num?)?.toInt() ?? 0,
              clearedNotFound: off['cleared_not_found'] as bool? ?? false,
            ),
          );
        }
      }

      return PurchaseDetail(
        purchase: Purchase(
          id: row['id'] as String,
          date: decodeCalendarDay(row['purchase_date'] as String),
          storeId: row['store_id'] as String,
          registeredBy: row['registered_by'] as String? ?? '',
          items: items.toIList(),
        ),
        items: items.toIList(),
        trail: trail.toIList(),
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> correct({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    try {
      await _client.rpc<void>(
        'update_purchase',
        params: {
          // Three columns only: `registered_by` is a historical fact a
          // correction never rewrites.
          'p_purchase': purchase.toCorrectionJson(),
          'p_items': [for (final item in purchase.items) item.toJson()],
          'p_write_offs': [for (final off in writeOffs) off.toJson()],
          // Each entry sends `fulfilled_on` PRESENT and null when the item
          // reopens — an omitted key would reopen nothing, and in silence.
          'p_restored': [for (final entry in restored) entry.toJson()],
          // TWO months when the correction moved the purchase across the turn
          // of one: the month it left may have rearmed, and the month it
          // arrived in may have crossed a cut.
          'p_cap_alerts': [for (final alerts in capAlerts) alerts.toJson()],
        },
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> delete({
    required String purchaseId,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    try {
      await _client.rpc<void>(
        'delete_purchase',
        params: {
          'p_purchase_id': purchaseId,
          'p_restored': [for (final entry in restored) entry.toJson()],
          // Deleting only ever DROPS the month, so what travels here is the
          // rearm — and it commits with the deletion for the same reason.
          'p_cap_alerts': [for (final alerts in capAlerts) alerts.toJson()],
        },
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<SameDayAlert>> fetchSameDayTypes({
    required DateTime date,
    required String registeredBy,
    required ISet<String> productTypeIds,
  }) async {
    try {
      // A function and not a PostgREST embed on purpose: the filter falls on
      // `product_registration.product_type_id`, THREE levels down the embed
      // chain, and a third-level filter is exactly where PostgREST's syntax
      // stops being obvious.
      final response = await _client.rpc<List<dynamic>>(
        'same_day_types',
        params: {
          'p_date': encodeCalendarDay(date),
          'p_registered_by': registeredBy,
          'p_type_ids': productTypeIds.toList(),
        },
      );

      return response
          .cast<Map<String, dynamic>>()
          // The day comes from HERE and not from the query: it is the same
          // day that was asked about, and the sentence needs it to choose
          // between "hoje" and "no dia 25/08".
          .map((row) => SameDayAlert.fromJson(row, date))
          .toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}
