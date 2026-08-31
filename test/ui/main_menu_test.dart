import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/routing/routes.dart';
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

  testWidgets('every door navigates — there is no map of pendencies left', (
    tester,
  ) async {
    // The three tests this replaces asked `isPending` about one route at a
    // time. The map they read was deleted with its last entry in H18, and what
    // takes their place is the property that outlived it: each of the three
    // doors reaches a screen.
    final reached = <String>[];
    Scaffold destination(String name) => Scaffold(body: Text(name));

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
          path: Routes.purchaseHistory,
          builder: (context, state) => destination('o histórico'),
        ),
        GoRoute(
          path: Routes.catalog,
          builder: (context, state) => destination('a manutenção'),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => destination('as configurações'),
        ),
      ],
    );
    addTearDown(router.dispose);

    for (final door in const {
      'Histórico de compras': 'o histórico',
      'Manutenção do cadastro': 'a manutenção',
      'Configurações': 'as configurações',
    }.entries) {
      router.go(Routes.shoppingList);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(door.key));
      await tester.pumpAndSettle();

      expect(find.text(door.value), findsOneWidget, reason: door.key);
      reached.add(door.key);
    }

    expect(reached, hasLength(3));
  });
}
