import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/barcode/widgets/unknown_code_dialog.dart';

void main() {
  bool? answer;

  Future<void> open(WidgetTester tester) async {
    answer = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () async => answer = await UnknownCodeDialog.show(context, 'Nenhum produto com o código 123.'),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the message', (tester) async {
    await open(tester);
    expect(find.text('Nenhum produto com o código 123.'), findsOneWidget);
  });

  testWidgets('register answers true', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('unknown-code-register')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('close answers false', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('unknown-code-close')));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('tapping outside answers false', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
