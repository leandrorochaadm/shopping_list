import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/consumption/consumption_repository.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/monthly_average.dart';
import '../../../domain/models/reference_window.dart';
import '../../../domain/models/report_period.dart';
import '../../core/error_translation.dart';

/// Screens 2 and 6 — **the same state, read two ways**.
///
/// One ViewModel and not two, and it is the reason the two stories are
/// neighbours in `handoff §4`: "a conta é a mesma; não escrever duas vezes".
/// Whoever goes from the suggestion to "falta comprar" reads the answer that
/// is already in memory, with no second query.
///
/// **This is where the clock enters the system** (rule 9 and decision 13). The
/// `today` is a constructor field, exactly like `ReportPeriodNotifier`'s and
/// `PriceComparisonViewModel`'s, and it is what lets a test pin the instant —
/// without it, the cases that read "Agosto/2026" pass in August and fail in
/// September on a CI nobody touched.
final class MonthlyAverageViewModel
    extends AsyncNotifier<IList<MonthlyAverage>> {
  /// Rounded with `dayOf` (rule 9): both intervals are made of calendar days,
  /// and an instant carrying an hour would give a different window on every
  /// load.
  ///
  /// `ProviderContainer.test` reaches it with
  /// `monthlyAverageViewModelProvider.overrideWith(
  ///     () => MonthlyAverageViewModel(today: DateTime(2026, 8, 15)))` — a
  /// function with only optional named parameters is assignable to
  /// `MonthlyAverageViewModel Function()`, which is what makes `.new` work
  /// above.
  MonthlyAverageViewModel({DateTime? today})
    : today = dayOf(today ?? DateTime.now());

  final DateTime today;

  /// The three closed months before this one. Neither screen shows it in a
  /// header, but it is what every number on both of them divides by.
  ReportPeriod get window => closedWindow(today);

  /// The month in progress — the "Agosto/2026" of screen 6's header, and the
  /// interval "já comprado" is summed over.
  ReportPeriod get month => ReportPeriod.monthOf(today);

  /// Guards the reload (rule 14). Without it a double tap on `↻` fires two
  /// queries.
  bool _running = false;

  @override
  Future<IList<MonthlyAverage>> build() async {
    final rows = await ref
        .watch(consumptionRepositoryProvider)
        .fetchTypeConsumption(window: window, month: month);
    // The transformation IS the state: unlike `buildReportSections`, which the
    // screen builds once per frame, this one filters and divides, and both
    // screens want the result. What stays in the screen is the grouping.
    return monthlyAverages(rows, window);
  }

  /// The `↻` and the pull-to-refresh. Null on success, or the pt-BR sentence
  /// for the SnackBar — what is on screen stays there either way (rule 16, two
  /// outcomes with no payload).
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<IList<MonthlyAverage>>();

      final rows = await ref
          .read(consumptionRepositoryProvider)
          .fetchTypeConsumption(window: window, month: month);
      if (!ref.mounted) return null;

      state = AsyncData(monthlyAverages(rows, window));
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'calcular a média');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<IList<MonthlyAverage>>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final monthlyAverageViewModelProvider =
    AsyncNotifierProvider<MonthlyAverageViewModel, IList<MonthlyAverage>>(
      MonthlyAverageViewModel.new,
      retry: (retryCount, error) => null,
    );
