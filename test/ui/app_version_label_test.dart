import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/app_version.dart';
import 'package:shopping_list/ui/core/widgets/app_version_label.dart';

void main() {
  const published = AppVersion(
    name: '1.0.0',
    buildNumber: 42,
    commit: 'a1b2c3d',
  );

  /// Mounts the label INSIDE a bottom sheet, which is where it really lives:
  /// the tap pops that sheet, and a label mounted straight into `home` would
  /// pop the route instead and hide the bug.
  Future<void> pumpInSheet(WidgetTester tester, AppVersion version) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => AppVersionLabel(version: version),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// The clipboard has no implementation in a test: the platform channel is
  /// intercepted, and the captured argument IS the assertion.
  String? Function() interceptClipboard(WidgetTester tester) {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return () => copied;
  }

  testWidgets('a published build shows the two lines', (tester) async {
    await pumpInSheet(tester, published);

    expect(find.text('Versão 1.0.0 (build 42)'), findsOneWidget);
    expect(find.text('Commit a1b2c3d'), findsOneWidget);
  });

  testWidgets('a local build says "local" and shows no commit line', (
    tester,
  ) async {
    await pumpInSheet(tester, const AppVersion(name: '1.0.0'));

    expect(find.text('Versão 1.0.0 (local)'), findsOneWidget);
    expect(find.textContaining('Commit'), findsNothing);
    expect(find.textContaining('build'), findsNothing);
  });

  testWidgets('the tap copies the two lines as one, closes and confirms', (
    tester,
  ) async {
    final copied = interceptClipboard(tester);

    await pumpInSheet(tester, published);
    await tester.tap(find.text('Versão 1.0.0 (build 42)'));
    await tester.pumpAndSettle();

    expect(copied(), 'Versão 1.0.0 (build 42) Commit a1b2c3d');
    // The sheet is gone, and the confirmation is on screen.
    expect(find.text('Commit a1b2c3d'), findsNothing);
    expect(find.text('Versão copiada.'), findsOneWidget);
  });

  testWidgets('a local build copies its single line', (tester) async {
    final copied = interceptClipboard(tester);

    await pumpInSheet(tester, const AppVersion(name: '1.0.0'));
    await tester.tap(find.text('Versão 1.0.0 (local)'));
    await tester.pumpAndSettle();

    expect(copied(), 'Versão 1.0.0 (local)');
  });
}
