import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// `rpc` does not return a Future — it returns a `PostgrestFilterBuilder`,
/// which only IMPLEMENTS one. Stubbing it with `thenAnswer((_) async => …)`
/// does not compile, so the success case needs a stand-in whose `then` is what
/// `await` reaches. The failing cases use `thenThrow`, which needs none of
/// this. The trap has already cost half an hour once, in
/// `purchase_repository_remote_test.dart`.
class _FakeRpc extends Fake implements PostgrestFilterBuilder<List<dynamic>> {
  _FakeRpc(this.value);

  final List<dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

/// The one inviolable rule of every `_remote` method, held by a test: the call
/// closes on `rethrowAsKnownFailure`, so a SQLSTATE never reaches AppFailure
/// as an HTTP status.
void main() {
  late _MockClient client;
  late ConsumptionRepositoryRemote repository;

  final window = ReportPeriod(
    from: DateTime(2026, 5, 1),
    to: DateTime(2026, 7, 31),
  );
  final month = ReportPeriod(
    from: DateTime(2026, 8, 1),
    to: DateTime(2026, 8, 31),
  );

  setUp(() {
    client = _MockClient();
    repository = ConsumptionRepositoryRemote(client);
  });

  test('translates the SQLSTATE instead of leaking it', () {
    // Without `rethrowAsKnownFailure` the SQLSTATE arrives as "status 23505",
    // falls into the `>= 500` arm of AppFailure and tells the user the server
    // is down.
    when(
      () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
    ).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    expect(
      () => repository.fetchTypeConsumption(window: window, month: month),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('a transport failure becomes a NetworkException', () {
    // The `postgrest` package speaks through `http`, so this is how a dropped
    // connection actually arrives.
    when(
      () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
    ).thenThrow(ClientException('connection closed'));

    expect(
      () => repository.fetchTypeConsumption(window: window, month: month),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'sends the FOUR dates as calendar days, and reads the rows back',
    () async {
      // The four intervals come from the ViewModel, off the phone's clock: no
      // `now()` and no `current_date` in SQL (decision 7). What this case holds
      // is that both ends of both periods travel, in the 'yyyy-MM-dd' Postgres
      // reads.
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeRpc([
          {
            'product_type_id': 'type-5',
            'product_type_name': 'Café',
            'category_id': 'cat-4',
            'category_name': 'Mercearia',
            'base_unit': 'kilogram',
            'type_active': true,
            'category_active': true,
            'consumed_in_window': 2000,
            'consumed_in_month': 0,
            'first_purchase_on': '2026-03-10',
          },
        ]),
      );

      final rows = await repository.fetchTypeConsumption(
        window: window,
        month: month,
      );

      final captured = verify(
        () => client.rpc<List<dynamic>>(
          captureAny(),
          params: captureAny(named: 'params'),
        ),
      ).captured;

      expect(captured.first, 'type_consumption');
      expect(captured[1], {
        'p_window_from': '2026-05-01',
        'p_window_to': '2026-07-31',
        'p_month_from': '2026-08-01',
        'p_month_to': '2026-08-31',
      });

      expect(rows, hasLength(1));
      expect(rows.first.type.name, 'Café');
      expect(rows.first.type.baseUnit, BaseUnit.kilogram);
      expect(rows.first.category.name, 'Mercearia');
      expect(rows.first.consumedInWindow, 2000);
      expect(rows.first.consumedInMonth, 0);
      expect(rows.first.firstPurchaseOn, DateTime(2026, 3, 10));
    },
  );

  test('a deactivated type comes back flagged, not filtered out', () {
    // Decision E-e: the flag travels and DART is what discards. Filtering here
    // would put a rule of H10 inside a repository, which does I/O and nothing
    // else (rule 3).
    when(
      () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
    ).thenAnswer(
      (_) => _FakeRpc([
        {
          'product_type_id': 'type-9',
          'product_type_name': 'Desativado',
          'category_id': 'cat-4',
          'category_name': 'Mercearia',
          'base_unit': 'kilogram',
          'type_active': false,
          'category_active': true,
          'consumed_in_window': 3000,
          'consumed_in_month': 0,
          'first_purchase_on': '2026-05-12',
        },
      ]),
    );

    expect(
      repository.fetchTypeConsumption(window: window, month: month),
      completion(
        allOf(
          hasLength(1),
          predicate<Iterable<Object?>>(
            (rows) => (rows.first! as dynamic).type.active == false,
            'keeps type_active false',
          ),
        ),
      ),
    );
  });

  test('an empty answer is an empty list, not an error', () {
    // `coalesce(…, '[]'::jsonb)` in the migration is what makes this shape
    // reachable: the empty period is a state to draw, not a failure.
    when(
      () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => _FakeRpc(const []));

    expect(
      repository.fetchTypeConsumption(window: window, month: month),
      completion(isEmpty),
    );
  });
}
