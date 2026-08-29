import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/pending_changes.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../services/supabase_error.dart';
import 'shopping_list_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`.** Without it the SQLSTATE
/// of PostgREST arrives as "status 23505", falls into the `>= 500` arm of
/// AppFailure and tells the user the server is down.
final class ShoppingListRepositoryRemote implements ShoppingListRepository {
  ShoppingListRepositoryRemote(this._client);

  final SupabaseClient _client;

  static const _table = 'shopping_list_item';

  /// The PostgREST embed (D4), written ONCE — it is used by the fetch, the
  /// insert and the update, and three copies would diverge on the first new
  /// column. `alias:foreign_key ( ... )` resolves the relation through the
  /// foreign key, which is how `preferred_brand_id` and `product_type_id` can
  /// point at different tables with no ambiguity.
  static const _selection = '''
id, quantity, entered_on, picked, not_found, fulfilled_on, removed_on,
list_write_off ( quantity_written_off ),
product_type:product_type_id (
  id, name, category_id, base_unit, active,
  category:category_id ( id, name, active )
),
preferred_brand:preferred_brand_id ( id, name, active ),
preferred_product:preferred_product_id (
  id, product_registration_id, piece_count, piece_size, piece_size_unit,
  total_content, active
)
''';

  /// The ids THIS phone wrote and whose echo has not come back yet (D2).
  ///
  /// It is a COUNTER, not a `Set`: two taps on the same item's checkbox are
  /// two writes to the same row, and a `Set` would hold a single entry — the
  /// first echo would consume it and the second would pass as a change from
  /// the other phone. The banner would then talk about the change the person
  /// has just made, which is exactly the risk D2 exists to close.
  final Map<String, int> _ownWrites = {};

  RealtimeChannel? _channel;
  StreamController<ListChangeKind>? _controller;
  bool _wasSubscribed = false;

  void _expectEcho(String id) =>
      _ownWrites.update(id, (n) => n + 1, ifAbsent: () => 1);

  /// True when the echo was ours — and it discounts one write.
  bool _consumeEcho(String id) {
    final pending = _ownWrites[id];
    if (pending == null) return false;
    if (pending == 1) {
      _ownWrites.remove(id);
    } else {
      _ownWrites[id] = pending - 1;
    }
    return true;
  }

  @override
  Future<IList<ShoppingListItem>> fetchAll() async {
    try {
      // No `.eq('product_type.active', true)`: a deactivated type that is on
      // the list stays on the list. What IS filtered are the two ways out of
      // it — bought and removed by hand — because a line that left must not
      // come back in the aisle. The partial index of the migration is on
      // exactly this pair.
      final rows = await _client
          .from(_table)
          .select(_selection)
          .isFilter('fulfilled_on', null)
          .isFilter('removed_on', null);
      return rows.map(ShoppingListItem.fromJson).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    // BEFORE the await, and this is the whole point: Realtime broadcasts on
    // commit and the HTTP response comes back after that same commit. The two
    // arrive practically together, and the echo can win.
    if (item.id != null) _expectEcho(item.id!);
    try {
      final row = await _client
          .from(_table)
          .insert(item.toJson())
          .select(_selection)
          .single();
      return ShoppingListItem.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    _expectEcho(item.id!);
    try {
      final payload = item.toJson()..remove('id');
      final row = await _client
          .from(_table)
          // The id leaves the payload because it is already in the `.eq`, and
          // sending a primary key inside an update is asking to swap it by
          // accident one day.
          .update(payload)
          .eq('id', item.id!)
          .select(_selection)
          .single();
      return ShoppingListItem.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> remove(ShoppingListItem item, DateTime day) async {
    _expectEcho(item.id!);
    try {
      // An UPDATE, not a DELETE — see the abstract. The day is rounded by
      // the entity's own transition, so no widget and no repository decides
      // what "today" is.
      final removed = item.markedRemoved(day);
      await _client
          .from(_table)
          .update({'removed_on': encodeCalendarDay(removed.removedOn!)})
          .eq('id', item.id!);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Stream<ListChangeKind> watchChanges() {
    final controller =
        _controller ??= StreamController<ListChangeKind>.broadcast(
          // The channel is not closed on the provider's dispose — the
          // repository provider has no per-screen lifetime. It closes here,
          // when the last listener (the PendingChangesNotifier) goes away.
          onCancel: _closeChannel,
        );

    _channel ??= _client
        .channel(_table)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: onChange,
        )
        .subscribe(onStatus);

    return controller.stream;
  }

  /// Visible for testing rather than private, together with [onStatus]: both
  /// are only reachable through the callback `onPostgresChanges` receives, and
  /// getting there with mocktail costs a mock channel, the capture of the
  /// named `callback:` argument and a `registerFallbackValue` of
  /// `PostgresChangeEvent` — the most fragile scaffolding in this feature, to
  /// exercise a dozen lines. Calling them directly tests the same rule.
  @visibleForTesting
  void onChange(PostgresChangePayload payload) {
    // A DELETE brings only the primary key in oldRecord; INSERT and UPDATE
    // bring the row in newRecord. One of the two always has the id.
    final id = (payload.newRecord['id'] ?? payload.oldRecord['id']) as String?;

    // D2 — our own echo. Without this discard, adding an item shows "1 item
    // novo — atualizar" to whoever has just added it.
    if (id != null && _consumeEcho(id)) return;

    _controller?.add(
      payload.eventType == PostgresChangeEvent.insert
          ? ListChangeKind.added
          : ListChangeKind.changed,
    );
  }

  @visibleForTesting
  void onStatus(RealtimeSubscribeStatus status, Object? error) {
    // D1 — a channel failure does NOT become a stream error. It becomes
    // silence; what becomes an event is COMING BACK, because anything could
    // have changed while it was down and the screen has no way to know what.
    if (status == RealtimeSubscribeStatus.subscribed) {
      if (_wasSubscribed) _controller?.add(ListChangeKind.changed);
      _wasSubscribed = true;
      return;
    }
    // debugPrint survives a release build on purpose: in an installed PWA the
    // browser console is the only diagnosis there is.
    debugPrint('[lista] canal $status ${error ?? ''}');
  }

  void _closeChannel() {
    _channel?.unsubscribe();
    _channel = null;
    // Without this, leaving screen 1 and coming back re-subscribes with the
    // flag still on, and the first thing the list does on opening is show "a
    // lista mudou" over nothing. `_ownWrites` is emptied for the mirror
    // reason: echoes that did not arrive while the channel was up never will,
    // and leaving them there would swallow the next REAL change to those rows.
    _wasSubscribed = false;
    _ownWrites.clear();
  }
}
