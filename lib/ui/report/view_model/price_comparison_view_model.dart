import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/report/report_repository.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/reference_window.dart';
import '../../core/error_translation.dart';

/// The Comparação de preço tab of screen 5 — and **the second place in this
/// feature where the clock enters the system** (rule 9). The first is
/// `ReportPeriodNotifier`, and the two do not mix: that one holds the FREE
/// period the user picks, this one the ROLLING window of three months, which
/// nobody picks. Both come in through the SAME door — a `today` in the
/// constructor — because that is the one a test can pin.
///
/// The `T` is the flat list of quotes, as the repository returns it. The lines
/// of the screen and the groups of the picker are pure functions over it,
/// called by the widget once per frame — putting the result in the state
/// would mean redoing it on every change of view, which does no I/O at all.
final class PriceComparisonViewModel extends AsyncNotifier<IList<PriceQuote>> {
  /// The SAME seam as `ReportPeriodNotifier({DateTime? today})`, and for the
  /// same reason written in its dartdoc: without it no test can say WHICH
  /// window was asked of the repository, which is the only thing this
  /// ViewModel decides. `ProviderContainer.test` reaches it with
  /// `priceComparisonViewModelProvider.overrideWith(
  ///     () => PriceComparisonViewModel(today: DateTime(2026, 8, 15)))`.
  ///
  /// Rounded with `dayOf` (rule 9): the window is made of calendar days, and
  /// an instant with an hour inside would give a different `since` on every
  /// load.
  PriceComparisonViewModel({DateTime? today})
    : today = dayOf(today ?? DateTime.now());

  final DateTime today;

  /// Guards the reload (rule 14). Without it a double tap on `↻` fires two
  /// queries.
  bool _running = false;

  @override
  Future<IList<PriceQuote>> build() =>
      // `watch` in the build and `read` in the refresh — the same mould as
      // `ReportViewModel`, which lives in the file next door. The clock came
      // in through the constructor (rule 9), once per notifier.
      ref
          .watch(reportRepositoryProvider)
          .fetchPriceQuotes(rollingWindowStart(today));

  /// The `↻` and the pull-to-refresh. Null on success, or the pt-BR sentence
  /// for the SnackBar — what is on screen stays there either way.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<IList<PriceQuote>>();

      final quotes = await ref
          .read(reportRepositoryProvider)
          .fetchPriceQuotes(rollingWindowStart(today));
      if (!ref.mounted) return null;

      state = AsyncData(quotes);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'carregar a comparação de preço');
      // With nothing to fall back on the failure has to OCCUPY the tab:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<IList<PriceQuote>>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final priceComparisonViewModelProvider =
    AsyncNotifierProvider<PriceComparisonViewModel, IList<PriceQuote>>(
      PriceComparisonViewModel.new,
      retry: (retryCount, error) => null,
    );
