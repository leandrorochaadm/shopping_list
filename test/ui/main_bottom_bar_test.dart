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

  /// A router of the three destinations plus screen 3, because a tap on any destination now calls
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
          path: Routes.suggestions,
          builder: (context, state) => const Scaffold(
            body: Text('a despensa'),
            bottomNavigationBar: MainBottomBar(current: Routes.suggestions),
          ),
        ),
        GoRoute(
          path: Routes.reports,
          builder: (context, state) => const Scaffold(
            body: Text('o relatório'),
            bottomNavigationBar: MainBottomBar(current: Routes.reports),
          ),
        ),
        GoRoute(
          path: Routes.newPurchase,
          builder: (context, state) =>
              const Scaffold(body: Text('o lançamento')),
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
    expect(find.text('Despensa'), findsOneWidget);
    expect(find.text('Relatórios'), findsOneWidget);
    // Screen 6 left the bar for the `≡` on 27/09/2026.
    expect(find.text('Falta'), findsNothing);
  });

  testWidgets('"Despensa" navigates to screen 2', (tester) async {
    await pumpRoutedBar(tester);

    await tester.tap(find.text('Despensa'));
    await tester.pumpAndSettle();

    expect(find.text('a despensa'), findsOneWidget);
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
      Icons.fact_check_outlined,
      Icons.bar_chart,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color, isNot(disabled));
    }

    for (final label in const ['Lista', 'Despensa', 'Relatórios']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('[ Lançar ] sits in the exact middle of the bar', (
    tester,
  ) async {
    await pumpBar(tester);

    final bar = tester.getRect(find.byType(MainBottomBar));
    final button = tester.getRect(find.byKey(const ValueKey('new-purchase')));

    expect(button.center.dx, closeTo(bar.center.dx, 0.5));
    expect(find.text('Lançar'), findsOneWidget);
    expect(find.byTooltip('Lançar compra'), findsOneWidget);
  });

  testWidgets('[ Lançar ] opens screen 3 from any of the three screens', (
    tester,
  ) async {
    final router = await pumpRoutedBar(tester);

    for (final from in const [
      Routes.shoppingList,
      Routes.suggestions,
      Routes.reports,
    ]) {
      router.go(from);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('new-purchase')));
      await tester.pumpAndSettle();

      expect(find.text('o lançamento'), findsOneWidget, reason: from);
    }
  });

  testWidgets('the screen on display is the one marked selected', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(
      tester.getSemantics(find.text('Lista')),
      isSemantics(isButton: true, isSelected: true, label: 'Lista'),
    );
    expect(
      tester.getSemantics(find.text('Despensa')),
      isSemantics(isButton: true, isSelected: false, label: 'Despensa'),
    );
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
