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

/// A query chain that answers a fixed set of rows. Like `rpc`, none of these
/// builders is a Future — they only IMPLEMENT one — so `thenAnswer` with an
/// `async` closure does not compile, and `then` is what `await` reaches.
class _FakeQuery extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeQuery(this.rows);

  final PostgrestList rows;

  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) =>
      this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList) onValue, {
    Function? onError,
  }) => Future.value(rows).then(onValue, onError: onError);
}

class _FakeTable extends Fake implements SupabaseQueryBuilder {
  _FakeTable(this.rows);

  final PostgrestList rows;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeQuery(rows);
}

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

  test('fetchPriceQuotes translates the SQLSTATE instead of leaking it', () {
    // Same inviolable rule, on the second method: without
    // `rethrowAsKnownFailure` the '23505' is read as a number, falls into the
    // `>= 500` arm and tells the user the server is down.
    when(() => client.from('purchase_item')).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    expect(
      () => repository.fetchPriceQuotes(DateTime(2026, 5, 30)),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('fetchPriceQuotes reads the leaf, the category and the store', () async {
    // One select with four embeds: the product embed is EXACTLY the nested
    // shape `ProductOption.fromJson` reads, the category comes one level
    // deeper because the picker groups by it, and the store comes with
    // `active` — without that column a deactivated shop would come back
    // active and the `==` of PriceQuote would diverge from the fake.
    when(() => client.from('purchase_item')).thenAnswer(
      (_) => _FakeTable([
        {
          'quantity_in_base_unit': 4200,
          'total_paid': 4800,
          'purchase': {
            'purchase_date': '2026-07-03',
            'store': {
              'id': 'store-3',
              'name': 'Mercearia do Zé',
              'active': false,
            },
          },
          'product': {
            'id': 'prod-4',
            'product_registration_id': 'reg-1',
            'piece_count': 12,
            'piece_size': 350,
            'piece_size_unit': 'milliliter',
            'total_content': 4200,
            'active': true,
            'product_registration': {
              'id': 'reg-1',
              'product_type_id': 'type-1',
              'brand_id': 'brand-1',
              'description': '',
              'selling_mode': 'by_piece',
              'active': true,
              'product_type': {
                'id': 'type-1',
                'name': 'Refrigerante',
                'category_id': 'cat-1',
                'base_unit': 'liter',
                'active': true,
                'category': {'id': 'cat-1', 'name': 'Bebidas'},
              },
              'brand': {'id': 'brand-1', 'name': 'Coca-Cola', 'active': true},
            },
          },
        },
      ]),
    );

    final quotes = await repository.fetchPriceQuotes(DateTime(2026, 5, 30));

    expect(quotes, hasLength(1));
    expect(quotes.single.option.label, 'Coca-Cola 12 × 350 ml');
    expect(quotes.single.categoryId, 'cat-1');
    expect(quotes.single.categoryName, 'Bebidas');
    expect(quotes.single.store.name, 'Mercearia do Zé');
    // The deactivated shop stays deactivated: buying there is a fact of the
    // past (requirement 16), and the `==` depends on the flag.
    expect(quotes.single.store.active, isFalse);
    expect(quotes.single.paid, const Money(4800));
    expect(quotes.single.purchasedOn, DateTime(2026, 7, 3));
    // R$ 11,43 a litre — the head of the wireframe's table.
    expect(quotes.single.costPerBaseUnit, 1143);
    // The history comes EMPTY: here the option is identity and label, not
    // ranking.
    expect(quotes.single.option.purchaseCount, 0);
    expect(quotes.single.option.baseline, isNull);
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
