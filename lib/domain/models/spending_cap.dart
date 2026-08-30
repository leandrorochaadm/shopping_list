import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'money.dart';

/// The two cuts of requirement 9, and the ONLY place their numbers are
/// written (rule 6). The message DERIVES from the number; it never repeats it
/// as text.
enum CapThreshold {
  approaching(percent: 80),
  exceeded(percent: 100);

  const CapThreshold({required this.percent});

  final int percent;

  /// Integer comparison, no division: `spent / cap >= percent / 100` becomes
  /// `spent * 100 >= cap * percent`. A double here would be R15 all over
  /// again — and this is the comparison the whole story turns on.
  bool isCrossedBy({required Money spent, required Money cap}) =>
      spent.cents * 100 >= cap.cents * percent;

  /// pt-BR — read on screen, word for word as `wireframes §Tela 3` writes it.
  ///
  /// **It takes nothing and names no month** (D-i). Naming it would be more
  /// honest for the late purchase — one registered in September can push
  /// AUGUST across a cut — and it was refused all the same: the wireframe
  /// outranks the plan, and the borderline case is accepted as risk 7.
  ///
  /// The `⚠` is NOT here: it is a glyph the dialog draws beside the sentence,
  /// and presentation does not belong in the domain.
  String get message => switch (this) {
    CapThreshold.approaching => 'O gasto do mês passou de $percent% do teto.',
    CapThreshold.exceeded => 'O teto do mês estourou.',
  };
}

/// The cap in force from a month on. One row per CHANGE, never one per month
/// (decision 14): it crosses months on its own.
final class SpendingCap {
  /// **May throw [InvalidSpendingCap]** — a cap of zero is born blown (D-j).
  factory SpendingCap({
    required Money amount,
    required DateTime effectiveFrom,
  }) {
    if (amount.cents <= 0) throw const InvalidSpendingCap();
    return SpendingCap._(
      amount: amount,
      // Always day 1: the cap is monthly, and a mid-month start would make
      // "the month's total" ambiguous.
      effectiveFrom: firstDayOfMonth(effectiveFrom),
    );
  }

  const SpendingCap._({required this.amount, required this.effectiveFrom});

  final Money amount;

  /// The month the cap STARTED in — not the month being asked about. A cap in
  /// force since March answers for August too.
  final DateTime effectiveFrom;

  /// "Vocês já estão em 87% do teto" — the sentence the cap screen shows the
  /// moment a cap is saved over a month that already spent.
  ///
  /// **It ROUNDS to the nearest whole percent, and that is the documents'
  /// number, not a taste**: R$ 1.300 of R$ 1.500 is 86,66…%, and
  /// `requisitos §9` and `wireframes §Tela E3` both write that case as
  /// "87%". Truncating would answer 86 and make the screen contradict the
  /// sentence the client reads.
  ///
  /// Rounding half up in INTEGERS — `+ amount ~/ 2` before the division —
  /// because a double here would be R15 all over again.
  ///
  /// It decides NOTHING: which cut fired is [CapThreshold.isCrossedBy], an
  /// exact comparison with no division at all. This number is only read.
  int usagePercent(Money spent) =>
      (spent.cents * 100 + amount.cents ~/ 2) ~/ amount.cents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpendingCap &&
          other.amount == amount &&
          other.effectiveFrom == effectiveFrom);

  @override
  int get hashCode => Object.hash(amount, effectiveFrom);

  @override
  String toString() =>
      'SpendingCap($amount, from ${encodeCalendarDay(effectiveFrom)})';
}

/// The two marks of one month. `false` is not "unknown": it is "this cut is
/// not crossed", which is what the rearm writes.
final class CapAlerts {
  CapAlerts({
    required DateTime month,
    this.warned80 = false,
    this.warned100 = false,
  }) : month = firstDayOfMonth(month);

  /// A month with neither cut marked — what the cap screen evaluates over,
  /// because saving a cap clears both marks of the current month.
  factory CapAlerts.none(DateTime month) => CapAlerts(month: month);

  final DateTime month;
  final bool warned80;
  final bool warned100;

  Map<String, dynamic> toJson() => {
    'month': encodeCalendarDay(month),
    'warned_80': warned80,
    'warned_100': warned100,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapAlerts &&
          other.month == month &&
          other.warned80 == warned80 &&
          other.warned100 == warned100);

  @override
  int get hashCode => Object.hash(month, warned80, warned100);

  @override
  String toString() =>
      'CapAlerts(${encodeCalendarDay(month)}, 80: $warned80, 100: $warned100)';
}

/// What `cap_states` answers for ONE month: the cap in force, what the month
/// has spent, and which cuts are already marked.
///
/// [cap] null is "month with no cap, forever" — either the cap has never been
/// configured, or this month is older than the first one that had it.
final class MonthCapStatus {
  MonthCapStatus({
    required DateTime month,
    required this.cap,
    required this.spent,
    required this.alerts,
  }) : month = firstDayOfMonth(month);

  factory MonthCapStatus.fromJson(Map<String, dynamic> json) {
    final month = decodeCalendarDay(json['month'] as String);
    final amount = json['cap_amount'];
    return MonthCapStatus(
      month: month,
      // A cap of zero cannot come out of the app (D-j), but a hand-written row
      // could: it is read as "no cap" rather than crashing the report.
      cap: amount == null || (amount as num).toInt() <= 0
          ? null
          : SpendingCap(
              amount: Money.fromJson(amount),
              // The month the cap STARTED in, straight from the query — never
              // `month`, which would make a cap in force since March claim to
              // have been born in August.
              effectiveFrom: decodeCalendarDay(
                json['cap_effective_from'] as String,
              ),
            ),
      spent: Money.fromJson(json['spent']),
      alerts: CapAlerts(
        month: month,
        warned80: json['warned_80'] as bool? ?? false,
        warned100: json['warned_100'] as bool? ?? false,
      ),
    );
  }

  final DateTime month;
  final SpendingCap? cap;
  final Money spent;
  final CapAlerts alerts;

  bool get hasCap => cap != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthCapStatus &&
          other.month == month &&
          other.cap == cap &&
          other.spent == spent &&
          other.alerts == alerts);

  @override
  int get hashCode => Object.hash(month, cap, spent, alerts);

  @override
  String toString() =>
      'MonthCapStatus(${encodeCalendarDay(month)}, cap: $cap, spent: $spent)';
}

/// What the evaluation produced: what to WRITE and what to SHOW.
final class SpendingCapEvaluation {
  const SpendingCapEvaluation({required this.alerts, required this.triggered});

  /// A month with no cap writes nothing and shows nothing — and the two are
  /// different facts, which is why [alerts] is nullable instead of empty.
  static const none = SpendingCapEvaluation(
    alerts: null,
    // `const IList.empty()` and not `IListConst([])`: it is the form `lib/`
    // uses, and it is what makes this whole object a compile-time constant.
    triggered: IList.empty(),
  );

  /// Null when the month has no cap: there is no row to touch.
  final CapAlerts? alerts;

  /// In order: approaching before exceeded.
  final IList<CapThreshold> triggered;

  /// The single sentence the screen shows (D-h). When both cuts fire in the
  /// same write, the graver one speaks alone — both marks are written all the
  /// same.
  CapThreshold? get headline => triggered.isEmpty ? null : triggered.last;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpendingCapEvaluation &&
          other.alerts == alerts &&
          other.triggered == triggered);

  @override
  int get hashCode => Object.hash(alerts, triggered);

  @override
  String toString() =>
      'SpendingCapEvaluation($alerts, triggered: $triggered)';
}

/// **The whole rule of H13, in one pure function.** Four doors call it — the
/// purchase, the correction, the deletion and the cap screen — and none of
/// them re-implements a comparison.
///
/// [spent] is the month's total AFTER the write being decided: the caller adds
/// the purchase, subtracts the deleted one, or passes what is already there.
///
/// [current] is what makes the rearm one line instead of a branch. The three
/// write doors pass `status.alerts`; **the cap screen passes
/// `CapAlerts.none(month)`**, which is "alterar o teto zera os dois avisos do
/// mês corrente e reavalia na hora".
SpendingCapEvaluation evaluateSpendingCap({
  required SpendingCap? cap,
  required DateTime month,
  required Money spent,
  required CapAlerts current,
}) {
  if (cap == null) return SpendingCapEvaluation.none;

  final crossed80 = CapThreshold.approaching.isCrossedBy(
    spent: spent,
    cap: cap.amount,
  );
  final crossed100 = CapThreshold.exceeded.isCrossedBy(
    spent: spent,
    cap: cap.amount,
  );

  return SpendingCapEvaluation(
    // The desired STATE of both marks, never a "mark it" order — and that is
    // what makes this same call the rearm when a cut stops being crossed.
    alerts: CapAlerts(
      month: month,
      warned80: crossed80,
      warned100: crossed100,
    ),
    triggered: [
      if (crossed80 && !current.warned80) CapThreshold.approaching,
      if (crossed100 && !current.warned100) CapThreshold.exceeded,
    ].toIList(),
  );
}

/// A cap of zero is born blown, and would divide by zero in `usagePercent`.
/// pt-BR: it is read on screen.
final class InvalidSpendingCap implements Exception {
  const InvalidSpendingCap();

  String get message => 'Informe um teto maior que zero.';

  @override
  String toString() => 'InvalidSpendingCap: $message';
}
