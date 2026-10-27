import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/purchase_summary.dart';
import '../../../domain/models/purchase_write_plan.dart';
import '../../../domain/models/same_day_alert.dart';
import '../../../domain/models/scale_label.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/spending_cap_sync.dart';
import '../../../domain/models/write_off_undo.dart';
import '../../services/pb_cap_alerts.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'purchase_repository.dart';

// The keys of the nested map that `ProductOption.fromJson` reads. They are the
// entity's contract, not the collections' names.
const _registrationKey = 'product_registration';
const _typeKey = 'product_type';
const _brandKey = 'brand';

// The key `ListWriteOff.toJson` sends for the domain. No column has it: the
// plan already turned it into the state of the list line.
const _fulfillsKey = 'fulfills';

// The expand paths of the reads below.
const _optionExpand =
    '${PbFields.productRegistrationId}.${PbFields.productTypeId},'
    '${PbFields.productRegistrationId}.${PbFields.brandId},'
    '${PbFields.productBarcodeViaProductId}';

/// The real thing. The client is PRIVATE: the UI never reaches it.
///
/// The three writes (save, correct, delete) are ONE PocketBase batch each, so
/// a purchase either enters whole or does not enter at all.
final class PurchaseRepositoryRemote implements PurchaseRepository {
  PurchaseRepositoryRemote(this._pb, {DateTime Function() clock = DateTime.now})
    // ignore: prefer_initializing_formals
    : _clock = clock;

  final PocketBase _pb;
  final DateTime Function() _clock;

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    try {
      requireSession(_pb);
      // No owner filter: the `listRule` already limits the list to the
      // signed-in user. A leaf without a brand stays in (a brand is optional).
      final records = await _pb
          .collection(PbCollections.product)
          .getFullList(
            filter:
                '${PbFields.active} = true && '
                '${PbFields.productRegistrationId}.${PbFields.active} = true',
            expand: _optionExpand,
          );
      return [for (final r in records) _optionOf(r.data)].toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<IList<PurchaseHistoryEntry>> fetchRecentItems(DateTime since) async {
    try {
      requireSession(_pb);
      // The date is the PARENT's. No `active` filter: deactivating a leaf
      // does not rewrite the past (requirement 16).
      final records = await _pb
          .collection(PbCollections.purchaseItem)
          .getFullList(
            filter: _pb.filter(
              '${PbFields.purchaseId}.${PbFields.purchaseDate} >= {:since}',
              {'since': encodeStoredDay(since)},
            ),
            expand:
                '${PbFields.purchaseId},'
                '${PbFields.productId}.${PbFields.productRegistrationId}',
          );
      return [
        for (final r in records)
          PurchaseHistoryEntry(
            productId: r.getStringValue(PbFields.productId),
            productTypeId:
                _one(
                      _one(r.data, PbFields.productId),
                      PbFields.productRegistrationId,
                    )[PbFields.productTypeId]
                    as String,
            quantityInBaseUnit: (r.data[PbFields.quantityInBaseUnit] as num)
                .toInt(),
            paid: Money.fromJson(r.data[PbFields.totalPaid]),
            purchasedOn: decodeStoredDay(
              _one(r.data, PbFields.purchaseId)[PbFields.purchaseDate]
                  as String,
            ),
          ),
      ].toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<bool> save(PurchaseSubmission submission) async {
    final purchase = submission.purchase;
    try {
      requireSession(_pb);
      final alertSteps = await _capAlertStepsFor(submission.capAlerts);
      final plan = PurchaseWritePlan.forCreate(
        purchase: purchase,
        writeOffs: submission.writeOffs,
        capAlerts: submission.capAlerts,
      );
      final batch = _pb.createBatch();
      for (final step in plan.steps) {
        _enqueue(batch, step, plan, _StoredLines.empty, alertSteps);
      }
      await batch.send();
      return false;
    } on Object catch (e, st) {
      // H8's resend: a 409 may be the purchase id (the batch already ran, and
      // it was atomic) or the month's alert (the other phone created it
      // between the read and the batch). One read by id tells them apart.
      if (e is ClientException && statusCodeOf(e) == 409) {
        try {
          final found = await _pb
              .collection(PbCollections.purchase)
              .getList(
                page: 1,
                perPage: 1,
                skipTotal: true,
                filter: _pb.filter('${PbFields.id} = {:id}', {
                  'id': purchase.id,
                }),
              );
          if (found.items.isNotEmpty) return true;
        } on Object catch (confirmation, confirmationSt) {
          rethrowAsKnownFailure(confirmation, confirmationSt);
        }
      }
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  }) async {
    // A programming error, not a server failure: no request is made.
    if (offset % limit != 0) {
      throw ArgumentError.value(
        offset,
        'offset',
        'must be a multiple of the page size ($limit)',
      );
    }
    try {
      requireSession(_pb);
      final result = await _pb
          .collection(PbCollections.purchase)
          .getList(
            page: offset ~/ limit + 1,
            perPage: limit,
            // `-id` breaks a tie: two purchases with the same `created_at`
            // never skip or repeat between pages.
            sort:
                '-${PbFields.purchaseDate},-${PbFields.createdAt},'
                '-${PbFields.id}',
            expand: '${PbFields.storeId},${PbFields.purchaseItemViaPurchaseId}',
          );
      final purchases = [
        for (final r in result.items) _summaryOf(r.data),
      ].toIList();
      return PurchaseHistoryPage(
        purchases: purchases,
        hasMore: result.page < result.totalPages,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<PurchaseDetail> fetchDetail(String purchaseId) async {
    try {
      requireSession(_pb);
      const items = PbFields.purchaseItemViaPurchaseId;
      const leaf =
          '$items.${PbFields.productId}.${PbFields.productRegistrationId}';
      final row = await _pb
          .collection(PbCollections.purchase)
          .getOne(
            purchaseId,
            expand:
                '$leaf.${PbFields.productTypeId},'
                '$leaf.${PbFields.brandId},'
                '$items.${PbFields.listWriteOffViaPurchaseItemId}',
          );

      final purchaseItems = <PurchaseItem>[];
      final trail = <ListWriteOff>[];
      for (final raw in _many(row.data, items)) {
        final id = raw[PbFields.id] as String;
        purchaseItems.add(
          PurchaseItem(
            id: id,
            option: _optionOf(_one(raw, PbFields.productId)),
            quantity: (raw[PbFields.quantity] as num).toInt(),
            paid: Money.fromJson(raw[PbFields.totalPaid]),
          ),
        );
        for (final off in _many(raw, PbFields.listWriteOffViaPurchaseItemId)) {
          trail.add(
            ListWriteOff(
              purchaseItemId: id,
              shoppingListItemId: off[PbFields.shoppingListItemId] as String,
              quantityWrittenOff:
                  (off[PbFields.quantityWrittenOff] as num?)?.toInt() ?? 0,
              clearedNotFound: off[PbFields.clearedNotFound] as bool? ?? false,
            ),
          );
        }
      }

      return PurchaseDetail(
        purchase: Purchase(
          id: row.id,
          date: decodeStoredDay(row.getStringValue(PbFields.purchaseDate)),
          storeId: row.getStringValue(PbFields.storeId),
          registeredBy: row.getStringValue(PbFields.registeredBy),
          items: purchaseItems.toIList(),
        ),
        items: purchaseItems.toIList(),
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
      requireSession(_pb);
      final stored = await _storedLinesOf(purchase.id);
      final alertSteps = await _capAlertStepsFor(capAlerts);
      final plan = PurchaseWritePlan.forCorrection(
        purchase: purchase,
        writeOffs: writeOffs,
        restored: restored,
        capAlerts: capAlerts,
      );
      final batch = _pb.createBatch();
      for (final step in plan.steps) {
        _enqueue(batch, step, plan, stored, alertSteps);
      }
      await batch.send();
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
      requireSession(_pb);
      final stored = await _storedLinesOf(purchaseId);
      final alertSteps = await _capAlertStepsFor(capAlerts);
      final plan = PurchaseWritePlan.forDeletion(
        purchaseId: purchaseId,
        restored: restored,
        capAlerts: capAlerts,
      );
      final batch = _pb.createBatch();
      for (final step in plan.steps) {
        _enqueue(batch, step, plan, stored, alertSteps);
      }
      await batch.send();
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
    if (productTypeIds.isEmpty) return const IList.empty();
    try {
      requireSession(_pb);
      // The types are cut in Dart (`sameDayAlertsOf`): one day has few lines.
      const registration =
          '${PbFields.productId}.${PbFields.productRegistrationId}';
      final records = await _pb
          .collection(PbCollections.purchaseItem)
          .getFullList(
            filter: _pb.filter(
              '${PbFields.purchaseId}.${PbFields.purchaseDate} = {:day} && '
              '${PbFields.purchaseId}.${PbFields.registeredBy} != {:by}',
              {'day': encodeStoredDay(date), 'by': registeredBy},
            ),
            expand:
                '${PbFields.purchaseId},$registration.${PbFields.productTypeId}',
          );
      final lines = <_SameDayLine>[];
      for (final r in records) {
        final purchase = _one(r.data, PbFields.purchaseId);
        final type = _one(
          _one(
            _one(r.data, PbFields.productId),
            PbFields.productRegistrationId,
          ),
          PbFields.productTypeId,
        );
        lines.add(
          _SameDayLine(
            purchaseDate: decodeStoredDay(
              purchase[PbFields.purchaseDate] as String,
            ),
            registeredBy: purchase[PbFields.registeredBy] as String? ?? '',
            productTypeId: type[PbFields.id] as String,
            typeName: type[PbFields.name] as String,
          ),
        );
      }
      return sameDayAlertsOf(
        date: date,
        registeredBy: registeredBy,
        lines: lines.lock,
        productTypeIds: productTypeIds,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  /// The items and write-offs the purchase has on the server — what a
  /// correction or a deletion has to delete explicitly.
  Future<_StoredLines> _storedLinesOf(String purchaseId) async {
    final items = await _pb
        .collection(PbCollections.purchaseItem)
        .getFullList(
          filter: _pb.filter('${PbFields.purchaseId} = {:id}', {
            'id': purchaseId,
          }),
          expand: PbFields.listWriteOffViaPurchaseItemId,
        );
    return _StoredLines(
      itemIds: [for (final i in items) i.id].toIList(),
      writeOffIds: [
        for (final i in items)
          for (final off in _many(
            i.data,
            PbFields.listWriteOffViaPurchaseItemId,
          ))
            off[PbFields.id] as String,
      ].toIList(),
    );
  }

  Future<IList<CapAlertStep>> _capAlertStepsFor(
    IList<CapAlerts> capAlerts,
  ) async {
    if (capAlerts.isEmpty) return const IList.empty();
    return planCapAlertWrites(
      wanted: capAlerts,
      existing: await fetchStoredCapAlerts(_pb, capAlerts.map((a) => a.month)),
      stampedAt: _clock().toUtc(),
    );
  }

  void _enqueue(
    BatchService batch,
    PurchaseWriteStep step,
    PurchaseWritePlan plan,
    _StoredLines stored,
    IList<CapAlertStep> alertSteps,
  ) {
    final userId = _pb.authStore.record!.id;
    final purchase = plan.purchase;
    switch (step) {
      case PurchaseWriteStep.createPurchase:
        batch
            .collection(PbCollections.purchase)
            .create(
              body: {
                ...purchase!.toJson(),
                PbFields.purchaseDate: encodeStoredDay(purchase.date),
                PbFields.createdAt: encodeInstant(_clock()),
                PbFields.user: userId,
              },
            );
      case PurchaseWriteStep.updatePurchase:
        // Never `registered_by`, `created_at` or `user`: a correction does
        // not rewrite who registered, or when.
        batch
            .collection(PbCollections.purchase)
            .update(
              purchase!.id,
              body: {
                PbFields.purchaseDate: encodeStoredDay(purchase.date),
                PbFields.storeId: purchase.storeId,
              },
            );
      case PurchaseWriteStep.deleteWriteOffs:
        for (final id in stored.writeOffIds) {
          batch.collection(PbCollections.listWriteOff).delete(id);
        }
      case PurchaseWriteStep.deleteItems:
        for (final id in stored.itemIds) {
          batch.collection(PbCollections.purchaseItem).delete(id);
        }
      case PurchaseWriteStep.createItems:
        for (final item in purchase!.items) {
          batch
              .collection(PbCollections.purchaseItem)
              .create(
                body: {
                  ...item.toJson(),
                  PbFields.purchaseId: purchase.id,
                  PbFields.user: userId,
                },
              );
        }
      case PurchaseWriteStep.createWriteOffs:
        for (final off in plan.writeOffs) {
          batch
              .collection(PbCollections.listWriteOff)
              .create(
                body: {
                  ...off.toJson()..remove(_fulfillsKey),
                  PbFields.user: userId,
                },
              );
        }
      case PurchaseWriteStep.updateListItems:
        for (final change in plan.listChanges) {
          final body = <String, dynamic>{
            ...switch (change.fulfillment) {
              KeepFulfillment() => const <String, dynamic>{},
              // The key PRESENT and empty: it is what reopens the item.
              ReopenItem() => const {PbFields.fulfilledOn: ''},
              SetFulfilled(:final on) => {
                PbFields.fulfilledOn: encodeStoredDay(on),
              },
            },
            if (change.notFound != null) PbFields.notFound: change.notFound,
          };
          if (body.isEmpty) continue;
          batch
              .collection(PbCollections.shoppingListItem)
              .update(change.shoppingListItemId, body: body);
        }
      case PurchaseWriteStep.deletePurchase:
        batch.collection(PbCollections.purchase).delete(plan.purchaseId);
      case PurchaseWriteStep.writeCapAlerts:
        addCapAlertSteps(batch, alertSteps, userId: userId);
    }
  }
}

/// A leaf expanded as `ProductOption.fromJson` expects: the registration,
/// its type and brand nested, and the codes as rows. PocketBase's empty
/// (`""`) becomes null where the entity reads "none".
ProductOption _optionOf(Map<String, dynamic> product) {
  final registration = _oneOrNull(product, PbFields.productRegistrationId)!;
  final brand = _oneOrNull(registration, PbFields.brandId);
  final type = _one(registration, PbFields.productTypeId);

  return ProductOption.fromJson({
    ...product,
    Product.barcodesKey: [
      for (final row in _many(product, PbFields.productBarcodeViaProductId))
        {
          ScaleCode.codeKey: row[PbFields.code],
          ScaleCode.storeIdKey: _emptyAsNull(row[PbFields.storeId]),
        },
    ],
    _registrationKey: {
      ...registration,
      PbFields.brandId: _emptyAsNull(registration[PbFields.brandId]),
      _typeKey: {...type},
      _brandKey: brand == null ? null : {...brand},
    },
  });
}

PurchaseSummary _summaryOf(Map<String, dynamic> row) {
  final store = _oneOrNull(row, PbFields.storeId);
  return PurchaseSummary.fromJson({
    PbFields.id: row[PbFields.id],
    PbFields.purchaseDate: encodeCalendarDay(
      decodeStoredDay(row[PbFields.purchaseDate] as String),
    ),
    PbFields.registeredBy: row[PbFields.registeredBy],
    'store': store == null ? null : {PbFields.name: store[PbFields.name]},
    'purchase_item': [
      for (final item in _many(row, PbFields.purchaseItemViaPurchaseId))
        {PbFields.totalPaid: item[PbFields.totalPaid]},
    ],
  });
}

Object? _emptyAsNull(Object? value) =>
    value is String && value.isEmpty ? null : value;

/// The single record expanded under [field], or null when absent.
Map<String, dynamic>? _oneOrNull(Map<String, dynamic> row, String field) {
  final value = (row['expand'] as Map<String, dynamic>?)?[field];
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    return value.first as Map<String, dynamic>;
  }
  return null;
}

Map<String, dynamic> _one(Map<String, dynamic> row, String field) =>
    _oneOrNull(row, field) ??
    (throw StateError('Missing expand "$field" in the response.'));

/// The records expanded under [field] (a back-relation); empty when absent.
List<Map<String, dynamic>> _many(Map<String, dynamic> row, String field) {
  final value = (row['expand'] as Map<String, dynamic>?)?[field];
  if (value is List) return value.cast<Map<String, dynamic>>();
  if (value is Map<String, dynamic>) return [value];
  return const [];
}

/// The ids a purchase already has on the server.
final class _StoredLines {
  const _StoredLines({required this.itemIds, required this.writeOffIds});

  static const empty = _StoredLines(
    itemIds: IList<String>.empty(),
    writeOffIds: IList<String>.empty(),
  );

  final IList<String> itemIds;
  final IList<String> writeOffIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StoredLines &&
          other.itemIds == itemIds &&
          other.writeOffIds == writeOffIds;

  @override
  int get hashCode => Object.hash(itemIds, writeOffIds);
}

/// One line of another person's purchase on the day, as `sameDayAlertsOf`
/// reads it.
final class _SameDayLine implements SameDayPurchaseLine {
  const _SameDayLine({
    required this.purchaseDate,
    required this.registeredBy,
    required this.productTypeId,
    required this.typeName,
  });

  @override
  final DateTime purchaseDate;
  @override
  final String registeredBy;
  @override
  final String productTypeId;
  @override
  final String typeName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SameDayLine &&
          other.purchaseDate == purchaseDate &&
          other.registeredBy == registeredBy &&
          other.productTypeId == productTypeId &&
          other.typeName == typeName;

  @override
  int get hashCode =>
      Object.hash(purchaseDate, registeredBy, productTypeId, typeName);
}
