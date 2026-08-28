import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/main.dart';

import 'helpers/locale.dart';

void main() {
  Finder fakeDataBanner() => find.byWidgetPredicate(
    (widget) => widget is Banner && widget.message == 'DADOS FAKE',
  );

  testWidgets('opens on the shopping list, in pt-BR', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShoppingListApp()));
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
    expectPtBrDelegates(tester);
  });

  testWidgets('marks the screen while running on the fakes', (tester) async {
    // Debug-only state, and invisible otherwise: everything typed on the
    // screens is discarded, and an installed PWA has no console to say so.
    await tester.pumpWidget(
      const ProviderScope(child: ShoppingListApp(usingFakes: true)),
    );
    await tester.pumpAndSettle();

    expect(fakeDataBanner(), findsOneWidget);
  });

  testWidgets('shows no mark when talking to the real database', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ShoppingListApp()));
    await tester.pumpAndSettle();

    expect(fakeDataBanner(), findsNothing);
  });
}
