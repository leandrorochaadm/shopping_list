import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// `rpc` does not return a Future — it returns a `PostgrestFilterBuilder`,
/// which only IMPLEMENTS one. Stubbing it with `thenAnswer((_) async => …)`
/// does not compile, so the success cases need a stand-in whose `then` is
/// what `await` reaches. The failing cases use `thenThrow`, which needs none
/// of this.
class _FakeListRpc extends Fake implements PostgrestFilterBuilder<List<dynamic>> {
  _FakeListRpc(this.value);

  final List<dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

class _FakeVoidRpc extends Fake implements PostgrestFilterBuilder<void> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(void) onValue, {
    Function? onError,
  }) => Future<void>.value().then(onValue, onError: onError);
}

void main() {
  late _MockClient client;
  late SpendingCapRepositoryRemote repository;

  final august = ReportPeriod.monthOf(DateTime(2026, 8, 15));
  final cap = SpendingCap(
    amount: const Money(150000),
    effectiveFrom: DateTime(2026, 8, 1),
  );

  setUp(() {
    client = _MockClient();
    repository = SpendingCapRepositoryRemote(client);
  });

  group('when PostgREST refuses', () {
    setUp(() {
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
    });

    final calls = <String, Future<void> Function()>{
      'fetchStatuses': () => repository.fetchStatuses([august].lock),
      'save': () =>
          repository.save(cap: cap, alerts: CapAlerts.none(DateTime(2026, 8, 1))),
    };

    for (final entry in calls.entries) {
      test('${entry.key} translates the SQLSTATE instead of leaking it', () {
        // Without `rethrowAsKnownFailure` the SQLSTATE arrives as
        // "status 23505", falls into the `>= 500` arm of AppFailure and tells
        // the user the server is down.
        expect(
          entry.value,
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );
      });
    }
  });

  group('fetchStatuses', () {
    test('sends one entry per month, with both ends of it', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeListRpc(const []);
      });

      await repository.fetchStatuses([
        august,
        ReportPeriod.monthOf(DateTime(2026, 9, 10)),
      ].lock);

      // Both dates come from the phone's clock: no `now()` in SQL.
      expect(sent!['p_months'], [
        {'month': '2026-08-01', 'last_day': '2026-08-31'},
        {'month': '2026-09-01', 'last_day': '2026-09-30'},
      ]);
    });

    test('reads the cap, the spending and the two marks', () async {
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeListRpc([
          {
            'month': '2026-08-01',
            'cap_amount': 150000,
            'cap_effective_from': '2026-05-01',
            'spent': 130000,
            'warned_80': true,
            'warned_100': false,
          },
        ]),
      );

      final statuses = await repository.fetchStatuses([august].lock);

      expect(statuses, hasLength(1));
      expect(statuses.first.month, DateTime(2026, 8, 1));
      // The month the cap started in, not the month asked about.
      expect(statuses.first.cap!.effectiveFrom, DateTime(2026, 5, 1));
      expect(statuses.first.spent, const Money(130000));
      expect(statuses.first.alerts.warned80, isTrue);
      expect(statuses.first.alerts.warned100, isFalse);
    });

    test('reads a month with no cap without falling over', () async {
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeListRpc([
          {
            'month': '2026-07-01',
            'cap_amount': null,
            'cap_effective_from': null,
            'spent': 0,
            'warned_80': false,
            'warned_100': false,
          },
        ]),
      );

      final statuses = await repository.fetchStatuses([august].lock);

      expect(statuses.first.hasCap, isFalse);
      expect(statuses.first.spent, Money.zero);
    });
  });

  group('save', () {
    test('sends the cents, day 1 of the month and the desired marks', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeVoidRpc();
      });

      await repository.save(
        cap: cap,
        alerts: CapAlerts(
          month: DateTime(2026, 8, 1),
          warned80: true,
          warned100: true,
        ),
      );

      expect(sent!['p_amount'], 150000);
      expect(sent!['p_effective_from'], '2026-08-01');
      expect(sent!['p_alerts'], [
        {'month': '2026-08-01', 'warned_80': true, 'warned_100': true},
      ]);
    });
  });
}
