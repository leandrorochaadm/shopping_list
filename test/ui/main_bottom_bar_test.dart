import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/main_bottom_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        bottomNavigationBar: MainBottomBar(current: Routes.shoppingList),
      ),
    ),
  );

  /// A router of three routes, because a tap on any destination now calls
  /// `context.go` — and without a GoRouter in the tree that throws. Until H18
  /// the bar alone could be asked about the destinations that did not
  /// navigate; there are none left.
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
          path: Routes.remainingThisMonth,
          builder: (context, state) => const Scaffold(
            body: Text('o que falta'),
            bottomNavigationBar: MainBottomBar(
              current: Routes.remainingThisMonth,
            ),
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

  testWidgets('"Falta" navigates to screen 6', (tester) async {
    // It used to answer '"Falta comprar este mês" chega na H18.'; H18 is this
    // delivery, and there is no story left to announce.
    await pumpRoutedBar(tester);

    await tester.tap(find.text('Falta'));
    await tester.pumpAndSettle();

    expect(find.text('o que falta'), findsOneWidget);
  });

  testWidgets('"Relatórios" navigates to screen 5', (tester) async {
    await pumpRoutedBar(tester);

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();

    expect(find.text('o relatório'), findsOneWidget);
  });

  testWidgets('no destination is greyed out, and each reads its own name', (
    tester,
  ) async {
    // The map of pendencies is gone: every icon is drawn in the default colour
    // and every tooltip is the label, which is what a screen reader announces
    // without having to tap.
    await pumpBar(tester);

    final context = tester.element(find.byType(MainBottomBar));
    final disabled = Theme.of(context).disabledColor;

    for (final icon in const [
      Icons.checklist,
      Icons.event_note,
      Icons.bar_chart,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color, isNot(disabled));
    }

    for (final label in const ['Lista', 'Falta', 'Relatórios']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the destination already on screen does nothing loud', (
    tester,
  ) async {
    // No SnackBar, and no navigation to the screen already on display: a
    // control that goes where you already are does nothing.
    await pumpBar(tester);

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
