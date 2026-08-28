import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/widgets/message_view.dart';

/// MessageView is rendered by every empty and every error state in the app,
/// and until this file existed its coverage came entirely from other widgets
/// rendering it: deleting the AlwaysScrollableScrollPhysics — the single line
/// that makes pull-to-refresh work when there is nothing on the screen — broke
/// no test at all.
void main() {
  Future<void> pumpMessageView(
    WidgetTester tester,
    String text, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MessageView(text))),
    );
  }

  testWidgets('stays scrollable so RefreshIndicator still triggers on it', (
    tester,
  ) async {
    await pumpMessageView(tester, 'Nenhum item na lista.');

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );

    // The default physics on a child that fits would refuse the drag, and the
    // pull-to-refresh would work on the full list and die on the empty state —
    // which is exactly where people pull.
    expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('fills the viewport height with a single line of text', (
    tester,
  ) async {
    // The ConstrainedBox minHeight is the other half of the same guarantee:
    // scrollable physics on a 40-pixel-tall child would still leave most of
    // the screen outside the gesture.
    await pumpMessageView(tester, 'Nada aqui.', size: const Size(400, 600));

    final body = tester.getSize(find.byType(MessageView));
    final content = tester.getSize(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(ConstrainedBox),
      ),
    );

    expect(content.height, body.height);
  });

  testWidgets('centers the message it was given', (tester) async {
    await pumpMessageView(tester, 'Nenhuma compra registrada.');

    expect(find.text('Nenhuma compra registrada.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Nenhuma compra registrada.')).textAlign,
      TextAlign.center,
    );
  });
}
