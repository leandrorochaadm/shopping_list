import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/main_bottom_bar.dart';
import 'package:shopping_list/ui/core/widgets/pending_destinations.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        bottomNavigationBar: MainBottomBar(current: Routes.shoppingList),
      ),
    ),
  );

  /// A router of two routes, because a tap on a DELIVERED destination calls
  /// `context.go` — and without a GoRouter in the tree that throws. The bar
  /// alone can only be asked about the destinations that do not navigate.
  Future<GoRouter> pumpRoutedBar(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: Routes.shoppingList,
          builder: (context, state) => const Scaffold(
            body: Text('a lista'),
            bottomNavigationBar: MainBottomBar(current: Routes.shoppingList),
          ),
        ),
        GoRoute(
          path: Routes.reports,
          builder: (context, state) => const Scaffold(
            body: Text('o relatório'),
            bottomNavigationBar: MainBottomBar(current: Routes.reports),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('carries the three permanent destinations', (tester) async {
    await pumpBar(tester);

    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Falta'), findsOneWidget);
    expect(find.text('Relatórios'), findsOneWidget);
  });

  // One test per destination: two SnackBars in a row QUEUE, and the second
  // would only appear four seconds after the first — long past pumpAndSettle.
  testWidgets('says which story brings "Falta"', (tester) async {
    // Never a tap that does nothing and does not say why.
    await pumpBar(tester);

    await tester.tap(find.text('Falta'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Falta comprar este mês" chega na H18.'),
      findsOneWidget,
    );
  });

  testWidgets('"Relatórios" stopped being pending and now navigates', (
    tester,
  ) async {
    // It used to answer 'Os relatórios chegam na H11.'; H11 is this delivery.
    // The tap needs a GoRouter in the tree — a delivered destination calls
    // `context.go`, and the helper above has no router.
    await pumpRoutedBar(tester);

    expect(isPending(Routes.reports), isFalse);

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();

    expect(find.text('o relatório'), findsOneWidget);
  });

  testWidgets('a delivered destination is not greyed out, and reads its name', (
    tester,
  ) async {
    // The other half of the same rule, and it needs no router: the icon is not
    // in `disabledColor` any more, and the tooltip went back to being the
    // label instead of the pendency's sentence.
    await pumpBar(tester);

    final context = tester.element(find.byType(MainBottomBar));
    final icon = tester.widget<Icon>(find.byIcon(Icons.bar_chart));

    expect(icon.color, isNot(Theme.of(context).disabledColor));
    expect(find.byTooltip('Relatórios'), findsOneWidget);
    // And the one still pending keeps its sentence.
    expect(
      find.byTooltip('"Falta comprar este mês" chega na H18.'),
      findsOneWidget,
    );
  });

  testWidgets('the destination already on screen does nothing loud', (
    tester,
  ) async {
    await pumpBar(tester);

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
