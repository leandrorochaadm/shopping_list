import 'package:flutter/material.dart';

/// Material 3 defaults, light theme only — no design system of its own
/// (`tecnico §3.10`). The black-and-white of the wireframes belongs to the
/// validation draft, not to the app.
abstract final class AppTheme {
  // static final, not a getter: ColorScheme.fromSeed computes the whole
  // palette, and as a getter that would run on every MyApp build.
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    // The app is used one-handed, walking down an aisle: every tap target is
    // at least 48px (`tecnico §7.5`). `padded` is what enforces it on the
    // icon-only buttons, which otherwise shrink to their icon.
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );

  // No dark theme on purpose: it is not in scope, and a half-done one would
  // ship a screen nobody tested.
}
