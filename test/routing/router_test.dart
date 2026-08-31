import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/consumption/widgets/remaining_screen.dart';
import 'package:shopping_list/ui/consumption/widgets/suggestions_screen.dart';
import 'package:shopping_list/ui/device_user/widgets/welcome_screen.dart';
import 'package:shopping_list/ui/report/widgets/reports_screen.dart';
import 'package:shopping_list/ui/settings/widgets/settings_screen.dart';

import '../helpers/catalog.dart';
import '../helpers/consumption.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/report.dart';
import '../helpers/shopping_list.dart';

void main() {
  // Screen 3 draws a date, and `main()` does not run in a test.
  setUpAll(initializePtBr);

  /// Every path and the title its screen carries. A typo in a path, a route
  /// dropped from the router or a name that stops matching fails here —
  /// instead of at the moment someone taps the link on the phone.
  ///
  /// **Since H18 there is one map and not two.** Until then a second one held
  /// the paths still showing the placeholder, and every story moved a line
  /// across; the last two moved here with this delivery, and the sum that had
  /// to stay eleven is now this map's own length. Loosening that count is how
  /// `tecnico §3.4` would quietly stop being true.
  const realTitleByPath = <String, String>{
    Routes.shoppingList: 'Lista de compras',
    Routes.welcome: 'Quem está usando?',
    Routes.settings: 'Configurações',
    Routes.newProduct: 'Novo produto',
    Routes.newPurchase: 'Lançar compra',
    Routes.purchaseHistory: 'Histórico de compras',
    // The one route that takes a parameter, and the id is one the purchase
    // fake actually holds: the screen loads it.
    '/purchases/purchase-1/edit': 'Corrigir compra',
    Routes.catalog: 'Manutenção do cadastro',
    Routes.reports: 'Relatórios',
    Routes.suggestions: 'Sugestão de itens',
    Routes.remainingThisMonth: 'Falta comprar este mês',
  };

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer.test(overrides: overrides);
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
      realTitleByPath.length,
      11,
      reason: 'tecnico 3.4 froze eleven screens',
    );

    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    // The title is asserted where a title LIVES. A screen that carries the
    // bottom bar has its own name written twice — '/reports' is the app bar
    // title AND the bar's label — and a plain `find.text` would report two.
    // Loosening it to `findsWidgets` would stop catching a wrong title, which
    // is the whole point of these two maps.
    Finder titleOf(String title) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(title));

    for (final entry in realTitleByPath.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();

      expect(titleOf(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('matches /purchases/new as a route, not as an id', (
    tester,
  ) async {
    // The guard the route order in router.dart exists for. Today the two paths
    // differ in segment count and could not collide; the day a '/purchases/:id'
    // route is added they can, and this test is what notices.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    router.go(Routes.newPurchase);
    await tester.pumpAndSettle();

    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.text('Corrigir compra'), findsNothing);
  });

  testWidgets('opens the shopping list first', (tester) async {
    await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );
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
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    // The history and NOT `/reports`: the report is one of the three permanent
    // destinations of the bottom bar, and it carries no Back button — the case
    // right below says so. The history is a real screen behind the `≡`, and it
    // has the `canPop() ? BackButton : home` logic this case is about.
    router.push(Routes.purchaseHistory);
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

  testWidgets('gives the shopping list no exit — it IS the exit', (
    tester,
  ) async {
    // The one exception to R11, and it has to be written down somewhere or the
    // next screen to land on `/` grows a button that navigates to itself. The
    // shopping list is where every other exit lands; opened at the root there
    // is nothing to pop back to either, so the app bar carries the `≡` and
    // neither of the two exits.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    router.go(Routes.shoppingList);
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Ir para a lista'), findsNothing);
  });

  testWidgets('gives the report no exit either — it is a destination', (
    tester,
  ) async {
    // The same exception the shopping list has, for the same reason: the three
    // permanent destinations of the bottom bar are switched BETWEEN, and the
    // wireframe's own note says "alternar entre eles não é voltar". Without
    // this case the next screen to grow a bottom bar grows a button that
    // navigates to itself.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    // Pushed, which is the case that WOULD grow one.
    router.push(Routes.reports);
    await tester.pumpAndSettle();

    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Ir para a lista'), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);

    // And opened directly, with an empty stack: still the `≡` and the bar.
    router.go(Routes.reports);
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  testWidgets('gives "falta comprar" no exit either — the third destination', (
    tester,
  ) async {
    // The third and last screen with the bottom bar, and the same exception
    // for the same reason: "alternar entre eles não é voltar". Screen 1 and
    // screen 5 already have a case each; this closes the set.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    // Pushed, which is the case that WOULD grow one.
    router.push(Routes.remainingThisMonth);
    await tester.pumpAndSettle();

    expect(find.byType(RemainingScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Ir para a lista'), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);

    // And opened directly, with an empty stack: still the `≡` and the bar.
    router.go(Routes.remainingThisMonth);
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  testWidgets('gives the suggestion a Back button — it IS pushed', (
    tester,
  ) async {
    // The opposite of the three above, and the reason screen 1 opens it with
    // `push`: the wireframe sends screen 2 back to the list, both from this
    // button and from `[ Adicionar selecionados ]`.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    router.push(Routes.suggestions);
    await tester.pumpAndSettle();

    expect(find.byType(SuggestionsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Lista de compras'), findsOneWidget);

    // Opened by a pasted link, with an empty stack: the exit is the house.
    router.go(Routes.suggestions);
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.byTooltip('Ir para a lista'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de compras'), findsOneWidget);
  });

  testWidgets('sends an unmarked phone to the welcome screen, from anywhere', (
    tester,
  ) async {
    // The app's only redirect, and it is not about identity: there is no
    // session here. A phone that was never asked cannot register a purchase
    // with nobody's name on it.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(name: null),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);

    for (final path in [Routes.reports, Routes.settings, Routes.newProduct]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget, reason: path);
    }
  });

  testWidgets('leaves a marked phone alone, on every route', (tester) async {
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsNothing);

    router.go(Routes.settings);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('lets the S1 spike through without asking who is using it', (
    tester,
  ) async {
    // Throwaway, deleted with the spike: the measurement is a stopwatch run,
    // and a question in front of it would be counted as typing time.
    final router = await pumpRouter(
      tester,
      overrides: [
        deviceUserOverride(name: null),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(),
        reportOverride(),
        consumptionOverride(),
      ],
    );

    router.go(Routes.typingSpike);
    await tester.pumpAndSettle();

    expect(find.text('Teste de digitação'), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });
}
