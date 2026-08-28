import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The single locale this app ships in, and the delegates that carry it.
///
/// It lives here, and not in `main.dart`, because there are TWO application
/// roots — the app itself and the misconfiguration screen — and a root that
/// forgets these renders Material's own strings in English inside a pt-BR
/// screen. Without the delegates, showDatePicker and the tooltips stay in
/// English even though the screens render pt-BR dates.
const ptBrLocale = Locale('pt', 'BR');

const appLocalizationsDelegates = GlobalMaterialLocalizations.delegates;

const appSupportedLocales = [ptBrLocale];
