import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/barcode/widgets/barcode_reader_sheet.dart';

import '../helpers/barcode_camera.dart';
import '../helpers/viewport.dart';

const _qr = '02822521001605261107';
const _ean = '7894900011517';

void main() {
  late FakeBarcodeCamera camera;
  String? read;
  var closed = false;

  setUp(() {
    camera = FakeBarcodeCamera();
    read = null;
    closed = false;
  });

  Future<void> openReader(WidgetTester tester, {bool keyboard = false}) async {
    if (keyboard) {
      useIPhone12WithKeyboard(tester);
    } else {
      useIPhone12(tester);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [camera.override],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  read = await BarcodeReaderSheet.show(context);
                  closed = true;
                },
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

  Finder typedField() => find.descendant(
    of: find.byKey(const ValueKey('reader-typed')),
    matching: find.byType(TextField),
  );

  testWidgets('a camera read closes with the raw text', (tester) async {
    await openReader(tester);
    camera.read(_qr);
    await tester.pumpAndSettle();
    expect(read, _qr);
    expect(closed, isTrue);
    expect(find.byType(BarcodeReaderSheet), findsNothing);
  });

  testWidgets('two reads in the same frame close only once', (tester) async {
    await openReader(tester);
    camera.read(_ean);
    camera.read('7891000100103');
    await tester.pumpAndSettle();
    expect(read, _ean);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('typed code with Usar closes with it', (tester) async {
    await openReader(tester);
    await tester.enterText(typedField(), ' $_ean ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reader-use')));
    await tester.pumpAndSettle();
    expect(read, _ean);
  });

  testWidgets('the keyboard done key also uses the typed code', (tester) async {
    await openReader(tester);
    await tester.enterText(typedField(), _ean);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(read, _ean);
  });

  testWidgets('Usar is disabled with an empty field', (tester) async {
    await openReader(tester);
    VoidCallback? onPressed() => tester
        .widget<FilledButton>(find.byKey(const ValueKey('reader-use')))
        .onPressed;
    expect(onPressed(), isNull);
    await tester.enterText(typedField(), '   ');
    await tester.pump();
    expect(onPressed(), isNull);
  });

  testWidgets('X closes with null', (tester) async {
    await openReader(tester);
    await tester.tap(find.byKey(const ValueKey('reader-close')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(read, isNull);
  });

  testWidgets('a read while the panel is closing keeps the screen below', (
    tester,
  ) async {
    await openReader(tester);
    await tester.tap(find.byKey(const ValueKey('reader-close')));
    await tester.pump();
    camera.read(_ean);
    await tester.pumpAndSettle();
    expect(read, isNull);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('a read while a tap outside closes it keeps the screen below', (
    tester,
  ) async {
    await openReader(tester);
    await tester.tapAt(const Offset(195, 40));
    await tester.pump();
    camera.read(_ean);
    await tester.pumpAndSettle();
    expect(read, isNull);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets(
    'without a camera shows the Settings sentence and keeps the field',
    (tester) async {
      await openReader(tester);
      camera.failToOpen();
      await tester.pump();
      expect(
        find.text('Libere a câmera nos Ajustes do iPhone.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reader-typed')), findsOneWidget);
      await tester.enterText(typedField(), _ean);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reader-use')));
      await tester.pumpAndSettle();
      expect(read, _ean);
    },
  );

  testWidgets('the field has no focus when it opens', (tester) async {
    await openReader(tester);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.widget<TextField>(typedField()).focusNode?.hasFocus,
      isNot(true),
    );
  });

  testWidgets('the field sits above the camera', (tester) async {
    await openReader(tester);
    final field = tester.getRect(find.byKey(const ValueKey('reader-typed')));
    final cam = tester.getRect(find.byKey(const ValueKey('fake-camera')));
    expect(field.bottom, lessThanOrEqualTo(cam.top));
  });

  testWidgets('with the keyboard up the field and Usar stay above it', (
    tester,
  ) async {
    await openReader(tester, keyboard: true);
    final field = tester.getRect(find.byKey(const ValueKey('reader-typed')));
    final use = tester.getRect(find.byKey(const ValueKey('reader-use')));
    expect(field.bottom, lessThanOrEqualTo(iPhone12KeyboardFold));
    expect(use.bottom, lessThanOrEqualTo(iPhone12KeyboardFold));
  });

  testWidgets("Usar is the reader's own button", (tester) async {
    await openReader(tester);
    expect(find.text('Usar'), findsOneWidget);
  });
}
