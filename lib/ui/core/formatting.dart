/// Money and date, written the way they are read in pt-BR — and the ONLY
/// place in the app where rounding is allowed (decision 24).
///
/// It lives here and not inside a screen because nine more screens are coming
/// and a copy per screen would be nine places to fix when a format changes.
///
/// **Quantity is not here**, and that is not an oversight:
/// `BaseUnit.formatQuantity` — '6 kg', '2,5 L', '3 un' — lives in the DOMAIN,
/// over the same integer conversion `MeasureUnit.parseAmount` reads. A
/// `formatQuantity` here would be a third implementation of it.
///
/// **The `'2026-08-18'` Postgres reads is not here either** — it is
/// `encodeCalendarDay`, in the domain, because `data/` needs it and `data/`
/// importing from `ui/` would invert the flow (rule 12).
library;

import 'package:intl/intl.dart';

import '../../domain/models/money.dart';

/// 'R$ 1.234,56'.
///
/// Built from the INTEGER cents, digit by digit, and never through
/// `cents / 100`: this file is the boundary where rounding is permitted, not
/// where a float gets to decide the last cent.
String formatMoney(Money value) {
  final sign = value.cents < 0 ? '-' : '';
  final cents = value.cents.abs();
  final whole = NumberFormat.decimalPattern('pt_BR').format(cents ~/ 100);
  return '$sign$_currencySymbol$whole,${_fractionOf(cents)}';
}

/// '1234,56' — what goes INTO a text field, with no symbol and no grouping.
///
/// The grouping is dropped on purpose: a field that came back with '1.234,56'
/// would have to be parsed by `Money.parse`, which refuses the dot as a
/// thousands separator — and rightly, since it also means a decimal point.
String formatMoneyPlain(Money value) {
  final sign = value.cents < 0 ? '-' : '';
  final cents = value.cents.abs();
  return '$sign${cents ~/ 100},${_fractionOf(cents)}';
}

/// '18/08/2026'.
///
/// `main()` does not run in a test, so any widget test that reaches this
/// needs `setUpAll(() => initializeDateFormatting('pt_BR'))` — without it
/// DateFormat throws on the locale data it never loaded.
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy', 'pt_BR').format(date);

/// '18/08' — the banner of a recovered draft, where the year is noise: a
/// draft that survived into another year is not a case anyone will read.
String formatShortDate(DateTime date) =>
    DateFormat('dd/MM', 'pt_BR').format(date);

/// 'Julho' — the label of a month shortcut on screen 5.
///
/// **It capitalizes the first letter**, and that is not cosmetic:
/// `DateFormat('MMMM', 'pt_BR')` answers 'julho' in lower case, and a button
/// reading `‹ julho` is the kind of thing only seen on the phone.
String formatMonthName(DateTime month) =>
    _capitalize(DateFormat('MMMM', 'pt_BR').format(month));

/// 'Agosto/2026' — the period currently on screen, between the two shortcuts.
/// The year is there because the two shortcuts walk across December.
String formatMonthYear(DateTime month) =>
    '${formatMonthName(month)}/${month.year}';

/// The first rune, not the first code unit: an accented month name would be
/// cut in half by `substring(0, 1)` on a surrogate pair, and pt-BR has none
/// today — but the next locale is not this file's problem to discover.
String _capitalize(String value) => value.isEmpty
    ? value
    : value[0].toUpperCase() + value.substring(1);

/// Hard-coded rather than taken from `NumberFormat.currency`: the symbol of
/// pt-BR carries a non-breaking space that a `find.text('R$ 62,00')` in a
/// test would never match, and chasing that costs an afternoon.
const _currencySymbol = r'R$ ';

String _fractionOf(int cents) => (cents % 100).toString().padLeft(2, '0');
