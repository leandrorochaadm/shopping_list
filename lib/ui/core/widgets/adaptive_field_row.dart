import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The gap between two fields, and between two lines of them. The same 12 the
/// screens already put between stacked fields.
const double _gap = 12;

/// What `InputDecorator` spends horizontally on a filled field when the theme
/// sets no padding of its own (`input_decorator.dart`, `_defaultContentPadding`).
/// The theme is asked first; this is only the fallback for the theme that says
/// nothing.
const EdgeInsets _materialFieldPadding = EdgeInsets.symmetric(horizontal: 12);

/// How much Material shrinks a label when it floats above the field
/// (`input_decorator.dart`, `_kFinalLabelScale`).
const double _floatingLabelScale = 0.75;

/// Fields laid out side by side — for as long as they still fit.
///
/// **No width and no breakpoint is written down here.** Each field says what
/// its widest text is; this widget measures that text — with the device's own
/// text scale, in the app's own styles — against the width the parent actually
/// offers, and puts on one line as many fields as the measurement allows. Turn
/// the phone's font up in Ajustes and a row of three breaks into two by
/// itself; turn it back down and it closes again.
///
/// It exists for screen 3: on the 390 pt of an iPhone 12, Peso, Valor total and
/// Valor por kg side by side are what keep the whole "escolher produto →
/// digitar → adicionar" loop above the keyboard, twenty times in a row.
class AdaptiveFieldRow extends StatelessWidget {
  const AdaptiveFieldRow({required this.fields, super.key});

  final List<AdaptiveFieldSpec> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final decoration = theme.inputDecorationTheme;

    // What a `TextField` writes its value in, and what it floats its label in
    // — read from the theme, so a change of type scale moves the measurement
    // with it instead of leaving it behind.
    final valueStyle = theme.textTheme.bodyLarge ?? const TextStyle();
    final labelStyle = decoration.labelStyle ?? valueStyle;
    final chrome = (decoration.contentPadding ?? _materialFieldPadding)
        .resolve(Directionality.of(context))
        .horizontal;

    final demands = [
      for (final field in fields)
        chrome +
            math.max(
              _widthOf(field.label, labelStyle, scaler) * _floatingLabelScale,
              _widthOf(field.widestValue, valueStyle, scaler),
            ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = _pack(demands, constraints.maxWidth);
        return Column(
          spacing: _gap,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              Row(
                spacing: _gap,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final index in line)
                    Expanded(
                      // Proportional to what the field asked for, so the money
                      // column is not squeezed to the width of the count one.
                      flex: demands[index].round(),
                      child: fields[index].build(context, line.length > 1),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// As many fields per line as fit, in the order they were given. A field
  /// wider than the whole line stays alone on it — there is nowhere else for
  /// it to go.
  List<List<int>> _pack(List<double> demands, double available) {
    if (!available.isFinite) {
      return [List.generate(demands.length, (index) => index)];
    }

    final lines = <List<int>>[];
    var current = <int>[];
    var used = 0.0;

    for (var index = 0; index < demands.length; index++) {
      final needed = current.isEmpty
          ? demands[index]
          : used + _gap + demands[index];
      if (current.isNotEmpty && needed > available) {
        lines.add(current);
        current = [index];
        used = demands[index];
      } else {
        current = [...current, index];
        used = needed;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  double _widthOf(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}

/// One field of an [AdaptiveFieldRow], and the two strings that decide how
/// much room it asks for.
class AdaptiveFieldSpec {
  const AdaptiveFieldSpec({
    required this.label,
    required this.widestValue,
    required this.build,
  });

  /// The floating label, measured at the scale Material floats it to.
  final String label;

  /// The widest text this field is meant to keep fully readable — **suffix
  /// included**, because the decoration draws it beside the number and it takes
  /// the same room.
  final String widestValue;

  /// `compact` is true when the field ended up SHARING its line. It is the
  /// signal to drop what only pays for itself at full width: `AppTextField`'s
  /// clear button spends `kMinInteractiveDimension` — 48 pt — of a column that
  /// may be 120 pt wide.
  final Widget Function(BuildContext context, bool compact) build;
}
