import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts that the pumped application root carries the pt-BR delegates of
/// `ui/core/app_locale.dart`.
///
/// There is more than one application root in this app — the app itself and
/// the misconfiguration screen — and a root that forgets the delegates renders
/// Material's own strings in English inside a pt-BR screen. The assertion is
/// one; only the roots are many.
void expectPtBrDelegates(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold));

  expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
  // A string only the global delegates can produce: without them this label
  // is 'Cancel'.
  expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
}
