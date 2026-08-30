import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/pending_destinations.dart';
import 'package:shopping_list/ui/core/widgets/main_menu.dart';

/// A file of its own for the `≡`, because what changed in it is a rule of its
/// own — three doors stopped being disabled, and "corrigir compra" left the
/// menu instead of becoming enabled.
///
/// Screens 1 and 5 cover it from the outside; this one covers the widget.
void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MainMenu.show(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists three doors, and none of them is disabled', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.text('Histórico de compras'), findsOneWidget);
    expect(find.text('Manutenção do cadastro'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    // No subtitle at all: a subtitle here IS the "chega na H…" explanation.
    expect(find.textContaining('chega na H'), findsNothing);
  });

  testWidgets('"corrigir compra" left the menu, and did not become enabled', (
    tester,
  ) async {
    // `/purchases/:id/edit` does not navigate without an id, and the only
    // screen that knows which id is the history — one line above it.
    await openMenu(tester);

    expect(find.text('Corrigir compra'), findsNothing);
  });

  testWidgets('a door that is tapped closes the sheet and navigates', (
    tester,
  ) async {
    // The tap needs a GoRouter in the tree: every door of this menu is a
    // delivered screen now, and a delivered door calls `context.go`.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: Routes.shoppingList,
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MainMenu.show(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.catalog,
          builder: (context, state) =>
              const Scaffold(body: Text('a manutenção')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manutenção do cadastro'));
    await tester.pumpAndSettle();

    expect(find.text('a manutenção'), findsOneWidget);
    // The sheet closed on the way out — a menu left open over the screen it
    // navigated to is the bug this pop guards against.
    expect(find.text('Histórico de compras'), findsNothing);
  });

  test('the three screens of this delivery left the pending map', () {
    for (final route in [
      Routes.purchaseHistory,
      Routes.editPurchase,
      Routes.catalog,
      // Screen 3 was delivered in H7 and the map had been forgotten.
      Routes.newPurchase,
    ]) {
      expect(isPending(route), isFalse, reason: route);
    }
  });

  test('the report screen left the pending map', () {
    // A case of its own, and NOT one more line in the test above: that one
    // names the four screens of delivery 4, and pushing the report into it
    // would make its name lie about what it protects.
    expect(isPending(Routes.reports), isFalse);
  });

  test('what is still pending stays pending, with its sentence', () {
    expect(pendingDestinations, {
      Routes.suggestions: 'A sugestão de itens chega na H17.',
      Routes.remainingThisMonth: '"Falta comprar este mês" chega na H18.',
    });
  });
}
