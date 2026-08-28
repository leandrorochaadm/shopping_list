import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/spike/widgets/typing_spike_screen.dart';

/// **Throwaway — deleted with the screen** once A2 is answered.
///
/// It is here for one reason: the number this spike produces is only worth
/// something if the stopwatch measures typing, and nothing else.
void main() {
  /// Pumping the same widget type again REBUILDS without recreating the
  /// State — which is how a test can read the label after real time has
  /// passed. The screen only repaints on its own when the ticker fires, and
  /// the ticker is a fake timer: real time moves the Stopwatch, pumped time
  /// moves the screen, and the two clocks are not the same clock in a test.
  Future<void> pumpSpike(WidgetTester tester) => tester.pumpWidget(
    // A NEW instance each call, with a fixed key: an identical `const` widget
    // is skipped by the framework without rebuilding anything, and the label
    // would read the same stale text forever.
    MaterialApp(home: TypingSpikeScreen(key: const ValueKey('spike'))),
  );

  Future<void> waitReal(WidgetTester tester) => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );

  String elapsedText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('spike-elapsed'))).data!;

  testWidgets('offers the three field kinds the purchase screen has', (
    tester,
  ) async {
    // Free text, whole number and amount: three different iOS keyboards, and
    // the amount is the one that historically misplaces the caret.
    await pumpSpike(tester);

    expect(find.byKey(const Key('spike-product')), findsOneWidget);
    expect(find.byKey(const Key('spike-quantity')), findsOneWidget);
    expect(find.byKey(const Key('spike-amount')), findsOneWidget);
  });

  testWidgets('holds the clock at zero until the first keystroke', (
    tester,
  ) async {
    // The number has to be typing time. A clock started on open would count
    // the walk to the aisle and make the PWA look worse than it is.
    await pumpSpike(tester);

    await waitReal(tester);
    await pumpSpike(tester);

    expect(elapsedText(tester), '0min 00.0s');
  });

  testWidgets('runs from the first keystroke and stops on Concluir', (
    tester,
  ) async {
    await pumpSpike(tester);

    await tester.enterText(find.byKey(const Key('spike-product')), 'Arroz');
    await waitReal(tester);
    await pumpSpike(tester);
    expect(elapsedText(tester), isNot('0min 00.0s'));

    await tester.tap(find.text('Concluir'));
    await tester.pump();
    final frozen = elapsedText(tester);

    // Neither more time nor another keystroke may move it after Concluir: the
    // measurement is read off the screen, sometimes minutes later.
    await waitReal(tester);
    await tester.enterText(find.byKey(const Key('spike-amount')), '19,90');
    await pumpSpike(tester);

    expect(elapsedText(tester), frozen);
  });

  testWidgets('zeroes the clock for the next run', (tester) async {
    await pumpSpike(tester);

    await tester.enterText(find.byKey(const Key('spike-quantity')), '2');
    await waitReal(tester);

    await tester.tap(find.text('Zerar'));
    await tester.pump();

    expect(elapsedText(tester), '0min 00.0s');
  });
}
