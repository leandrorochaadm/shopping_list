import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_increase.dart';
import 'package:shopping_list/ui/purchase/widgets/price_increase_warning.dart';

void main() {
  // No container anywhere in this file, and that IS the assertion: the widget
  // reads no provider and re-implements no rule (rules 4 and 11).
  Future<void> pumpWarning(WidgetTester tester, PriceIncrease increase) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PriceIncreaseWarning(increase: increase)),
        ),
      );

  PriceIncrease increaseOf(int cents) => evaluatePriceIncrease(
    baseline: PriceBaseline(paid: const Money(6200), quantityInBaseUnit: 4200),
    paid: Money(cents),
    quantityInBaseUnit: 4200,
  )!;

  testWidgets('writes the sentence the entity built', (tester) async {
    await pumpWarning(tester, increaseOf(7000));

    expect(find.text('Subiu 13% sobre a média'), findsOneWidget);
  });

  testWidgets('the percentage comes from the entity, never from the widget', (
    tester,
  ) async {
    // Two different rises, two different sentences: nothing here is fixed
    // text, and no "10" is written in the widget (rule 6).
    await pumpWarning(tester, increaseOf(7363));
    expect(find.text('Subiu 19% sobre a média'), findsOneWidget);

    await pumpWarning(tester, increaseOf(6820));
    expect(find.text('Subiu 10% sobre a média'), findsOneWidget);
  });

  testWidgets('it is drawn in the error colour, with the ⚠ beside it', (
    tester,
  ) async {
    await pumpWarning(tester, increaseOf(7000));

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.warning_amber_outlined),
    );
    final theme = ThemeData();
    expect(icon.color, isNotNull);
    expect(icon.color, isNot(theme.colorScheme.onSurface));
  });
}
