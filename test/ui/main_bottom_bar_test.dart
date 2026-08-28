import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('says which story brings "Relatórios"', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();

    expect(find.text('Os relatórios chegam na H11.'), findsOneWidget);
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
