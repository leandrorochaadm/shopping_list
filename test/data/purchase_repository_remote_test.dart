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
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';
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

  /// The `eq` filters the chain applied, in the order they came. A fake that
  /// answers `this` to everything swallows the WHERE silently, and there are
  /// queries here whose filter IS the rule — `fetchProductOptions` keeps the
  /// deactivated leaf out of screen 3 and out of the `#3a` panel, and it does
  /// that in SQL and nowhere else.
  final filters = <String, Object>{};

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) =>
      this;

  @override
  PostgrestFilterBuilder<PostgrestList> inFilter(
    String column,
    List<dynamic> values,
  ) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;

  /// `single()` narrows the chain from a list to a map, so it cannot answer
  /// with `this` — the fake has to change shape exactly where the real
  /// builder does.
  @override
  PostgrestTransformBuilder<PostgrestMap> single() =>
      _FakeSingle(rows.isEmpty ? const {} : rows.first);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList) onValue, {
    Function? onError,
  }) => Future.value(rows).then(onValue, onError: onError);
}

class _FakeSingle extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  _FakeSingle(this.row);

  final PostgrestMap row;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap) onValue, {
    Function? onError,
  }) => Future.value(row).then(onValue, onError: onError);
}

/// The void RPCs of H9. Same trap as `_FakeRpc`: `rpc` is not a Future, it
/// only implements one.
class _FakeVoidRpc extends Fake implements PostgrestFilterBuilder<void> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(void) onValue, {
    Function? onError,
  }) => Future<void>.value().then(onValue, onError: onError);
}

/// H14's read. Same trap as `_FakeRpc`: `rpc` is not a Future.
class _FakeSameDayRpc extends Fake
    implements PostgrestFilterBuilder<List<dynamic>> {
  _FakeSameDayRpc(this.value);

  final List<dynamic> value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<dynamic>) onValue, {
    Function? onError,
  }) => Future.value(value).then(onValue, onError: onError);
}

class _FakeTable extends Fake implements SupabaseQueryBuilder {
  _FakeTable(this.rows);

  final PostgrestList rows;

  /// The chains `select` handed back, so a test can ask which filters were
  /// applied to them. A `final` list and not a nullable field: a mutable
  /// field would put `must_be_immutable` on this class, and the project's
  /// checklist wants `flutter analyze` clean.
  final queries = <_FakeQuery>[];

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    final query = _FakeQuery(rows);
    queries.add(query);
    return query;
  }
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
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
    });

    final calls = <String, Future<void> Function()>{
      'fetchProductOptions': () => repository.fetchProductOptions(),
      'fetchRecentItems': () =>
          repository.fetchRecentItems(DateTime(2026, 5, 28)),
      'save': () => repository.save(submission),
      'fetchPage': () => repository.fetchPage(offset: 0, limit: 20),
      'fetchDetail': () => repository.fetchDetail('a1'),
      'correct': () => repository.correct(
        purchase: submission.purchase,
        writeOffs: const IList<ListWriteOff>.empty(),
        restored: const IList<RestoredListItem>.empty(),
      ),
      'delete': () => repository.delete(
        purchaseId: 'a1',
        restored: const IList<RestoredListItem>.empty(),
      ),
      'fetchSameDayTypes': () => repository.fetchSameDayTypes(
        date: DateTime(2026, 8, 18),
        registeredBy: 'Leandro',
        productTypeIds: const ISet<String>.empty(),
      ),
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
      // H13: the month's marks travel WITH the purchase, in the same
      // transaction — empty here, which is a month with no cap.
      expect(sent!['p_cap_alerts'], isEmpty);
    });

    test('sends the month marks the domain decided', () async {
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

      await repository.save(
        PurchaseSubmission(
          purchase: submission.purchase,
          writeOffs: const IList<ListWriteOff>.empty(),
          capAlerts: [
            CapAlerts(
              month: DateTime(2026, 8, 1),
              warned80: true,
              warned100: false,
            ),
          ].lock,
        ),
      );

      expect(sent!['p_cap_alerts'], [
        {'month': '2026-08-01', 'warned_80': true, 'warned_100': false},
      ]);
    });
  });

  group('the correction and the deletion carry the marks too', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
    });

    test('correct sends p_cap_alerts, one entry per month affected', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeVoidRpc();
      });

      await repository.correct(
        purchase: submission.purchase,
        writeOffs: const IList<ListWriteOff>.empty(),
        restored: const IList<RestoredListItem>.empty(),
        // TWO months: the correction moved the purchase across the turn of
        // one, so the month it left may have rearmed.
        capAlerts: [
          CapAlerts(month: DateTime(2026, 8, 1)),
          CapAlerts(month: DateTime(2026, 9, 1), warned80: true),
        ].lock,
      );

      expect(sent!['p_cap_alerts'], [
        {'month': '2026-08-01', 'warned_80': false, 'warned_100': false},
        {'month': '2026-09-01', 'warned_80': true, 'warned_100': false},
      ]);
    });

    test('delete sends the rearm', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeVoidRpc();
      });

      await repository.delete(
        purchaseId: 'a1',
        restored: const IList<RestoredListItem>.empty(),
        capAlerts: [CapAlerts(month: DateTime(2026, 8, 1))].lock,
      );

      expect(sent!['p_cap_alerts'], [
        {'month': '2026-08-01', 'warned_80': false, 'warned_100': false},
      ]);
    });
  });

  group('fetchSameDayTypes', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
    });

    test('sends the day, the label and the types', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeSameDayRpc(const []);
      });

      await repository.fetchSameDayTypes(
        date: DateTime(2026, 8, 18),
        registeredBy: 'Leandro',
        productTypeIds: const ISetConst({'type-1'}),
      );

      // The day comes from the phone's clock — never `current_date`, which at
      // 21:00 UTC−4 on the 30th answers the 31st.
      expect(sent!['p_date'], '2026-08-18');
      expect(sent!['p_registered_by'], 'Leandro');
      expect(sent!['p_type_ids'], ['type-1']);
    });

    test('reads the types, keeping the day that was asked about', () async {
      when(
        () => client.rpc<List<dynamic>>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeSameDayRpc([
          {'product_type_id': 'type-1', 'name': 'Refrigerante'},
        ]),
      );

      final alerts = await repository.fetchSameDayTypes(
        date: DateTime(2026, 8, 18),
        registeredBy: 'Leandro',
        productTypeIds: const ISetConst({'type-1'}),
      );

      expect(alerts.single.typeName, 'Refrigerante');
      // The day is NOT in the answer: it is the one asked about, and the
      // sentence needs it to choose between "hoje" and "no dia 18/08".
      expect(alerts.single.purchasedOn, DateTime(2026, 8, 18));
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

    test('the deactivated leaf is left out — the filter is in SQL', () async {
      // `handoff §H19`: "um produto desativado fica de fora" do painel `#3a`
      // — and `handoff §H10` says the same about screen 3's picker. Neither
      // is decided in Dart: `costCandidatesOf` only cuts what it is handed,
      // and the panel opens over the very list this method returned.
      //
      // So the WHERE below IS the acceptance criterion. Without the assertion
      // its removal breaks two screens and no test turns red — the fixture
      // here is active either way, and the mapping keeps passing.
      final table = _FakeTable([
        {
          'id': 'prod-4',
          'product_registration_id': 'reg-1',
          'active': true,
          'piece_count': 12,
          'piece_size': 350,
          'piece_size_unit': 'milliliter',
          'total_content': 4200,
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
      ]);
      when(() => client.from('product')).thenAnswer((_) => table);

      await repository.fetchProductOptions();

      // Both flags, and the second one is the one easy to lose: a deactivated
      // REGISTRATION takes its leaves with it (`Product.isEffectivelyActiveIn`
      // is the same `&&`, on the read).
      expect(table.queries.single.filters, {
        'active': true,
        'product_registration.active': true,
      });
    });

    test('reads the history with the date from the PARENT table', () async {
      // The filter is on `purchase.purchase_date`, which is what `!inner`
      // makes possible — and there is no `order` in the query, because
      // ordering an embedded table in PostgREST orders the children.
      //
      // The type comes embedded two levels down, and NOT from the catalog:
      // `fetchProductOptions` filters `active = true`, and a leaf deactivated
      // in the middle of the window would take its purchases out of the
      // type's average (H15, requirement 16).
      when(() => client.from('purchase_item')).thenAnswer(
        (_) => _FakeTable([
          {
            'product_id': 'prod-4',
            'quantity_in_base_unit': 4200,
            'total_paid': 6200,
            'purchase': {'purchase_date': '2026-08-18'},
            'product': {
              'product_registration': {'product_type_id': 'type-1'},
            },
          },
        ]),
      );

      final history = await repository.fetchRecentItems(DateTime(2026, 5, 28));

      expect(history, hasLength(1));
      expect(history.single.productId, 'prod-4');
      expect(history.single.productTypeId, 'type-1');
      expect(history.single.quantityInBaseUnit, 4200);
      expect(history.single.paid, const Money(6200));
      expect(history.single.purchasedOn, DateTime(2026, 8, 18));
    });

    test('fetchPage asks for ONE row more and answers hasMore with it', () async {
      // `range` in PostgREST is inclusive at both ends, so `range(0, 20)`
      // brings 21 rows. The extra one is dropped, and its existence IS the
      // answer — no second query, and no count.
      when(() => client.from('purchase')).thenAnswer(
        (_) => _FakeTable([
          for (var i = 0; i < 21; i++)
            {
              'id': 'a\$i',
              'purchase_date': '2026-08-18',
              'registered_by': 'Leandro',
              'store': {'name': 'Carrefour'},
              'purchase_item': [
                {'total_paid': 6200},
                {'total_paid': 100},
              ],
            },
        ]),
      );

      final page = await repository.fetchPage(offset: 0, limit: 20);

      expect(page.purchases, hasLength(20));
      expect(page.hasMore, isTrue);
      // The total is added up in Dart, out of the embed (D9).
      expect(page.purchases.first.total, const Money(6300));
      expect(page.purchases.first.itemCount, 2);
      expect(page.purchases.first.storeName, 'Carrefour');
    });

    test('fetchPage on the last page answers hasMore false', () async {
      when(() => client.from('purchase')).thenAnswer(
        (_) => _FakeTable([
          for (var i = 0; i < 3; i++)
            {
              'id': 'a\$i',
              'purchase_date': '2026-08-18',
              'registered_by': 'Leandro',
              'store': {'name': 'Carrefour'},
              'purchase_item': <Map<String, dynamic>>[],
            },
        ]),
      );

      final page = await repository.fetchPage(offset: 0, limit: 20);

      expect(page.purchases, hasLength(3));
      expect(page.hasMore, isFalse);
    });

    test('fetchDetail is ONE call, with the trail embedded in the item', () async {
      // Two calls would mean building an `in.(…)` out of the ids the first
      // one returned — a round trip that depends on another, in the middle of
      // opening a screen. `list_write_off` has no purchase column, so the
      // embed is the only way.
      when(() => client.from('purchase')).thenAnswer(
        (_) => _FakeTable([
          {
            'id': 'a1',
            'purchase_date': '2026-08-18',
            'store_id': 'store-1',
            'registered_by': 'Leandro',
            'purchase_item': [
              {
                'id': 'i1',
                'product_id': 'prod-4',
                'quantity': 1,
                'quantity_in_base_unit': 4200,
                'total_paid': 6200,
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
                    },
                    'brand': {
                      'id': 'brand-1',
                      'name': 'Coca-Cola',
                      'active': true,
                    },
                  },
                },
                'list_write_off': [
                  {
                    'shopping_list_item_id': 'l1',
                    'quantity_written_off': 4200,
                    'cleared_not_found': true,
                  },
                ],
              },
            ],
          },
        ]),
      );

      final detail = await repository.fetchDetail('a1');

      verify(() => client.from('purchase')).called(1);
      expect(detail.purchase.id, 'a1');
      expect(detail.purchase.date, DateTime(2026, 8, 18));
      expect(detail.purchase.registeredBy, 'Leandro');
      // The line comes back COMPLETE, because the item carries the whole
      // option — no view around it, and no second query to the catalog.
      expect(detail.items.single.label, 'Coca-Cola 12 × 350 ml');
      expect(detail.items.single.paid, const Money(6200));
      expect(detail.trail.single.shoppingListItemId, 'l1');
      expect(detail.trail.single.purchaseItemId, 'i1');
      expect(detail.trail.single.clearedNotFound, isTrue);
      // `fulfills` is not a column, so it never comes back — the undo
      // DERIVES it (D6).
      expect(detail.trail.single.fulfills, isFalse);
    });
  });

  group('the correction', () {
    setUp(() {
      client = _MockClient();
      repository = PurchaseRepositoryRemote(client);
    });

    test('update_purchase sends the four keys, and fulfilled_on PRESENT', () async {
      // Omitting `fulfilled_on` would reopen nothing, and in silence — which
      // is the whole reason the key travels with a null VALUE.
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeVoidRpc();
      });

      await repository.correct(
        purchase: submission.purchase,
        writeOffs: [
          const ListWriteOff(
            purchaseItemId: 'i1',
            shoppingListItemId: 'l1',
            quantityWrittenOff: 2000,
            fulfills: true,
          ),
        ].lock,
        restored: const [
          RestoredListItem(id: 'l1', fulfilledOn: null, notFound: true),
        ].lock,
      );

      expect(sent!.keys, containsAll(<String>[
        'p_purchase',
        'p_items',
        'p_write_offs',
        'p_restored',
      ]));
      // Three columns, and `registered_by` is NOT one of them: who
      // registered a purchase is a historical fact.
      expect(sent!['p_purchase'], {
        'id': 'a1',
        'purchase_date': '2026-08-18',
        'store_id': 'store-1',
      });

      final restored = (sent!['p_restored'] as List).single
          as Map<String, dynamic>;
      expect(restored.containsKey('fulfilled_on'), isTrue);
      expect(restored['fulfilled_on'], isNull);
      expect(restored['not_found'], isTrue);

      // `fulfills` travels in the same object and is still not a column.
      final off = (sent!['p_write_offs'] as List).single
          as Map<String, dynamic>;
      expect(off['fulfills'], isTrue);
    });

    test('delete_purchase sends the id and what to give back', () async {
      Map<String, dynamic>? sent;
      when(
        () => client.rpc<void>(any(), params: any(named: 'params')),
      ).thenAnswer((invocation) {
        sent = invocation.namedArguments[#params] as Map<String, dynamic>;
        return _FakeVoidRpc();
      });

      await repository.delete(
        purchaseId: 'a1',
        restored: const [
          RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false),
        ].lock,
      );

      expect(sent!['p_purchase_id'], 'a1');
      expect((sent!['p_restored'] as List).single, {
        'id': 'l1',
        'fulfilled_on': null,
        'not_found': false,
      });
    });
  });
}
