import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/report/report_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// `rpc` does not return a Future — it returns a `PostgrestFilterBuilder`,
/// which only IMPLEMENTS one. Stubbing it with `thenAnswer((_) async => …)`
/// does not compile, so the success case needs a stand-in whose `then` is what
/// `await` reaches. The failing cases use `thenThrow`, which needs none of
/// this.
class _FakeRpc extends Fake
    implements PostgrestFilterBuilder<Map<String, dynamic>> {
  _FakeRpc(this.value);

  final Map<String, dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

/// The one inviolable rule of every `_remote` method, held by a test: the
/// call closes on `rethrowAsKnownFailure`, so a SQLSTATE never reaches
/// AppFailure as an HTTP status.
void main() {
  late _MockClient client;
  late ReportRepositoryRemote repository;

  final period = ReportPeriod(
    from: DateTime(2026, 8, 1),
    to: DateTime(2026, 8, 31),
  );

  setUp(() {
    client = _MockClient();
    repository = ReportRepositoryRemote(client);
  });

  test('fetchPeriodReport translates the SQLSTATE instead of leaking it', () {
    // Without `rethrowAsKnownFailure` the SQLSTATE arrives as "status 23505",
    // falls into the `>= 500` arm of AppFailure and tells the user the server
    // is down.
    when(
      () => client.rpc<Map<String, dynamic>>(
        any(),
        params: any(named: 'params'),
      ),
    ).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    expect(
      () => repository.fetchPeriodReport(period),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
    );
  });

  test('a transport failure becomes NetworkException', () {
    // `postgrest` speaks through `http`, so this is how a phone with no
    // connection reports itself.
    when(
      () => client.rpc<Map<String, dynamic>>(
        any(),
        params: any(named: 'params'),
      ),
    ).thenThrow(ClientException('offline'));

    expect(
      () => repository.fetchPeriodReport(period),
      throwsA(isA<NetworkException>()),
    );
  });

  test('reads the three aggregations out of the one call', () async {
    when(
      () => client.rpc<Map<String, dynamic>>(
        any(),
        params: any(named: 'params'),
      ),
    ).thenAnswer(
      (_) => _FakeRpc(const {
        'categories': [
          {
            'category_id': 'cat-2',
            'category_name': 'Carnes',
            'total_paid': 19200,
          },
        ],
        'types': [
          {
            'product_type_id': 'type-2',
            'product_type_name': 'Acém moído',
            'category_id': 'cat-2',
            'base_unit': 'kilogram',
            'quantity_in_base_unit': 6000,
            'total_paid': 19200,
          },
        ],
        'brands': [
          {
            'product_type_id': 'type-2',
            'brand_id': null,
            'brand_name': null,
            'quantity_in_base_unit': 6000,
            'total_paid': 19200,
          },
        ],
      }),
    );

    final report = await repository.fetchPeriodReport(period);

    expect(report.total, const Money(19200));
    expect(report.types.single.baseUnit, BaseUnit.kilogram);
    expect(report.types.single.costPerBaseUnit, 3200);
    expect(report.brands.single.hasBrand, isFalse);
  });

  test('sends the interval as two calendar days, never as a timestamp', () async {
    // `purchase_date` is a `date` in Postgres: an ISO instant would not
    // compare against it the way the query assumes.
    Map<String, dynamic>? sent;
    when(
      () => client.rpc<Map<String, dynamic>>(
        any(),
        params: any(named: 'params'),
      ),
    ).thenAnswer((invocation) {
      sent = invocation.namedArguments[#params] as Map<String, dynamic>;
      return _FakeRpc(const {
        'categories': <Object>[],
        'types': <Object>[],
        'brands': <Object>[],
      });
    });

    await repository.fetchPeriodReport(period);

    expect(sent, {'p_from': '2026-08-01', 'p_to': '2026-08-31'});
  });

  test('an empty period is a value, not an error', () async {
    when(
      () => client.rpc<Map<String, dynamic>>(
        any(),
        params: any(named: 'params'),
      ),
    ).thenAnswer(
      (_) => _FakeRpc(const {
        'categories': <Object>[],
        'types': <Object>[],
        'brands': <Object>[],
      }),
    );

    expect((await repository.fetchPeriodReport(period)).isEmpty, isTrue);
  });
}
