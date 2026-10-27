import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/services/pb_cap_alerts.dart';

import '../helpers/pocketbase_test_client.dart';

void main() {
  late List<http.Request> requests;

  setUp(() => requests = []);

  test('reads nothing when no month is asked', () async {
    final pb = testPocketBase(
      MockClient((request) async {
        requests.add(request);
        return listJson([]);
      }),
    );

    final stored = await fetchStoredCapAlerts(pb, const []);

    expect(stored, isEmpty);
    expect(requests, isEmpty);
  });

  test('asks once for the distinct months and maps the stamps', () async {
    final pb = testPocketBase(
      MockClient((request) async {
        requests.add(request);
        return listJson([
          recordJson('alert0000000001', {
            'month': '2026-08-01 00:00:00.000Z',
            'warned_80_at': '2026-08-18 15:30:00.000Z',
            'warned_100_at': '',
          }),
        ]);
      }),
    );

    final stored = await fetchStoredCapAlerts(pb, [
      DateTime.utc(2026, 8, 3),
      DateTime.utc(2026, 8, 20),
      DateTime.utc(2026, 9),
    ]);

    expect(requests, hasLength(1));
    final filter = requests.single.url.queryParameters['filter']!;
    expect('2026-08-01'.allMatches(filter), hasLength(1));
    expect(filter, contains('2026-09-01'));
    expect(stored.single.id, 'alert0000000001');
    expect(stored.single.month, DateTime(2026, 8));
    expect(stored.single.warned80At, DateTime.utc(2026, 8, 18, 15, 30));
    expect(stored.single.warned100At, isNull);
  });

  test('a batch with no steps sends nothing', () {
    final pb = testPocketBase(
      MockClient((request) async => fail('no request expected')),
    );

    addCapAlertSteps(pb.createBatch(), const IList.empty(), userId: testUserId);

    expect(jsonEncode(requests), '[]');
  });
}
