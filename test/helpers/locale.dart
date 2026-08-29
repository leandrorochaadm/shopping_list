import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

/// `main()` does not run in a test, so any widget test that renders a date or
/// an amount has to load the pt-BR locale data itself — without it DateFormat
/// throws `LocaleDataException` from inside a build().
///
/// Call it from `setUpAll`.
Future<void> initializePtBr() => initializeDateFormatting('pt_BR');
