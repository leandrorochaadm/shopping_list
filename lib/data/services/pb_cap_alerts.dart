import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../domain/models/calendar_day.dart';
import '../../domain/models/record_id.dart';
import '../../domain/models/spending_cap_sync.dart';
import 'pb_schema.dart';

/// Reads the cap alerts (`spending_cap_alert`) of [months], one per month.
///
/// No `try` of its own: the repository that calls it already has one. No
/// months means no request.
Future<IList<StoredCapAlert>> fetchStoredCapAlerts(
  PocketBase pb,
  Iterable<DateTime> months,
) async {
  final days = {for (final m in months) encodeStoredDay(firstDayOfMonth(m))};
  if (days.isEmpty) return const IList.empty();

  final params = <String, dynamic>{};
  final clauses = <String>[];
  var index = 0;
  for (final day in days) {
    clauses.add('${PbFields.month} = {:m$index}');
    params['m$index'] = day;
    index++;
  }
  final records = await pb
      .collection(PbCollections.spendingCapAlert)
      .getFullList(filter: pb.filter(clauses.join(' || '), params));

  return [
    for (final r in records)
      StoredCapAlert(
        id: r.id,
        month: decodeStoredDay(r.getStringValue(PbFields.month)),
        warned80At: _stampOf(r.getStringValue(PbFields.warned80At)),
        warned100At: _stampOf(r.getStringValue(PbFields.warned100At)),
      ),
  ].toIList();
}

/// Queues the writes [steps] decided, in the order received. The steps that
/// are [CapAlertWrite.none] queue nothing.
void addCapAlertSteps(
  BatchService batch,
  IList<CapAlertStep> steps, {
  required String userId,
}) {
  final alerts = batch.collection(PbCollections.spendingCapAlert);
  for (final step in steps) {
    final stamps = {
      PbFields.warned80At: _stampBody(step.warned80At),
      PbFields.warned100At: _stampBody(step.warned100At),
    };
    switch (step.write) {
      case CapAlertWrite.none:
        break;
      case CapAlertWrite.create:
        alerts.create(
          body: {
            PbFields.id: newRecordId(),
            PbFields.month: encodeStoredDay(step.month),
            ...stamps,
            PbFields.user: userId,
          },
        );
      case CapAlertWrite.update:
        // Neither the month nor the owner: the rule refuses both to change.
        alerts.update(step.recordId!, body: stamps);
      case CapAlertWrite.delete:
        alerts.delete(step.recordId!);
    }
  }
}

DateTime? _stampOf(String raw) => raw.isEmpty ? null : decodeInstant(raw);

String _stampBody(DateTime? stamp) => stamp == null ? '' : encodeInstant(stamp);
