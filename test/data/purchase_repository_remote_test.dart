import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_remote.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/purchase.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// A query chain that answers a fixed set of rows. Like `rpc`, none of these
/// builders is a Future — they only IMPLEMENT one — so `thenAnswer` with an
/// `async` closure does not compile, and `then` is what `await` reaches.
class _FakeQuery extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeQuery(this.rows);

  final PostgrestList rows;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

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
/// does not compile, so the success cases need a stand-in whose `then` is
/// what `await` reaches. The failing cases use `thenThrow`, which needs none
/// of this.
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

/// The one inviolable rule of every `_remote` method, held by a test — and
/// the one thing about `create_purchase` that a happy path never shows: a
/// resend that arrived twice answers "already registered" instead of writing
/// a second purchase.
void main() {
  late _MockClient client;
  late PurchaseRepositoryRemote repository;

  final submission = PurchaseSubmission(
    purchase: Purchase(
      id: 'a1',
      date: DateTime(2026, 8, 18),
      storeId: 'store-1',
      registeredBy: 'Leandro',
      items: [
        purchaseItem(
          id: 'i1',
          option: optionByPiece(id: 'prod-4', pieceCount: 12),
          cents: 6200,
        ),
      ].lock,
    ),
    writeOffs: const IList<ListWriteOff>.empty(),
  );

  group('when PostgREST refuses', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
      // The failure is raised at the first hop of every chain, which is where
      // a real PostgrestException would surface anyway.
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
    });

    final calls = <String, Future<void> Function()>{
      'fetchProductOptions': () => repository.fetchProductOptions(),
      'fetchRecentItems': () =>
          repository.fetchRecentItems(DateTime(2026, 5, 28)),
      'save': () => repository.save(submission),
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

  group('save', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
    });

    test('answers true when the purchase was already registered', () async {
      // H8's resend that arrived twice. It is NOT an error: the purchase is
      // there, the list was written off once, and the draft has to die all
      // the same.
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) => _FakeRpc({'already_registered': true, 'purchase_id': 'a1'}),
      );

      expect(await repository.save(submission), isTrue);
    });

    test('answers false for a purchase that was written now', () async {
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) => _FakeRpc({'already_registered': false, 'purchase_id': 'a1'}),
      );

      expect(await repository.save(submission), isFalse);
    });

    test('sends the purchase, the items and the write-offs apart', () async {
      // The three arguments of the function, and the items do NOT carry a
      // purchase_id: it is the same for all of them and comes from the first
      // argument.
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<Map<String, dynamic>>(
          any(),
          params: any(named: 'params'),
        ),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeRpc({'already_registered': false});
      });

      await repository.save(submission);

      expect(sent!['p_purchase'], {
        'id': 'a1',
        'purchase_date': '2026-08-18',
        'store_id': 'store-1',
        'registered_by': 'Leandro',
      });
      final items = sent!['p_items'] as List;
      expect(items, hasLength(1));
      expect(
        (items.single as Map<String, dynamic>).containsKey('purchase_id'),
        isFalse,
      );
      expect(sent!['p_write_offs'], isEmpty);
    });
  });

  group('reading', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
    });

    test('reads the picker out of the embed, brand and all', () async {
      // The shape of the query is the contract here: the registration comes
      // nested, and the type and the brand nested inside it. A `!inner` put
      // on `brand` would make the weight-sold product disappear, which is why
      // the null one is in this fixture too.
      // `thenAnswer`, not `thenReturn`: the builder implements Future, and
      // mocktail refuses to return one directly.
      when(() => client.from('product')).thenAnswer(
        (_) => _FakeTable([
          {
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
              },
              'brand': {'id': 'brand-1', 'name': 'Coca-Cola', 'active': true},
            },
          },
          {
            'id': 'prod-5',
            'product_registration_id': 'reg-2',
            'active': true,
            'product_registration': {
              'id': 'reg-2',
              'product_type_id': 'type-2',
              'brand_id': null,
              'description': '',
              'selling_mode': 'by_weight',
              'active': true,
              'product_type': {
                'id': 'type-2',
                'name': 'Acém moído',
                'category_id': 'cat-2',
                'base_unit': 'kilogram',
                'active': true,
              },
              'brand': null,
            },
          },
        ]),
      );

      final options = await repository.fetchProductOptions();

      expect(options, hasLength(2));
      expect(options.first.label, 'Coca-Cola 12 × 350 ml');
      expect(options.first.toBaseUnit(1), 4200);
      // "Sem marca" is a real answer (decision B2), and it has to survive.
      expect(options.last.brand, isNull);
      expect(options.last.label, 'Acém moído (a peso)');
    });

    test('reads the history with the date from the PARENT table', () async {
      // The filter is on `purchase.purchase_date`, which is what `!inner`
      // makes possible — and there is no `order` in the query, because
      // ordering an embedded table in PostgREST orders the children.
      when(() => client.from('purchase_item')).thenAnswer(
        (_) => _FakeTable([
          {
            'product_id': 'prod-4',
            'quantity_in_base_unit': 4200,
            'total_paid': 6200,
            'purchase': {'purchase_date': '2026-08-18'},
          },
        ]),
      );

      final history = await repository.fetchRecentItems(DateTime(2026, 5, 28));

      expect(history, hasLength(1));
      expect(history.single.productId, 'prod-4');
      expect(history.single.quantityInBaseUnit, 4200);
      expect(history.single.paid, const Money(6200));
      expect(history.single.purchasedOn, DateTime(2026, 8, 18));
    });
  });
}
