import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/record_id.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/spending_cap_sync.dart';
import '../../services/pb_cap_alerts.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'spending_cap_repository.dart';

// The date of the purchase, reached through the item's relation.
const _purchaseDate = '${PbFields.purchaseId}.${PbFields.purchaseDate}';
const _purchaseExpand = 'expand.${PbFields.purchaseId}';

/// The real thing. The client is PRIVATE: the UI never reaches it.
final class SpendingCapRepositoryRemote implements SpendingCapRepository {
  SpendingCapRepositoryRemote(this._pb, {this._clock = DateTime.now});

  final PocketBase _pb;
  final DateTime Function() _clock;

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(
    IList<ReportPeriod> months,
  ) async {
    try {
      requireSession(_pb);
      if (months.isEmpty) return const IList.empty();

      // Three reads in parallel: a purchase saved between them can leave the
      // spending a little behind the marks. The next read fixes it.
      final results = await Future.wait<Object>([
        _fetchCaps(),
        fetchStoredCapAlerts(_pb, months.map((p) => p.from)),
        _fetchSpending(months),
      ]);
      return buildMonthCapStatuses(
        months: months.map((p) => p.from).toIList(),
        caps: results[0] as IList<SpendingCap>,
        spentByMonth: results[2] as IMap<DateTime, Money>,
        alerts: results[1] as IList<StoredCapAlert>,
      );
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<void> save({
    required SpendingCap cap,
    required CapAlerts alerts,
  }) async {
    // The rearm belongs to the month the cap starts in.
    if (alerts.month != cap.effectiveFrom) {
      throw ArgumentError.value(
        alerts.month,
        'alerts',
        'must be the month of the cap',
      );
    }
    try {
      requireSession(_pb);
      try {
        await _saveOnce(cap, alerts);
      } on ClientException catch (e) {
        if (statusCodeOf(e) != 409) rethrow;
        // The other phone created it: read again, and this time it updates.
        await _saveOnce(cap, alerts);
      }
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  Future<IList<SpendingCap>> _fetchCaps() async {
    final records = await _pb
        .collection(PbCollections.spendingCap)
        .getFullList(sort: PbFields.effectiveFrom);
    final caps = <SpendingCap>[];
    for (final r in records) {
      try {
        caps.add(
          SpendingCap(
            amount: Money.fromJson(r.data[PbFields.amount]),
            effectiveFrom: decodeStoredDay(
              r.getStringValue(PbFields.effectiveFrom),
            ),
          ),
        );
      } on InvalidSpendingCap {
        // Only a hand-written record gets here. The old `MonthCapStatus`
        // also read it as "no cap" instead of breaking the screen.
      }
    }
    return caps.toIList();
  }

  Future<IMap<DateTime, Money>> _fetchSpending(
    IList<ReportPeriod> months,
  ) async {
    final params = <String, dynamic>{};
    final clauses = <String>[];
    for (var i = 0; i < months.length; i++) {
      clauses.add('($_purchaseDate >= {:f$i} && $_purchaseDate <= {:t$i})');
      params['f$i'] = encodeStoredDay(months[i].from);
      params['t$i'] = encodeStoredDay(months[i].to);
    }
    final records = await _pb
        .collection(PbCollections.purchaseItem)
        .getFullList(
          filter: _pb.filter(clauses.join(' || '), params),
          expand: PbFields.purchaseId,
        );
    final byDay = <DateTime, Money>{};
    for (final r in records) {
      final purchase = r.get<RecordModel?>(_purchaseExpand);
      if (purchase == null) {
        throw StateError('Missing expand "${PbFields.purchaseId}".');
      }
      final day = decodeStoredDay(
        purchase.getStringValue(PbFields.purchaseDate),
      );
      final paid = Money.fromJson(r.data[PbFields.totalPaid]);
      final soFar = byDay[day];
      byDay[day] = soFar == null ? paid : soFar + paid;
    }
    return byDay.lock;
  }

  Future<void> _saveOnce(SpendingCap cap, CapAlerts alerts) async {
    final existing =
        (await _pb
                .collection(PbCollections.spendingCap)
                .getList(
                  page: 1,
                  perPage: 1,
                  skipTotal: true,
                  filter: _pb.filter('${PbFields.effectiveFrom} = {:from}', {
                    'from': encodeStoredDay(cap.effectiveFrom),
                  }),
                ))
            .items
            .firstOrNull;
    final stored = await fetchStoredCapAlerts(_pb, [alerts.month]);
    final steps = planCapAlertWrites(
      wanted: [alerts].lock,
      existing: stored,
      stampedAt: _clock().toUtc(),
      rearm: true,
    );

    final userId = _pb.authStore.record!.id;
    final batch = _pb.createBatch();
    final caps = batch.collection(PbCollections.spendingCap);
    if (existing != null) {
      // Neither the owner nor the month: the rule refuses both to change.
      caps.update(existing.id, body: {PbFields.amount: cap.amount.toJson()});
    } else {
      caps.create(
        body: {
          PbFields.id: newRecordId(),
          PbFields.amount: cap.amount.toJson(),
          PbFields.effectiveFrom: encodeStoredDay(cap.effectiveFrom),
          PbFields.user: userId,
        },
      );
    }
    addCapAlertSteps(batch, steps, userId: userId);
    await batch.send();
  }
}
