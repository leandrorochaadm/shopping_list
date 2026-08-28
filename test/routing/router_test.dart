import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/under_construction_screen.dart';

void main() {
  /// Every path of `tecnico §3.4` and the title its screen shows. A typo in a
  /// path, a route dropped from the router or a name that stops matching fails
  /// here — instead of at the moment someone taps the link on the phone.
  const titleByPath = <String, String>{
    Routes.shoppingList: 'Lista de compras',
    Routes.welcome: 'Quem está usando?',
    Routes.suggestions: 'Sugestão de itens',
    Routes.newPurchase: 'Lançar compra',
    Routes.purchaseHistory: 'Histórico de compras',
    '/purchases/7f3c/edit': 'Corrigir compra',
    Routes.newProduct: 'Novo produto',
    Routes.reports: 'Relatórios',
    Routes.remainingThisMonth: 'Falta comprar este mês',
    Routes.catalog: 'Manutenção do cadastro',
    Routes.settings: 'Configurações',
  };

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final container = ProviderContainer.test();
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return router;
  }

  testWidgets('every route of the app resolves to a screen', (tester) async {
    expect(
      titleByPath,
      hasLength(11),
      reason: 'tecnico 3.4 froze eleven screens',
    );

    final router = await pumpRouter(tester);

    for (final entry in titleByPath.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();

      expect(
        find.byType(UnderConstructionScreen),
        findsOneWidget,
        reason: entry.key,
      );
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('matches /purchases/new as a route, not as an id', (
    tester,
  ) async {
    // The guard the route order in router.dart exists for. Today the two paths
    // differ in segment count and could not collide; the day a '/purchases/:id'
    // route is added they can, and this test is what notices.
    final router = await pumpRouter(tester);

    router.go(Routes.newPurchase);
    await tester.pumpAndSettle();

    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.text('Corrigir compra'), findsNothing);
  });

  testWidgets('opens the shopping list first', (tester) async {
    await pumpRouter(tester);
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
  });

  test('every route name resolves to the path it was registered with', () {
    // RouteNames exists so a screen can call goNamed and never chase a path.
    // Nothing calls it yet, so a name with a typo — or a `name:` dropped from
    // router.dart — would compile, pass every other test here, and only fail
    // the first time a screen navigates by name.
    const pathByName = <String, String>{
      RouteNames.shoppingList: Routes.shoppingList,
      RouteNames.welcome: Routes.welcome,
      RouteNames.suggestions: Routes.suggestions,
      RouteNames.newPurchase: Routes.newPurchase,
      RouteNames.purchaseHistory: Routes.purchaseHistory,
      RouteNames.newProduct: Routes.newProduct,
      RouteNames.reports: Routes.reports,
      RouteNames.remainingThisMonth: Routes.remainingThisMonth,
      RouteNames.catalog: Routes.catalog,
      RouteNames.settings: Routes.settings,
    };

    final router = ProviderContainer.test().read(appRouterProvider);

    for (final entry in pathByName.entries) {
      expect(router.namedLocation(entry.key), entry.value, reason: entry.key);
    }
    // The eleventh: the only route that takes a parameter.
    expect(
      router.namedLocation(
        RouteNames.editPurchase,
        pathParameters: {'id': '7f3c'},
      ),
      '/purchases/7f3c/edit',
    );
  });

  testWidgets('gives every screen an exit of its own', (tester) async {
    // R11: installed on the home screen there is no browser Back button and no
    // refresh gesture, so each screen has to carry its own way out. Which exit
    // it shows depends on whether there is anything to pop back to.
    final router = await pumpRouter(tester);

    router.push(Routes.reports);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Lista de compras'), findsOneWidget);

    // Opened directly, with an empty stack: the exit is the home button, and
    // it has to land on the list.
    router.go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byTooltip('Ir para a lista'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de compras'), findsOneWidget);
  });
}
