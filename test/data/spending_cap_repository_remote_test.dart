import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/calendar_day.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/record_id.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';

import '../helpers/pocketbase_test_client.dart';

const _capId = 'cap000000000001';
const _alertId = 'alert0000000001';
const _stamp = '2026-08-18 15:30:00.000Z';
const _uniqueError = {
  'effective_from': {'code': 'validation_not_unique', 'message': ''},
};

final _august = ReportPeriod.monthOf(DateTime(2026, 8, 15));
final _cap = SpendingCap(
  amount: const Money(150000),
  effectiveFrom: DateTime(2026, 8, 1),
);
final _clock = DateTime.utc(2026, 8, 18, 15, 30);

class _Fake {
  _Fake({
    this.caps = const [],
    this.alerts = const [],
    this.items = const [],
    this.batches = const [],
  });

  final List<Map<String, dynamic>> caps;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> items;

  /// One entry per expected batch: null is success, else the error response.
  final List<http.Response?> batches;

  final requests = <http.Request>[];
  var _batchCount = 0;

  Iterable<http.Request> get(String collection) => requests.where(
    (r) => r.method == 'GET' && r.url.path.endsWith('/$collection/records'),
  );

  List<http.Request> get batchRequests =>
      requests.where((r) => r.url.path == '/api/batch').toList();

  List<Map<String, dynamic>> batchBody(int index) =>
      ((jsonDecode(batchRequests[index].body) as Map)['requests'] as List)
          .cast<Map<String, dynamic>>();

  MockClient get client => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/batch') {
      final scripted = _batchCount < batches.length
          ? batches[_batchCount]
          : null;
      _batchCount++;
      if (scripted != null) return scripted;
      final count =
          ((jsonDecode(request.body) as Map)['requests'] as List).length;
      return http.Response(
        jsonEncode([
          for (var i = 0; i < count; i++) {'status': 200, 'body': {}},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/spending_cap/records')) return listJson(caps);
    if (path.endsWith('/spending_cap_alert/records')) return listJson(alerts);
    if (path.endsWith('/purchase_item/records')) return listJson(items);
    return errorJson(404);
  });
}

Map<String, dynamic> _capRecord(String id, int amount, String from) =>
    recordJson(id, {'amount': amount, 'effective_from': from});

Map<String, dynamic> _alertRecord({String? w80, String? w100}) =>
    recordJson(_alertId, {
      'month': '2026-08-01 00:00:00.000Z',
      'warned_80_at': w80 ?? '',
      'warned_100_at': w100 ?? '',
    });

Map<String, dynamic> _item(
  String id,
  String purchaseId,
  int paid,
  String day,
) => recordJson(
  id,
  {'purchase_id': purchaseId, 'total_paid': paid},
  expand: {
    'purchase_id': recordJson(purchaseId, {'purchase_date': day}),
  },
);

SpendingCapRepositoryRemote _repo(
  MockClient client, {
  DateTime Function()? clock,
}) => SpendingCapRepositoryRemote(
  testPocketBase(client),
  clock: clock ?? () => _clock,
);

void main() {
  group('errors', () {
    test('both methods go through rethrowAsKnownFailure', () async {
      final repo = _repo(MockClient((_) async => errorJson(400)));
      await expectLater(
        repo.fetchStatuses([_august].lock),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        repo.save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1))),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('without a session both fail with 401 and make no request', () async {
      final fake = _Fake();
      final repo = SpendingCapRepositoryRemote(
        testPocketBase(fake.client, signedIn: false),
      );
      for (final call in [
        () => repo.fetchStatuses([_august].lock),
        () => repo.fetchStatuses(const IList.empty()),
        () =>
            repo.save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1))),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 401),
          ),
        );
      }
      expect(fake.requests, isEmpty);
    });

    test('without network both fail with NetworkException', () async {
      final repo = _repo(offlineClient());
      await expectLater(
        repo.fetchStatuses([_august].lock),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        repo.save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1))),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('fetchStatuses', () {
    test('no month asked makes no request', () async {
      final fake = _Fake();
      final result = await _repo(
        fake.client,
      ).fetchStatuses(const IList.empty());
      expect(result, isEmpty);
      expect(fake.requests, isEmpty);
    });

    test('sends one interval per month, both ends by the codec', () async {
      final fake = _Fake();
      await _repo(fake.client).fetchStatuses(
        [_august, ReportPeriod.monthOf(DateTime(2026, 9, 10))].lock,
      );

      expect(fake.get('spending_cap'), hasLength(1));
      expect(fake.get('spending_cap_alert'), hasLength(1));
      final items = fake.get('purchase_item').single;
      final filter = items.url.queryParameters['filter']!;
      expect(
        filter,
        contains('purchase_id.purchase_date >= "2026-08-01 00:00:00.000Z"'),
      );
      expect(
        filter,
        contains('purchase_id.purchase_date <= "2026-08-31 00:00:00.000Z"'),
      );
      expect(
        filter,
        contains('purchase_id.purchase_date >= "2026-09-01 00:00:00.000Z"'),
      );
      expect(
        filter,
        contains('purchase_id.purchase_date <= "2026-09-30 00:00:00.000Z"'),
      );
      expect(items.url.queryParameters['expand'], 'purchase_id');
      final alertFilter = fake
          .get('spending_cap_alert')
          .single
          .url
          .queryParameters['filter']!;
      expect(alertFilter, contains('2026-08-01'));
      expect(alertFilter, contains('2026-09-01'));
    });

    test('reads the cap, the spending and the two marks', () async {
      final fake = _Fake(
        caps: [_capRecord(_capId, 150000, '2026-05-01 00:00:00.000Z')],
        items: [
          _item(
            'item00000000001',
            'purch0000000001',
            100000,
            '2026-08-03 00:00:00.000Z',
          ),
          _item(
            'item00000000002',
            'purch0000000002',
            30000,
            '2026-08-20 00:00:00.000Z',
          ),
        ],
        alerts: [_alertRecord(w80: '2026-08-10 14:00:00.000Z')],
      );
      final status = (await _repo(
        fake.client,
      ).fetchStatuses([_august].lock)).single;

      expect(status.month, DateTime(2026, 8, 1));
      expect(status.cap!.effectiveFrom, DateTime(2026, 5, 1));
      expect(status.spent, const Money(130000));
      expect(status.alerts.warned80, isTrue);
      expect(status.alerts.warned100, isFalse);
    });

    test('a month with no cap reads as no cap', () async {
      final status = (await _repo(
        _Fake().client,
      ).fetchStatuses([_august].lock)).single;
      expect(status.hasCap, isFalse);
      expect(status.spent, Money.zero);
    });

    test('takes the cap of each month, ordered by month', () async {
      final fake = _Fake(
        caps: [
          _capRecord(_capId, 150000, '2026-05-01 00:00:00.000Z'),
          _capRecord('cap000000000002', 180000, '2026-09-01 00:00:00.000Z'),
        ],
      );
      final result = await _repo(fake.client).fetchStatuses(
        [ReportPeriod.monthOf(DateTime(2026, 9, 5)), _august].lock,
      );
      expect(result.map((s) => s.cap!.amount), [
        const Money(150000),
        const Money(180000),
      ]);
      expect(result.first.month, DateTime(2026, 8, 1));
    });

    test('a hand-written cap of zero reads as no cap', () async {
      final fake = _Fake(
        caps: [_capRecord(_capId, 0, '2026-08-01 00:00:00.000Z')],
      );
      final status = (await _repo(
        fake.client,
      ).fetchStatuses([_august].lock)).single;
      expect(status.hasCap, isFalse);
    });
  });

  group('save', () {
    test('creates the cap and the wanted marks', () async {
      final fake = _Fake();
      await _repo(fake.client).save(
        cap: _cap,
        alerts: CapAlerts(
          month: DateTime(2026, 8, 1),
          warned80: true,
          warned100: true,
        ),
      );

      expect(
        fake.get('spending_cap').single.url.queryParameters['filter'],
        contains('effective_from = "2026-08-01 00:00:00.000Z"'),
      );
      expect(fake.batchRequests, hasLength(1));
      final body = fake.batchBody(0);
      expect(body, hasLength(2));
      expect(body[0]['method'], 'POST');
      expect(body[0]['url'], endsWith('spending_cap/records'));
      final capBody = body[0]['body'] as Map<String, dynamic>;
      expect(capBody['amount'], 150000);
      expect(capBody['effective_from'], '2026-08-01 00:00:00.000Z');
      expect(capBody['user'], testUserId);
      expect(isRecordId(capBody['id'] as String), isTrue);
      expect(body[1]['method'], 'POST');
      expect(body[1]['url'], endsWith('spending_cap_alert/records'));
      final alertBody = body[1]['body'] as Map<String, dynamic>;
      expect(alertBody['warned_80_at'], _stamp);
      expect(alertBody['warned_100_at'], _stamp);
    });

    test('updates the cap that already exists', () async {
      final fake = _Fake(
        caps: [_capRecord(_capId, 100000, '2026-08-01 00:00:00.000Z')],
      );
      await _repo(
        fake.client,
      ).save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1)));
      final body = fake.batchBody(0);
      expect(body, hasLength(1));
      expect(body.single['method'], 'PATCH');
      expect(body.single['url'], endsWith('spending_cap/records/$_capId'));
      expect(body.single['body'], {'amount': 150000});
    });

    test('rearm ignores the old stamp', () async {
      final fake = _Fake(
        alerts: [
          _alertRecord(
            w80: '2026-08-05 09:00:00.000Z',
            w100: '2026-08-05 09:00:00.000Z',
          ),
        ],
      );
      await _repo(fake.client).save(
        cap: _cap,
        alerts: CapAlerts(month: DateTime(2026, 8, 1), warned80: true),
      );
      final last = fake.batchBody(0).last;
      expect(last['method'], 'PATCH');
      expect(last['url'], endsWith('spending_cap_alert/records/$_alertId'));
      final body = last['body'] as Map<String, dynamic>;
      expect(body['warned_80_at'], _stamp);
      expect(body['warned_100_at'], '');
    });

    test('a full rearm deletes the stored mark', () async {
      final fake = _Fake(
        alerts: [_alertRecord(w80: '2026-08-05 09:00:00.000Z')],
      );
      await _repo(
        fake.client,
      ).save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1)));
      final last = fake.batchBody(0).last;
      expect(last['method'], 'DELETE');
      expect(last['url'], endsWith('spending_cap_alert/records/$_alertId'));
    });

    test('a 409 reads again and updates', () async {
      // The first read finds nothing; the second finds the cap the other
      // phone created in between.
      var capReads = 0;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/api/batch') {
          final batches = requests.where((r) => r.url.path == '/api/batch');
          if (batches.length == 1) {
            return batchErrorJson(index: 0, status: 400, data: _uniqueError);
          }
          return http.Response(
            jsonEncode([
              {'status': 200, 'body': {}},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/spending_cap/records')) {
          capReads++;
          return listJson(
            capReads == 1
                ? []
                : [_capRecord(_capId, 100000, '2026-08-01 00:00:00.000Z')],
          );
        }
        return listJson([]);
      });

      await _repo(
        client,
      ).save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1)));

      bool isGet(http.Request r, String c) =>
          r.method == 'GET' && r.url.path.endsWith('/$c/records');
      expect(requests.where((r) => isGet(r, 'spending_cap')), hasLength(2));
      expect(
        requests.where((r) => isGet(r, 'spending_cap_alert')),
        hasLength(2),
      );
      final batches = requests
          .where((r) => r.url.path == '/api/batch')
          .toList();
      expect(batches, hasLength(2));
      final second = (jsonDecode(batches[1].body) as Map)['requests'] as List;
      expect((second.first as Map)['method'], 'PATCH');
      expect(
        (second.first as Map)['url'],
        endsWith('spending_cap/records/$_capId'),
      );
    });

    test('the stamp comes from the clock, in UTC', () async {
      final fake = _Fake();
      await _repo(fake.client, clock: () => DateTime(2026, 8, 18, 12, 30)).save(
        cap: _cap,
        alerts: CapAlerts(month: DateTime(2026, 8, 1), warned80: true),
      );
      final alertBody = fake.batchBody(0).last['body'] as Map<String, dynamic>;
      expect(
        alertBody['warned_80_at'],
        encodeInstant(DateTime(2026, 8, 18, 12, 30)),
      );
    });

    test('a second 409 does not try a third time', () async {
      final conflict = batchErrorJson(
        index: 0,
        status: 400,
        data: _uniqueError,
      );
      final fake = _Fake(batches: [conflict, conflict]);
      await expectLater(
        _repo(
          fake.client,
        ).save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 8, 1))),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(fake.batchRequests, hasLength(2));
    });

    test('another batch failure does not repeat', () async {
      final fake = _Fake(batches: [batchErrorJson(index: 1, status: 404)]);
      await expectLater(
        _repo(fake.client).save(
          cap: _cap,
          alerts: CapAlerts(month: DateTime(2026, 8, 1), warned80: true),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect(fake.batchRequests, hasLength(1));
    });

    test(
      'alerts of another month than the cap fail before any request',
      () async {
        final fake = _Fake();
        await expectLater(
          _repo(
            fake.client,
          ).save(cap: _cap, alerts: CapAlerts.none(DateTime(2026, 9, 1))),
          throwsArgumentError,
        );
        expect(fake.requests, isEmpty);
      },
    );
  });
}
