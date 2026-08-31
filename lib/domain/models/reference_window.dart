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
/// left to buy (H18). It does not exist in this file yet: it is born in H17,
/// and it is born HERE, beside this one, so the two are never written on two
/// different screens.
library;

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
