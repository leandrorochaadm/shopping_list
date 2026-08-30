import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/report/report_repository.dart';
import '../../../domain/models/period_report.dart';
import '../../core/error_translation.dart';
import 'report_period_notifier.dart';

/// Screen 5 — the spending and the consumption of the chosen period.
///
/// The `T` is the [PeriodReport] as the query returns it, flat. The tree the
/// screen draws is built by `buildReportSections`, in the domain, and it is
/// built ONCE per frame by the screen — putting it in the state would mean
/// rebuilding it on every rebuild of the ViewModel, and putting the ordering
/// rules in `data/` besides.
final class ReportViewModel extends AsyncNotifier<PeriodReport> {
  /// Guards the reload. Without it a double tap on `↻` fires two queries.
  bool _running = false;

  @override
  Future<PeriodReport> build() {
    // `watch`, not `read`: changing the period is what makes this build()
    // run again, and Riverpod 3 keeps the previous report on screen while the
    // new one comes.
    final period = ref.watch(reportPeriodProvider);
    return ref.watch(reportRepositoryProvider).fetchPeriodReport(period);
  }

  /// The `↻` and the pull-to-refresh. Returns null on success, or the pt-BR
  /// sentence for the SnackBar — the report already on screen stays there
  /// either way.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<PeriodReport>();

      final period = ref.read(reportPeriodProvider);
      final report = await ref
          .read(reportRepositoryProvider)
          .fetchPeriodReport(period);
      if (!ref.mounted) return null;

      state = AsyncData(report);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'carregar o relatório');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<PeriodReport>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final reportViewModelProvider =
    AsyncNotifierProvider<ReportViewModel, PeriodReport>(
      ReportViewModel.new,
      retry: (retryCount, error) => null,
    );
