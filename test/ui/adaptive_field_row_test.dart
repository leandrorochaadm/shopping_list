import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/widgets/adaptive_field_row.dart';

/// The width of one character in the font a widget test draws with: the font
/// size plus the letter spacing of `bodyLarge` (16 + 0,5). It is what makes
/// the measurement in here exact — and it is also why this row is tested HERE
/// and not through screen 3: on a real device Roboto is about half as wide, so
/// a screen-wide assertion would be measuring the test font, not the layout.
const double _charWidth = 16.5;

/// What `InputDecorator` spends horizontally on a filled field, and what the
/// row adds to every measurement.
const double _chrome = 24;

/// The gap the row leaves between two fields.
const double _gap = 12;

void main() {
  Widget field(String key) =>
      TextField(key: ValueKey(key), decoration: const InputDecoration());

  Future<void> pumpRow(
    WidgetTester tester, {
    required double width,
    required List<AdaptiveFieldSpec> fields,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AdaptiveFieldRow(fields: fields),
          ),
        ),
      ),
    );
  }

  /// A field asking for [chars] characters of value — the label is shorter, so
  /// the value is what decides.
  AdaptiveFieldSpec spec(
    String key,
    int chars, {
    void Function(bool compact)? onBuild,
  }) => AdaptiveFieldSpec(
    label: 'x',
    widestValue: 'x' * chars,
    build: (context, compact) {
      onBuild?.call(compact);
      return field(key);
    },
  );

  double demand(int chars) => _chrome + chars * _charWidth;

  testWidgets('fields that fit stay on one line', (tester) async {
    await pumpRow(
      tester,
      width: demand(4) + _gap + demand(4),
      fields: [spec('a', 4), spec('b', 4)],
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('a'))).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dx,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dx),
    );
  });

  testWidgets('one point short of fitting, the last field drops a line', (
    tester,
  ) async {
    // The point is that NOTHING in the row says where to break: the same two
    // fields fit above and do not fit here, and the only thing that changed
    // is the room they were offered.
    await pumpRow(
      tester,
      width: demand(4) + _gap + demand(4) - 1,
      fields: [spec('a', 4), spec('b', 4)],
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy),
    );
  });

  testWidgets('a longer text is what breaks the line, at the same width', (
    tester,
  ) async {
    // The same width as the first test, and one character more to write.
    await pumpRow(
      tester,
      width: demand(4) + _gap + demand(4),
      fields: [spec('a', 4), spec('b', 5)],
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy),
    );
  });

  testWidgets('turning the phone font up breaks it too', (tester) async {
    // Ajustes → Tela → Texto maior. No breakpoint is written down anywhere:
    // the row measures the text it is about to draw, at the scale it is going
    // to draw it.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpRow(
      tester,
      width: demand(4) + _gap + demand(4),
      fields: [spec('a', 4), spec('b', 4)],
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy),
    );
  });

  testWidgets('a field wider than the whole line stays alone on it', (
    tester,
  ) async {
    await pumpRow(
      tester,
      width: demand(2),
      fields: [spec('a', 10), spec('b', 1)],
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy),
    );
  });

  testWidgets('the wider field gets the wider column', (tester) async {
    await pumpRow(
      tester,
      width: demand(2) + _gap + demand(8),
      fields: [spec('a', 2), spec('b', 8)],
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('b'))).width,
      greaterThan(tester.getSize(find.byKey(const ValueKey('a'))).width),
    );
  });

  testWidgets('compact is true only while the field shares its line', (
    tester,
  ) async {
    // It is what turns off the clear button, whose slot is 48 pt of a column
    // that may be 120 pt wide.
    final compact = <String, bool>{};

    await pumpRow(
      tester,
      width: demand(4) + _gap + demand(4),
      fields: [
        spec('a', 4, onBuild: (value) => compact['a'] = value),
        spec('b', 4, onBuild: (value) => compact['b'] = value),
      ],
    );
    expect(compact, {'a': true, 'b': true});

    await pumpRow(
      tester,
      width: demand(4),
      fields: [
        spec('a', 4, onBuild: (value) => compact['a'] = value),
        spec('b', 4, onBuild: (value) => compact['b'] = value),
      ],
    );
    expect(compact, {'a': false, 'b': false});
  });

  testWidgets('a single field takes the whole line', (tester) async {
    await pumpRow(tester, width: 300, fields: [spec('a', 2)]);

    expect(tester.getSize(find.byKey(const ValueKey('a'))).width, 300);
  });
}
