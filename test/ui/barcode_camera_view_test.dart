import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/barcode/widgets/barcode_camera_view.dart';

import '../helpers/barcode_camera.dart';

const _a = '7894900011517';
const _b = '7891000100103';

void main() {
  late FakeBarcodeCamera camera;
  late List<String> detected;

  setUp(() {
    camera = FakeBarcodeCamera();
    detected = <String>[];
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [camera.override],
      child: MaterialApp(
        home: Scaffold(
          body: BarcodeCameraView(
            onDetect: detected.add,
            hint: 'Aponte para o código',
          ),
        ),
      ),
    ),
  );

  const gap = BarcodeCameraView.codeGoneGap;

  testWidgets('counts a code once while it stays in view', (tester) async {
    await mount(tester);
    camera.read(_a);
    await tester.pump(const Duration(milliseconds: 300));
    camera.read(_a);
    await tester.pump(const Duration(milliseconds: 300));
    camera.read(_a);
    expect(detected, [_a]);
  });

  testWidgets('counts again after a gap longer than codeGoneGap', (
    tester,
  ) async {
    await mount(tester);
    camera.read(_a);
    await tester.pump(gap + const Duration(milliseconds: 1));
    camera.read(_a);
    expect(detected, [_a, _a]);
  });

  testWidgets('does not count again one millisecond before codeGoneGap', (
    tester,
  ) async {
    await mount(tester);
    camera.read(_a);
    await tester.pump(gap - const Duration(milliseconds: 1));
    camera.read(_a);
    expect(detected, [_a]);
  });

  testWidgets('counts again exactly at codeGoneGap', (tester) async {
    await mount(tester);
    camera.read(_a);
    await tester.pump(gap);
    camera.read(_a);
    expect(detected, [_a, _a]);
  });

  testWidgets('counts two different codes', (tester) async {
    await mount(tester);
    camera.read(_a);
    camera.read(_b);
    expect(detected, [_a, _b]);
    camera.read(_a);
    expect(detected, [_a, _b]);
  });

  testWidgets('shows the hint over the camera', (tester) async {
    await mount(tester);
    expect(find.text('Aponte para o código'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
  });

  testWidgets(
    'without a camera shows the Settings sentence and hides the view',
    (tester) async {
      await mount(tester);
      camera.failToOpen();
      await tester.pump();
      expect(
        find.text('Libere a câmera nos Ajustes do iPhone.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('fake-camera')), findsNothing);
      expect(find.text('Aponte para o código'), findsNothing);
    },
  );

  test('the default camera is the live one', () {
    final container = ProviderContainer.test();
    expect(container.read(barcodeCameraBuilderProvider), liveBarcodeCamera);
  });

  testWidgets('cancels the pending timers on dispose', (tester) async {
    await mount(tester);
    camera.read(_a);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [camera.override],
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pump();
  });
}
