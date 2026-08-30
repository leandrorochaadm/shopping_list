import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/widgets/warning_dialog.dart';

void main() {
  /// Opens the dialog over a screen with nothing else on it, so every `⚠` the
  /// finder sees belongs to it.
  Future<void> open(WidgetTester tester, List<String> messages) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showWarnings(context, messages),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows one warning with the glyph beside it', (tester) async {
    await open(tester, ['O teto do mês estourou.']);

    expect(find.text('O teto do mês estourou.'), findsOneWidget);
    expect(find.text('⚠ '), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);
  });

  testWidgets('stacks both warnings, the cap one on top', (tester) async {
    // The wireframe is explicit: the two warnings of the same purchase appear
    // TOGETHER, stacked, the cap above and the repeat below, with a single
    // button.
    await open(tester, [
      'O teto do mês estourou.',
      'Vocês dois compraram Leite hoje.',
    ]);

    final cap = tester.getTopLeft(find.text('O teto do mês estourou.'));
    final repeat = tester.getTopLeft(find.text('Vocês dois compraram Leite hoje.'));

    expect(cap.dy, lessThan(repeat.dy));
    // ONE button for both.
    expect(find.text('Entendi'), findsOneWidget);
  });

  testWidgets('the button closes it', (tester) async {
    await open(tester, ['O teto do mês estourou.']);

    await tester.tap(find.byKey(const ValueKey('acknowledge-warnings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('warnings')), findsNothing);
  });

  testWidgets('opens nothing when there is nothing to say', (tester) async {
    // The caller does not have to check: a purchase that crossed no cut and
    // repeated nothing simply shows no dialog.
    await open(tester, const []);

    expect(find.byKey(const ValueKey('warnings')), findsNothing);
  });
}
