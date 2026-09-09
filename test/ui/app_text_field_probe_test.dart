import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekton_core/tekton_core.dart';

/// Throwaway probe of step 1.4 of the migration plan: does `enterText` still
/// reach the field through the key of an `AppTextField`? Deleted in step 5.4.
void main() {
  testWidgets('enterText through the AppTextField key hits the mask',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField.currency(
            key: const ValueKey('probe'),
            controller: controller,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('probe')), '1500');

    expect(controller.text, 'R\$\u{A0}15,00');
    expect(find.byType(TextField), findsOneWidget);
  });
}
