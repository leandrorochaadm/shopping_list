import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';

/// The fake with a switch that makes the next call fail, and a counter for the
/// paging.
class _SpyRepository extends PurchaseRepositoryLocal {
  _SpyRepository({this.empty = false}) : super(latency: Duration.zero);

  /// An app whose first purchase has not been registered yet — the state the
  /// screen opens in on day one.
  final bool empty;

  Object? failNextCall;
  int pageCalls = 0;

  @override
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  }) async {
    pageCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    if (empty) {
      return const PurchaseHistoryPage(
        purchases: IList.empty(),
        hasMore: false,
      );
    }
    return super.fetchPage(offset: offset, limit: limit);
  }
}

void main() {
  // The screen draws a date and an amount, and `main()` does not run in a
  // test.
  setUpAll(initializePtBr);

  Future<ProviderContainer> pumpHistory(
    WidgetTester tester, {
    PurchaseRepository? repository,
    List<Override> overrides = const [],
  }) async {
    // A tall viewport: a page of twenty lines plus the footer button does not
    // fit the default 800×600, and a button outside the render tree cannot be
    // tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(purchases: repository ?? _SpyRepository()),
        ...overrides,
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go(Routes.purchaseHistory);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lists the purchases, newest first', (tester) async {
    await pumpHistory(tester);

    expect(find.text('28/08/2026 · Carrefour'), findsOneWidget);
    expect(find.text('R\$ 62,00 · Leandro'), findsOneWidget);
    expect(find.text('27/08/2026 · Feira do Bairro'), findsOneWidget);
    expect(find.text('R\$ 45,00 · esposa'), findsOneWidget);
  });

  testWidgets('an app with no purchase yet says so', (tester) async {
    await pumpHistory(tester, repository: _SpyRepository(empty: true));

    expect(find.text('Nenhuma compra lançada ainda.'), findsOneWidget);
  });

  testWidgets('a failed load occupies the screen, without the exception', (
    tester,
  ) async {
    final repository = _SpyRepository()..failNextCall = ApiException(500, '');
    await pumpHistory(tester, repository: repository);

    expect(find.byKey(const ValueKey('retry-history')), findsOneWidget);
    // Rule 10: the raw exception never reaches the screen.
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('trying again brings the list back', (tester) async {
    final repository = _SpyRepository()..failNextCall = ApiException(500, '');
    await pumpHistory(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('retry-history')));
    await tester.pumpAndSettle();

    expect(find.text('28/08/2026 · Carrefour'), findsOneWidget);
  });

  testWidgets('[ Carregar mais ] appends the next page', (tester) async {
    final repository = _SpyRepository();
    await pumpHistory(tester, repository: repository);

    // Twenty per page, twenty-five in the fake: the oldest is on page two.
    expect(find.byKey(const ValueKey('catalog-purchase-25')), findsNothing);
    expect(repository.pageCalls, 1);

    await tester.tap(find.byKey(const ValueKey('load-more')));
    await tester.pumpAndSettle();

    expect(repository.pageCalls, 2);
    // Page one is still there — the list never blanks while the next page
    // comes.
    expect(find.text('28/08/2026 · Carrefour'), findsOneWidget);
    // And the footer button is gone: there is no page three.
    expect(find.byKey(const ValueKey('load-more')), findsNothing);
  });

  testWidgets('a failed [ Carregar mais ] keeps the page on screen', (
    tester,
  ) async {
    final repository = _SpyRepository();
    await pumpHistory(tester, repository: repository);

    repository.failNextCall = NetworkException('offline');
    await tester.tap(find.byKey(const ValueKey('load-more')));
    await tester.pumpAndSettle();

    expect(find.text('28/08/2026 · Carrefour'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('NetworkException'), findsNothing);
  });

  testWidgets('tapping a line opens the correction', (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.text('28/08/2026 · Carrefour'));
    await tester.pumpAndSettle();

    expect(find.text('Corrigir compra'), findsOneWidget);
    // `push`, not `go`: the way back to the history is the Back button.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('has an exit of its own', (tester) async {
    await pumpHistory(tester);

    // Reached by `go` from the root, so there is nothing to pop: R11 says the
    // way out is the house.
    expect(find.byTooltip('Ir para a lista'), findsOneWidget);

    await tester.tap(find.byTooltip('Ir para a lista'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de compras'), findsOneWidget);
  });
}
