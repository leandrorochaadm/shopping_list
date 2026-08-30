import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/pending_destinations.dart';
import 'package:shopping_list/ui/shopping_list/widgets/shopping_list_menu.dart';

/// A file of its own for the `≡`, because what changed in it is a rule of its
/// own — three doors stopped being disabled, and "corrigir compra" left the
/// menu instead of becoming enabled.
///
/// Screen 1's test covers it from the outside; this one covers the widget.
void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ShoppingListMenu.show(context),
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

  test('what is still pending stays pending, with its sentence', () {
    expect(pendingDestinations, {
      Routes.suggestions: 'A sugestão de itens chega na H17.',
      Routes.reports: 'Os relatórios chegam na H11.',
      Routes.remainingThisMonth: '"Falta comprar este mês" chega na H18.',
    });
  });
}
