import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// The device this PWA is installed on: iPhone 12, 390 x 844 logical points.
const iPhone12Size = Size(390, 844);

/// The pixel ratio of that device. Logical points times this ratio is what
/// `physicalSize` and `viewInsets` are measured in.
const iPhone12PixelRatio = 3.0;

/// How much of that height the iOS keyboard takes when it is up, in points.
const iPhone12KeyboardInset = 336.0;

/// Sizes the test view like an iPhone 12.
///
/// Call it AFTER any pump helper that forces a viewport of its own, and never
/// add a second `addTearDown`: the one below already restores everything.
void useIPhone12(WidgetTester tester) {
  tester.view.physicalSize = iPhone12Size * iPhone12PixelRatio;
  tester.view.devicePixelRatio = iPhone12PixelRatio;
  addTearDown(tester.view.reset);
}

/// The same device with the keyboard up.
///
/// `viewInsets` is in PHYSICAL pixels, like `physicalSize` — the logical inset
/// has to be multiplied by the ratio, or the keyboard ends up a third of its
/// real height and the assertion passes while the field is still covered.
void useIPhone12WithKeyboard(WidgetTester tester) {
  useIPhone12(tester);
  tester.view.viewInsets = const FakeViewPadding(
    bottom: iPhone12KeyboardInset * iPhone12PixelRatio,
  );
}

/// The bottom edge of what stays visible with the keyboard up, in points.
const iPhone12KeyboardFold = 844.0 - iPhone12KeyboardInset;
