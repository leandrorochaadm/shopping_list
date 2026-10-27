import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/pending_changes.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'shopping_list_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// **Every method closes on `rethrowAsKnownFailure`**, with the session check
/// inside the `try`, so a missing session is classified like any other
/// failure.
final class ShoppingListRepositoryRemote implements ShoppingListRepository {
  ShoppingListRepositoryRemote(this._pb);

  final PocketBase _pb;

  /// The expand (D4), written ONCE — it is used by the fetch, the create and
  /// the update, and three copies would diverge on the first new column. The
  /// registration's brand comes nested inside it — the line's label needs its
  /// name (M-a). The write-offs are a back-relation: PocketBase leaves the key
  /// out when there are none.
  static const _expand =
      '${PbFields.productTypeId}.${PbFields.categoryId},'
      '${PbFields.preferredRegistrationId}.${PbFields.brandId},'
      '${PbFields.listWriteOffViaShoppingListItemId}';

  /// The two ways out of the list — bought and removed by hand. A line that
  /// left must not come back in the aisle. PocketBase stores an empty date as
  /// `""`.
  static const _openFilter =
      '${PbFields.fulfilledOn} = "" && ${PbFields.removedOn} = ""';

  /// Keeps the filter of `fetchItemsByIds` far below the filter and URL limits.
  static const _idsPerRequest = 50;

  /// The ids THIS phone wrote and whose echo has not come back yet (D2).
  ///
  /// It is a COUNTER, not a `Set`: two taps on the same item's checkbox are
  /// two writes to the same row, and a `Set` would hold a single entry — the
  /// first echo would consume it and the second would pass as a change from
  /// the other phone. The banner would then talk about the change the person
  /// has just made, which is exactly the risk D2 exists to close.
  final Map<String, int> _ownWrites = {};

  StreamController<ListChangeKind>? _controller;
  Future<UnsubscribeFunc>? _subscription;
  Future<UnsubscribeFunc>? _connectSubscription;
  bool _subscribed = false;

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

  /// Rebuilds the nested map `ShoppingListItem.fromJson` reads from a record
  /// and its expand. The "no value" of PocketBase (`""`) is turned into `null`
  /// here, at the border.
  Map<String, dynamic> _itemJson(RecordModel record) {
    // The expand stays raw (maps): `ShoppingListItem.fromJson` reads maps.
    Map<String, dynamic>? one(Map<String, dynamic> from, String field) {
      final expand = from['expand'];
      if (expand is! Map) return null;
      final value = expand[field];
      return value is Map ? value.cast<String, dynamic>() : null;
    }

    final type = one(record.data, PbFields.productTypeId)!;
    final category = one(type, PbFields.categoryId)!;
    final registration =
        record.getStringValue(PbFields.preferredRegistrationId).isEmpty
        ? null
        : one(record.data, PbFields.preferredRegistrationId);
    final brand = registration == null
        ? null
        : one(registration, PbFields.brandId);
    final writeOffs = switch (record.data['expand']) {
      final Map expand => expand[PbFields.listWriteOffViaShoppingListItemId],
      _ => null,
    };

    String? dayOrNull(String field) {
      final raw = record.getStringValue(field);
      return raw.isEmpty ? null : encodeCalendarDay(decodeStoredDay(raw));
    }

    Map<String, dynamic> without(Map<String, dynamic> m) =>
        {...m}..remove('expand');

    return {
      ...record.data,
      PbFields.id: record.id,
      PbFields.enteredOn: encodeCalendarDay(
        decodeStoredDay(record.getStringValue(PbFields.enteredOn)),
      ),
      PbFields.fulfilledOn: dayOrNull(PbFields.fulfilledOn),
      PbFields.removedOn: dayOrNull(PbFields.removedOn),
      ShoppingListItem.typeKey: {
        ...without(type),
        ShoppingListItem.categoryKey: without(category),
      },
      ShoppingListItem.preferredRegistrationKey: registration == null
          ? null
          : {
              ...without(registration),
              if ((registration[PbFields.brandId] as String? ?? '').isEmpty)
                PbFields.brandId: null,
              ShoppingListItem.brandKey: brand == null ? null : without(brand),
            },
      ShoppingListItem.writeOffsKey: writeOffs is List ? writeOffs : const [],
    };
  }

  ShoppingListItem _itemOf(RecordModel record) =>
      ShoppingListItem.fromJson(_itemJson(record));

  /// The columns of the item with the "no value" of PocketBase. Never carries
  /// the owner.
  Map<String, dynamic> _writeBody(ShoppingListItem item) {
    String stored(DateTime? day) => day == null ? '' : encodeStoredDay(day);
    return {
      ...item.toJson(),
      PbFields.preferredRegistrationId: item.preferredRegistration?.id ?? '',
      PbFields.quantity: item.quantity ?? 0,
      PbFields.enteredOn: encodeStoredDay(item.enteredOn),
      PbFields.fulfilledOn: stored(item.fulfilledOn),
      PbFields.removedOn: stored(item.removedOn),
    };
  }

  String _openOfTypeFilter(String productTypeId) => _pb.filter(
    '${PbFields.productTypeId} = {:t} && $_openFilter',
    {'t': productTypeId},
  );

  @override
  Future<IList<ShoppingListItem>> fetchAll() async {
    try {
      requireSession(_pb);
      // No `active` filter: a deactivated type that is on the list stays on
      // the list. What IS filtered are the two ways out of it.
      final records = await _pb
          .collection(PbCollections.shoppingListItem)
          .getFullList(filter: _openFilter, expand: _expand);
      return records.map(_itemOf).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<ShoppingListItem>> fetchItemsByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    // A purchase that wrote nothing off — someone bought what nobody had asked
    // for — lands here on every correction.
    if (unique.isEmpty) return const IList.empty();
    try {
      requireSession(_pb);
      // Same expand `fetchAll` uses — that is where the sum AND the count of
      // the trail come from — without the open filter: an item that LEFT the
      // list is precisely the one the undo has to see.
      final blocks = [
        for (var i = 0; i < unique.length; i += _idsPerRequest)
          unique.sublist(
            i,
            i + _idsPerRequest > unique.length
                ? unique.length
                : i + _idsPerRequest,
          ),
      ];
      final results = await Future.wait([
        for (final block in blocks)
          _pb
              .collection(PbCollections.shoppingListItem)
              .getFullList(
                filter: _pb.filter(
                  [
                    for (var i = 0; i < block.length; i++)
                      '${PbFields.id} = {:i$i}',
                  ].join(' || '),
                  {for (var i = 0; i < block.length; i++) 'i$i': block[i]},
                ),
                expand: _expand,
              ),
      ]);
      return [for (final records in results) ...records.map(_itemOf)].toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<int> countOpenItemsOfType(String productTypeId) async {
    try {
      requireSession(_pb);
      final page = await _pb
          .collection(PbCollections.shoppingListItem)
          .getList(
            page: 1,
            perPage: 1,
            filter: _openOfTypeFilter(productTypeId),
          );
      return page.totalItems;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<String>> removeOpenItemsOfType(
    String productTypeId,
    DateTime day,
  ) async {
    try {
      requireSession(_pb);
      // PocketBase has no `UPDATE … WHERE`: read the ids, then one PATCH per
      // id in an atomic batch. The repository needs the ids anyway, to
      // swallow the echo — without it, deactivating a type paints "a lista
      // mudou" on the very phone that deactivated it.
      final records = await _pb
          .collection(PbCollections.shoppingListItem)
          .getFullList(
            filter: _openOfTypeFilter(productTypeId),
            fields: PbFields.id,
          );
      final ids = records.map((r) => r.id).toIList();
      if (ids.isEmpty) return ids;

      // Consumed HERE, inside the repository, and BEFORE the batch: the ids
      // are known now, and the events can beat the HTTP response.
      for (final id in ids) {
        _expectEcho(id);
      }
      final removedOn = encodeStoredDay(dayOf(day));
      final batch = _pb.createBatch();
      for (final id in ids) {
        batch
            .collection(PbCollections.shoppingListItem)
            .update(id, body: {PbFields.removedOn: removedOn});
      }
      await batch.send();
      return ids;
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  void expectEcho(Iterable<String> ids) {
    for (final id in ids) {
      _expectEcho(id);
    }
  }

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    // BEFORE the await, and this is the whole point: the event is sent on
    // commit and the HTTP response comes back after that same commit. The two
    // arrive practically together, and the echo can win.
    if (item.id != null) _expectEcho(item.id!);
    try {
      requireSession(_pb);
      // The id is born in the app (`newRecordId`) and goes in the body; a
      // resend with the same id comes back 409.
      final record = await _pb
          .collection(PbCollections.shoppingListItem)
          .create(
            body: {
              ..._writeBody(item),
              PbFields.user: _pb.authStore.record!.id,
            },
            expand: _expand,
          );
      return _itemOf(record);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    _expectEcho(item.id!);
    try {
      requireSession(_pb);
      // The id is in the path; sending a primary key inside an update is
      // asking to swap it by accident one day. The owner never goes either.
      final body = _writeBody(item)..remove(PbFields.id);
      final record = await _pb
          .collection(PbCollections.shoppingListItem)
          .update(item.id!, body: body, expand: _expand);
      return _itemOf(record);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> remove(ShoppingListItem item, DateTime day) async {
    _expectEcho(item.id!);
    try {
      requireSession(_pb);
      // A PATCH, not a DELETE — see the abstract. The day is rounded by the
      // entity's own transition, so no widget and no repository decides what
      // "today" is.
      final removed = item.markedRemoved(day);
      await _pb
          .collection(PbCollections.shoppingListItem)
          .update(
            item.id!,
            body: {PbFields.removedOn: encodeStoredDay(removed.removedOn!)},
          );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Stream<ListChangeKind> watchChanges() {
    final controller = _controller ??=
        StreamController<ListChangeKind>.broadcast(
          // The channel is not closed on the provider's dispose — the
          // repository provider has no per-screen lifetime. It closes here,
          // when the last listener (the PendingChangesNotifier) goes away.
          onCancel: _closeChannel,
        );

    // Subscribed BEFORE the collection: the SDK delivers `PB_CONNECT` to
    // whoever subscribed, on every (re)connection.
    _connectSubscription ??= _guarded(
      _pb.realtime.subscribe(PbRealtime.connectTopic, (_) => onConnect()),
    );

    if (_subscription == null) {
      final subscription = _guarded(
        _pb
            .collection(PbCollections.shoppingListItem)
            .subscribe(PbRealtime.allRecords, onEvent),
      );
      _subscription = subscription;
      unawaited(
        subscription.then((unsubscribe) {
          if (_subscription == subscription) {
            onSubscribed();
          } else {
            // The channel was closed before the subscription finished.
            unawaited(unsubscribe());
          }
        }),
      );
    }

    return controller.stream;
  }

  /// D1 — a channel failure does NOT become a stream error. It becomes
  /// silence (a log line); the returned Future never completes with an error.
  Future<UnsubscribeFunc> _guarded(Future<UnsubscribeFunc> future) =>
      future.catchError((Object error) {
        // debugPrint survives a release build on purpose: in an installed PWA
        // the browser console is the only diagnosis there is.
        debugPrint('[lista] canal $error');
        return () async {};
      });

  /// Visible for testing rather than private: both this and [onSubscribed] /
  /// [onConnect] are only reachable through the callbacks the SDK receives.
  @visibleForTesting
  void onEvent(RecordSubscriptionEvent event) {
    final id = event.record?.id;

    // D2 — our own echo. Without this discard, adding an item shows "1 item
    // novo — atualizar" to whoever has just added it.
    if (id != null && _consumeEcho(id)) return;

    _controller?.add(
      event.action == PbRealtime.createAction
          ? ListChangeKind.added
          : ListChangeKind.changed,
    );
  }

  @visibleForTesting
  void onSubscribed() => _subscribed = true;

  /// Connection of the event stream. The first one is the initial connection
  /// and says nothing; the following ones are the way back from a drop, and
  /// anything could have changed while it was down.
  @visibleForTesting
  void onConnect() {
    if (_subscribed) _controller?.add(ListChangeKind.changed);
  }

  void _closeChannel() {
    final subscription = _subscription;
    final connect = _connectSubscription;
    _subscription = null;
    _connectSubscription = null;
    // Without this, leaving screen 1 and coming back re-subscribes with the
    // flag still on, and the first thing the list does on opening is show "a
    // lista mudou" over nothing. `_ownWrites` is emptied for the mirror
    // reason: echoes that did not arrive while the channel was up never will,
    // and leaving them there would swallow the next REAL change to those rows.
    _subscribed = false;
    _ownWrites.clear();
    for (final pending in [subscription, connect]) {
      pending?.then((unsubscribe) => unsubscribe()).catchError((Object e) {
        debugPrint('[lista] canal $e');
      });
    }
  }
}
