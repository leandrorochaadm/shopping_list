import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/main.dart';

import 'helpers/catalog.dart';
import 'helpers/device_user.dart';
import 'helpers/locale.dart';
import 'helpers/purchase.dart';
import 'helpers/shopping_list.dart';

void main() {
  Finder fakeDataBanner() => find.byWidgetPredicate(
    (widget) => widget is Banner && widget.message == 'DADOS FAKE',
  );

  // Since H1 the app has a redirect: without a device user label every route
  // lands on the welcome screen, and the provider that answers it has to be
  // overridden here — there is no Hive box in a test.
  testWidgets('opens on the shopping list, in pt-BR', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Screen 1 is real since H4: without the list's repository this test
        // would exercise the unoverridden-provider error screen, and the
        // `find.text('Lista de compras')` of the AppBar would stay green while
        // LYING.
        overrides: [
          deviceUserOverride(),
          shoppingListOverride(),
          catalogOverride(),
          // Since H7 the app root watches the automatic resend, which reads
          // the draft and the purchase repository.
          ...purchaseOverrides(),
        ],
        child: const ShoppingListApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
    expectPtBrDelegates(tester);
  });

  testWidgets('marks the screen while running on the fakes', (tester) async {
    // Debug-only state, and invisible otherwise: everything typed on the
    // screens is discarded, and an installed PWA has no console to say so.
    await tester.pumpWidget(
      ProviderScope(
        // Screen 1 is real since H4: without the list's repository this test
        // would exercise the unoverridden-provider error screen, and the
        // `find.text('Lista de compras')` of the AppBar would stay green while
        // LYING.
        overrides: [
          deviceUserOverride(),
          shoppingListOverride(),
          catalogOverride(),
          // Since H7 the app root watches the automatic resend, which reads
          // the draft and the purchase repository.
          ...purchaseOverrides(),
        ],
        child: const ShoppingListApp(usingFakes: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeDataBanner(), findsOneWidget);
  });

  testWidgets('shows no mark when talking to the real database', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // Screen 1 is real since H4: without the list's repository this test
        // would exercise the unoverridden-provider error screen, and the
        // `find.text('Lista de compras')` of the AppBar would stay green while
        // LYING.
        overrides: [
          deviceUserOverride(),
          shoppingListOverride(),
          catalogOverride(),
          // Since H7 the app root watches the automatic resend, which reads
          // the draft and the purchase repository.
          ...purchaseOverrides(),
        ],
        child: const ShoppingListApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeDataBanner(), findsNothing);
  });

  testWidgets('asks who is using a phone that was never marked', (
    tester,
  ) async {
    // The whole point of the redirect, seen from the application root: the
    // first opening is a question, not the list.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceUserOverride(name: null), ...purchaseOverrides()],
        child: const ShoppingListApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando?'), findsOneWidget);
    expect(find.text('Lista de compras'), findsNothing);
  });
}
