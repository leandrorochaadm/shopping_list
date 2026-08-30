import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';

/// August 2026 — the month every case below talks about. A fixed instant,
/// never `DateTime.now()`.
final august = DateTime(2026, 8, 1);
const cap1500 = Money(150000);

SpendingCap capOf(Money amount) =>
    SpendingCap(amount: amount, effectiveFrom: august);

void main() {
  group('CapThreshold', () {
    test('writes the two numbers of the rule ONCE', () {
      expect(CapThreshold.approaching.percent, 80);
      expect(CapThreshold.exceeded.percent, 100);
    });

    test('derives the sentence from the number, never repeating it', () {
      expect(
        CapThreshold.approaching.message,
        'O gasto do mês passou de 80% do teto.',
      );
      // The sentence of the wireframe, word for word — and it names no month
      // (D-i).
      expect(CapThreshold.exceeded.message, 'O teto do mês estourou.');
      expect(CapThreshold.exceeded.message, isNot(contains('agosto')));
    });

    test('crosses exactly AT the cut, and not one cent before', () {
      // R$ 1.199,99 · R$ 1.200,00 · R$ 1.200,01 over a R$ 1.500 cap.
      expect(
        CapThreshold.approaching.isCrossedBy(
          spent: const Money(119999),
          cap: cap1500,
        ),
        isFalse,
      );
      expect(
        CapThreshold.approaching.isCrossedBy(
          spent: const Money(120000),
          cap: cap1500,
        ),
        isTrue,
      );
      expect(
        CapThreshold.approaching.isCrossedBy(
          spent: const Money(120001),
          cap: cap1500,
        ),
        isTrue,
      );
    });

    test('the 100% cut is the cap itself, to the cent', () {
      expect(
        CapThreshold.exceeded.isCrossedBy(
          spent: const Money(149999),
          cap: cap1500,
        ),
        isFalse,
      );
      expect(
        CapThreshold.exceeded.isCrossedBy(
          spent: const Money(150000),
          cap: cap1500,
        ),
        isTrue,
      );
      expect(
        CapThreshold.exceeded.isCrossedBy(
          spent: const Money(150001),
          cap: cap1500,
        ),
        isTrue,
      );
    });

    test('compares without dividing — a cap no round percent can express', () {
      // R$ 3,33: 80% of it is R$ 2,664, so R$ 2,66 is below and R$ 2,67 is
      // above. A division into a double would put the boundary somewhere
      // else, once.
      expect(
        CapThreshold.approaching.isCrossedBy(
          spent: const Money(266),
          cap: const Money(333),
        ),
        isFalse,
      );
      expect(
        CapThreshold.approaching.isCrossedBy(
          spent: const Money(267),
          cap: const Money(333),
        ),
        isTrue,
      );
    });
  });

  group('SpendingCap', () {
    test('refuses a cap of zero — it would be born blown (D-j)', () {
      expect(
        () => SpendingCap(amount: Money.zero, effectiveFrom: august),
        throwsA(isA<InvalidSpendingCap>()),
      );
      expect(
        () => SpendingCap(amount: const Money(-1), effectiveFrom: august),
        throwsA(isA<InvalidSpendingCap>()),
      );
    });

    test('takes the effective date back to day 1 of its month', () {
      final cap = SpendingCap(
        amount: cap1500,
        effectiveFrom: DateTime(2026, 8, 20, 14, 30),
      );

      expect(cap.effectiveFrom, DateTime(2026, 8, 1));
    });

    test('answers the percentage the documents write — 87 of 1300/1500', () {
      // `requisitos §9` and `wireframes §Tela E3` both write this case as
      // 87%, and 86,66…% truncated would answer 86.
      expect(capOf(cap1500).usagePercent(const Money(130000)), 87);
    });

    test('rounds the percentage, both ways', () {
      // 74,4% → 74 and 75,6% → 76, over a R$ 1.000 cap.
      expect(capOf(const Money(100000)).usagePercent(const Money(74400)), 74);
      expect(capOf(const Money(100000)).usagePercent(const Money(75600)), 76);
      expect(capOf(const Money(100000)).usagePercent(const Money(120000)), 120);
    });

    test('is equal field by field', () {
      expect(capOf(cap1500), capOf(cap1500));
      expect(capOf(cap1500).hashCode, capOf(cap1500).hashCode);

      expect(capOf(cap1500), isNot(capOf(const Money(180000))));
      expect(
        capOf(cap1500),
        isNot(SpendingCap(amount: cap1500, effectiveFrom: DateTime(2026, 7, 1))),
      );
    });

    test('says what it is in the debugger', () {
      expect(capOf(cap1500).toString(), contains('2026-08-01'));
    });
  });

  group('CapAlerts', () {
    test('is born with neither cut marked', () {
      final alerts = CapAlerts.none(DateTime(2026, 8, 20));

      expect(alerts.month, august);
      expect(alerts.warned80, isFalse);
      expect(alerts.warned100, isFalse);
    });

    test('sends the month and both marks to the SQL', () {
      expect(
        CapAlerts(month: august, warned80: true).toJson(),
        {'month': '2026-08-01', 'warned_80': true, 'warned_100': false},
      );
    });

    test('is equal field by field', () {
      expect(CapAlerts(month: august), CapAlerts(month: august));
      expect(
        CapAlerts(month: august).hashCode,
        CapAlerts(month: august).hashCode,
      );

      expect(
        CapAlerts(month: august),
        isNot(CapAlerts(month: DateTime(2026, 7, 1))),
      );
      expect(
        CapAlerts(month: august),
        isNot(CapAlerts(month: august, warned80: true)),
      );
      expect(
        CapAlerts(month: august),
        isNot(CapAlerts(month: august, warned100: true)),
      );
    });
  });

  group('MonthCapStatus', () {
    Map<String, dynamic> row({
      Object? capAmount = 150000,
      String effectiveFrom = '2026-03-01',
      Object? spent = 130000,
      bool warned80 = false,
      bool warned100 = false,
    }) => {
      'month': '2026-08-01',
      'cap_amount': capAmount,
      'cap_effective_from': capAmount == null ? null : effectiveFrom,
      'spent': spent,
      'warned_80': warned80,
      'warned_100': warned100,
    };

    test('reads a month with a cap in force since another month', () {
      final status = MonthCapStatus.fromJson(row());

      expect(status.month, august);
      expect(status.hasCap, isTrue);
      // The month the cap STARTED in, never the month asked about.
      expect(status.cap!.effectiveFrom, DateTime(2026, 3, 1));
      expect(status.cap!.amount, cap1500);
      expect(status.spent, const Money(130000));
      expect(status.alerts.month, august);
    });

    test('reads a month with no cap — forever', () {
      final status = MonthCapStatus.fromJson(row(capAmount: null));

      expect(status.hasCap, isFalse);
      expect(status.cap, isNull);
      expect(status.spent, const Money(130000));
    });

    test('reads a hand-written cap of zero as NO cap, not as a crash', () {
      expect(MonthCapStatus.fromJson(row(capAmount: 0)).hasCap, isFalse);
    });

    test('reads the two marks', () {
      final status = MonthCapStatus.fromJson(
        row(warned80: true, warned100: true),
      );

      expect(status.alerts.warned80, isTrue);
      expect(status.alerts.warned100, isTrue);
    });

    test('is equal field by field', () {
      MonthCapStatus of({
        DateTime? month,
        SpendingCap? cap,
        Money spent = const Money(130000),
        CapAlerts? alerts,
      }) => MonthCapStatus(
        month: month ?? august,
        cap: cap ?? capOf(cap1500),
        spent: spent,
        alerts: alerts ?? CapAlerts(month: august),
      );

      expect(of(), of());
      expect(of().hashCode, of().hashCode);

      expect(of(), isNot(of(month: DateTime(2026, 7, 1))));
      expect(of(), isNot(of(cap: capOf(const Money(180000)))));
      expect(of(), isNot(of(spent: const Money(1))));
      expect(of(), isNot(of(alerts: CapAlerts(month: august, warned80: true))));
    });
  });

  group('evaluateSpendingCap', () {
    SpendingCapEvaluation evaluate({
      SpendingCap? cap,
      required int spent,
      bool warned80 = false,
      bool warned100 = false,
    }) => evaluateSpendingCap(
      cap: cap ?? capOf(cap1500),
      month: august,
      spent: Money(spent),
      current: CapAlerts(
        month: august,
        warned80: warned80,
        warned100: warned100,
      ),
    );

    test('a month with no cap writes nothing and shows nothing', () {
      final evaluation = evaluateSpendingCap(
        cap: null,
        month: august,
        spent: const Money(999999),
        current: CapAlerts.none(august),
      );

      expect(evaluation, SpendingCapEvaluation.none);
      // Null and not empty: there is no row to touch, which is a different
      // fact from "there is a row and both marks are off".
      expect(evaluation.alerts, isNull);
      expect(evaluation.triggered, isEmpty);
      expect(evaluation.headline, isNull);
    });

    test('the purchase that takes the month to 80% warns', () {
      final evaluation = evaluate(spent: 120000);

      expect(evaluation.triggered, [CapThreshold.approaching]);
      expect(evaluation.headline, CapThreshold.approaching);
      expect(evaluation.alerts!.warned80, isTrue);
      expect(evaluation.alerts!.warned100, isFalse);
    });

    test('the NEXT purchase of the same month does not repeat it', () {
      final evaluation = evaluate(spent: 130000, warned80: true);

      expect(evaluation.triggered, isEmpty);
      expect(evaluation.headline, isNull);
      // The mark is written again all the same: the SQL preserves the first
      // stamp, and `false` here would be a rearm nobody asked for.
      expect(evaluation.alerts!.warned80, isTrue);
    });

    test('the purchase that blows the cap warns the graver one ALONE', () {
      // Both cuts fire in the same write, and only "estourou" speaks (D-h).
      final evaluation = evaluate(spent: 160000);

      expect(evaluation.triggered, [
        CapThreshold.approaching,
        CapThreshold.exceeded,
      ]);
      expect(evaluation.headline, CapThreshold.exceeded);
      // …and BOTH marks are written, which is what stops the next purchase
      // from firing the 100% alone.
      expect(evaluation.alerts!.warned80, isTrue);
      expect(evaluation.alerts!.warned100, isTrue);
    });

    test('a cap born already blown writes both marks', () {
      // The cap screen evaluates over CapAlerts.none, which is the rearm the
      // save does first.
      final evaluation = evaluateSpendingCap(
        cap: capOf(cap1500),
        month: august,
        spent: const Money(180000),
        current: CapAlerts.none(august),
      );

      expect(evaluation.headline, CapThreshold.exceeded);
      expect(evaluation.alerts!.warned80, isTrue);
      expect(evaluation.alerts!.warned100, isTrue);
    });

    test('the 100% fires alone when the 80% was already given', () {
      final evaluation = evaluate(spent: 160000, warned80: true);

      expect(evaluation.triggered, [CapThreshold.exceeded]);
      expect(evaluation.headline, CapThreshold.exceeded);
    });

    test('a correction that drops the month REARMS both marks', () {
      // R$ 1.100 over a R$ 1.500 cap is under both cuts: `false` is not
      // "unknown", it is the rearm.
      final evaluation = evaluate(
        spent: 110000,
        warned80: true,
        warned100: true,
      );

      expect(evaluation.alerts!.warned80, isFalse);
      expect(evaluation.alerts!.warned100, isFalse);
      // A rearm is not an alert: nothing to show.
      expect(evaluation.triggered, isEmpty);
    });

    test('and the cut fires again once it is crossed a second time', () {
      final rearmed = evaluate(spent: 110000, warned80: true);
      final again = evaluateSpendingCap(
        cap: capOf(cap1500),
        month: august,
        spent: const Money(125000),
        current: rearmed.alerts!,
      );

      expect(again.triggered, [CapThreshold.approaching]);
    });

    test('raising the cap fires nothing NOW and gives the alert back', () {
      // R$ 1.300 spent, the 80% already given, the cap going to R$ 1.800:
      // 1300 is 72% of 1800, so the mark is cleared and nothing is shown.
      final raised = evaluateSpendingCap(
        cap: SpendingCap(amount: const Money(180000), effectiveFrom: august),
        month: august,
        spent: const Money(130000),
        // The save clears the month's marks first: this is what the screen
        // evaluates over.
        current: CapAlerts.none(august),
      );

      expect(raised.triggered, isEmpty);
      expect(raised.alerts!.warned80, isFalse);

      // …and the purchase that takes the month to R$ 1.440 brings it back.
      final later = evaluateSpendingCap(
        cap: SpendingCap(amount: const Money(180000), effectiveFrom: august),
        month: august,
        spent: const Money(144000),
        current: raised.alerts!,
      );

      expect(later.triggered, [CapThreshold.approaching]);
    });

    test('keys the marks by the FIRST day of the month it was given', () {
      final evaluation = evaluateSpendingCap(
        cap: capOf(cap1500),
        month: DateTime(2026, 8, 20),
        spent: const Money(120000),
        current: CapAlerts.none(DateTime(2026, 8, 20)),
      );

      expect(evaluation.alerts!.month, august);
    });
  });

  group('SpendingCapEvaluation', () {
    test('is equal field by field', () {
      final a = evaluateSpendingCap(
        cap: capOf(cap1500),
        month: august,
        spent: const Money(120000),
        current: CapAlerts.none(august),
      );
      final b = evaluateSpendingCap(
        cap: capOf(cap1500),
        month: august,
        spent: const Money(120000),
        current: CapAlerts.none(august),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(SpendingCapEvaluation.none));
      expect(
        a,
        isNot(
          SpendingCapEvaluation(
            alerts: a.alerts,
            triggered: const IList.empty(),
          ),
        ),
      );
    });
  });

  group('InvalidSpendingCap', () {
    test('says what to do, in pt-BR', () {
      const failure = InvalidSpendingCap();

      expect(failure.message, 'Informe um teto maior que zero.');
      expect(
        failure.toString(),
        'InvalidSpendingCap: Informe um teto maior que zero.',
      );
    });
  });
}
