import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';
import 'spending_cap_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// **The spending is seeded HERE and never read from
/// `PurchaseRepositoryLocal`.** Two fakes talking to each other is coupling
/// neither of them needs, and the number this screen shows in debug must not
/// depend on which purchase the other fake happened to seed.
///
/// The seed is the story the acceptance criteria are written with: a cap of
/// R$ 1.500 in force since the 1st of three months ago, and R$ 1.300 already
/// spent in the current month — which is 87% of it, the sentence
/// `requisitos §9` writes.
///
/// [today] anchors that seed. It defaults to the phone's clock so the screen
/// has a cap in debug in any month of any year; every test passes its own,
/// because a fixture that walks with the calendar is a test that fails on a
/// CI nobody touched.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class SpendingCapRepositoryLocal implements SpendingCapRepository {
  SpendingCapRepositoryLocal({
    SpendingCap? cap,
    Map<DateTime, Money>? spending,
    Map<DateTime, CapAlerts>? alerts,
    DateTime? today,
    this.latency = const Duration(milliseconds: 400),
  }) : _today = dayOf(today ?? DateTime.now()) {
    _cap =
        cap ??
        SpendingCap(
          amount: const Money(150000),
          effectiveFrom: DateTime(_today.year, _today.month - 3, 1),
        );
    _spending.addAll(
      spending ?? {firstDayOfMonth(_today): const Money(130000)},
    );
    if (alerts != null) _alerts.addAll(alerts);
  }

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final DateTime _today;

  /// Null is a value here too: "nunca configuraram um teto".
  late SpendingCap? _cap;

  final Map<DateTime, Money> _spending = {};
  final Map<DateTime, CapAlerts> _alerts = {};

  /// What was written, so a test can look at it without a database.
  final List<SpendingCap> saved = [];
  final List<CapAlerts> alertsWritten = [];

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(
    IList<ReportPeriod> months,
  ) async {
    await Future<void>.delayed(latency);

    final answer =
        [
          for (final period in months)
            MonthCapStatus(
              month: period.from,
              // A month older than the first cap has none, forever.
              cap: _capInForceOn(period.from),
              spent: _spending[firstDayOfMonth(period.from)] ?? Money.zero,
              alerts:
                  _alerts[firstDayOfMonth(period.from)] ??
                  CapAlerts.none(period.from),
            ),
        ]..sort((a, b) => a.month.compareTo(b.month));

    // Ordered by month and NOT by the order asked, exactly like `cap_states`:
    // a caller matching by index would be a bug this fake has to be able to
    // catch.
    return answer.toIList();
  }

  @override
  Future<void> save({
    required SpendingCap cap,
    required CapAlerts alerts,
  }) async {
    await Future<void>.delayed(latency);

    _cap = cap;
    saved.add(cap);
    alertsWritten.add(alerts);
    // The whole transaction of `save_spending_cap`: the cap, the month's
    // marks cleared, and the desired state written over them.
    _alerts[alerts.month] = alerts;
  }

  SpendingCap? _capInForceOn(DateTime month) {
    final cap = _cap;
    if (cap == null) return null;
    return cap.effectiveFrom.isAfter(firstDayOfMonth(month)) ? null : cap;
  }
}
