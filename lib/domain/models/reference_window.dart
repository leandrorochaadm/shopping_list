/// The TWO reference windows of the project, and they never mix
/// (`requisitos §Regras`, confirmed on 26/08/2026).
///
/// **Rolling** — the three months ending today, WITH the month in progress
/// inside. It rules the price-increase alert (H15), the comparison between
/// stores (H16) and the short list of the calculator (H19). The question is
/// "is this price expensive?", and last week's purchase is the most valuable
/// piece of information there is.
///
/// **Closed** — the three closed months before this one, without the month in
/// progress. It rules the monthly average, the suggestion (H17) and what is
/// left to buy (H18). It was born in H17, and it was born HERE, beside the
/// other one, so the two are never written on two different screens.
///
/// The two live in one file because the mistake they guard against is picking
/// the wrong one: a consumption question answered by the rolling window would
/// let every August purchase raise August's own average, and "falta comprar"
/// would never reach zero.
library;

import 'calendar_day.dart';
import 'report_period.dart';

/// Three months, and it is a number of a RULE: `static const` in the domain
/// (rule 6).
const int referenceWindowMonths = 3;

/// The first day of the rolling window — three CALENDAR months before
/// [today], which is how "os últimos 3 meses" is read on a receipt.
/// `Duration(days: 90)` would drift a day every leap year and two every
/// February.
///
/// A day the target month does not have normalizes forward (31 May minus
/// three months is 3 March), and that is acceptable: the window crops a
/// history, it decides nothing on its own.
///
/// It came from `NewPurchaseViewModel.threeMonthsBefore` on 30/08/2026: H16
/// lives in `ui/report/` and would have to import `ui/purchase/` to call it
/// (decision D-r).
DateTime rollingWindowStart(DateTime today) =>
    DateTime(today.year, today.month - referenceWindowMonths, today.day);

/// The CLOSED window: the three closed months before the one [today] is in,
/// with the month in progress deliberately OUT of it.
///
/// In August 2026 it is 01/05 to 31/07. It rules the monthly average, and with
/// it the suggestion (H17) and what is left to buy (H18) — never the price
/// questions, which use [rollingWindowStart].
///
/// The month in progress is out on purpose: if August entered August's own
/// average, every purchase would raise its own target and "falta comprar"
/// would never reach zero (`requisitos §Regras`, confirmed on 26/08/2026).
///
/// `DateTime(y, m, 0)` is day ZERO of the month, which Dart normalizes into
/// the last day of the PREVIOUS one — the same trick `ReportPeriod.monthOf`
/// uses, and what gets February right with no table.
ReportPeriod closedWindow(DateTime today) {
  final month = firstDayOfMonth(today);
  return ReportPeriod(
    from: DateTime(month.year, month.month - referenceWindowMonths, 1),
    to: DateTime(month.year, month.month, 0),
  );
}
