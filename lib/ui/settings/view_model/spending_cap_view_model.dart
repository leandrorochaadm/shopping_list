import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/spending_cap/spending_cap_repository.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';
import '../../core/error_translation.dart';

/// How saving a cap ended.
///
/// **TWO outcomes and one of them carries a payload** — which is the sealed
/// form of rule 16, not the `String?` one. The payload is the threshold the
/// save crossed on the spot, and the screen needs to tell "salvo, e vocês já
/// estão em 87%" from "salvo".
sealed class CapSaveOutcome {
  const CapSaveOutcome();
}

final class CapSaved extends CapSaveOutcome {
  const CapSaved(this.triggered);

  /// Null when nothing was crossed on the spot.
  ///
  /// **The 87% of "Vocês já estão em 87% deste teto neste mês" is NOT here.**
  /// The section composes that sentence from the reloaded state,
  /// `cap.usagePercent(status.spent)`: the percentage is a rule the domain
  /// already computes and the View only ASKS it (rule 11). A derived number
  /// riding in the outcome would be a second place for it to live.
  final CapThreshold? triggered;
}

final class CapSaveFailed extends CapSaveOutcome {
  const CapSaveFailed(this.message);

  /// pt-BR, already translated — the raw exception never reaches a screen.
  final String message;
}

/// Where one month stands against its cap: the cap in force, what has been
/// spent, and which cuts are already marked.
///
/// A **family by [ReportPeriod]** and not by `DateTime`: a month IS a period,
/// `ReportPeriod.monthOf` already knows its last day (February of a leap year
/// included), it has `==`, and a loose date would make both callers — screen
/// E3 and screen 5 — recompute the same thing.
///
/// The argument arrives through the CONSTRUCTOR (Riverpod 3 — there is no
/// `FamilyAsyncNotifier`) and `build()` stays parameterless.
final class SpendingCapViewModel extends AsyncNotifier<MonthCapStatus> {
  SpendingCapViewModel(this.period);

  /// The month being read. [save] writes the cap starting in **this** month,
  /// never in one taken from a clock: the screen that saves is the one showing
  /// the current month, and taking the date from two places is how they end up
  /// disagreeing.
  final ReportPeriod period;

  /// Guards the save and the reload (rule 14): the screen stays on display
  /// during both, so the button stays tappable.
  bool _running = false;

  @override
  Future<MonthCapStatus> build() => _load();

  Future<MonthCapStatus> _load() async {
    final statuses = await ref
        .watch(spendingCapRepositoryProvider)
        .fetchStatuses([period].lock);

    // One entry per month asked is the contract. An empty answer is a broken
    // one, and it has to say so instead of coming back as a null the screen
    // would draw as "sem teto".
    if (statuses.isEmpty) {
      throw StateError('cap_states answered nothing for $period');
    }
    return statuses.first;
  }

  /// The `↻` and the pull-to-refresh. Returns null on success, or the pt-BR
  /// sentence for the SnackBar — what is on screen stays there either way.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<MonthCapStatus>();

      final status = await _load();
      if (!ref.mounted) return null;

      state = AsyncData(status);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'ler o teto do mês');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<MonthCapStatus>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// Saves the cap of this month and re-evaluates the two cuts **on the
  /// spot** — "alterar o teto zera os dois avisos do mês corrente e reavalia
  /// na hora".
  ///
  /// Returns `null` when the reentrancy guard barred a second tap.
  ///
  /// The evaluation runs over `CapAlerts.none`, not over the marks that are
  /// there: the write clears them first, in the same transaction, so the state
  /// this decides over is the cleared one. That single argument is the whole
  /// difference between this door and the three write doors — the rule itself
  /// is the same function.
  Future<CapSaveOutcome?> save(Money amount) async {
    if (_running) return null;

    final current = state.value;
    // Without the month's spending there is nothing to evaluate against, and
    // guessing zero would write both marks as "not crossed" over a month that
    // may well be over the cap.
    if (current == null) {
      return const CapSaveFailed('Aguarde o teto do mês carregar.');
    }

    _running = true;
    try {
      // The rule refusing a cap of zero is the domain's, and its sentence
      // comes from the entity (D-j).
      final cap = SpendingCap(amount: amount, effectiveFrom: period.from);

      final evaluation = evaluateSpendingCap(
        cap: cap,
        month: period.from,
        spent: current.spent,
        current: CapAlerts.none(period.from),
      );

      // A cap always exists here, so the evaluation always has marks to
      // write: the null arm of `alerts` is the month WITHOUT a cap, which
      // this method has just made impossible.
      await ref
          .read(spendingCapRepositoryProvider)
          .save(cap: cap, alerts: evaluation.alerts!);
      if (!ref.mounted) return null;

      // The state the database now holds, assembled instead of read back: the
      // spending did not change, and a second round trip would be a second
      // instant for the same number to disagree in.
      state = AsyncData(
        MonthCapStatus(
          month: current.month,
          cap: cap,
          spent: current.spent,
          alerts: evaluation.alerts!,
        ),
      );
      return CapSaved(evaluation.headline);
    } on InvalidSpendingCap catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return CapSaveFailed(e.message);
    } on Object catch (e, st) {
      return CapSaveFailed(translateError(e, st, 'salvar o teto'));
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final spendingCapViewModelProvider =
    AsyncNotifierProvider.family<
      SpendingCapViewModel,
      MonthCapStatus,
      ReportPeriod
    >(SpendingCapViewModel.new, retry: (retryCount, error) => null);
