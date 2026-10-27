import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/domain/models/spending_cap_sync.dart';

final aug = DateTime(2019, 8);
final oct = DateTime(2019, 10);
final stamp = DateTime.utc(2019, 8, 10, 12);
final older = DateTime.utc(2019, 8, 1, 9);

SpendingCap capOf(int cents, DateTime from) =>
    SpendingCap(amount: Money(cents), effectiveFrom: from);

CapAlerts wanted(DateTime m, bool a, bool b) =>
    CapAlerts(month: m, warned80: a, warned100: b);

StoredCapAlert stored(
  DateTime m, {
  DateTime? a,
  DateTime? b,
  String id = 'r1',
}) => StoredCapAlert(id: id, month: m, warned80At: a, warned100At: b);

IList<CapAlertStep> plan(
  List<CapAlerts> w,
  List<StoredCapAlert> e, {
  bool rearm = false,
}) => planCapAlertWrites(
  wanted: w.toIList(),
  existing: e.toIList(),
  stampedAt: stamp,
  rearm: rearm,
);

IList<MonthCapStatus> statuses({
  List<DateTime> months = const [],
  List<SpendingCap> caps = const [],
  Map<DateTime, Money> spent = const {},
  List<StoredCapAlert> alerts = const [],
}) => buildMonthCapStatuses(
  months: months.toIList(),
  caps: caps.toIList(),
  spentByMonth: spent.toIMap(),
  alerts: alerts.toIList(),
);

void main() {
  group('buildMonthCapStatuses', () {
    test('answers no cap when none was ever configured', () {
      final r = statuses(months: [aug]);
      expect(r.single.cap, isNull);
      expect(r.single.hasCap, isFalse);
    });

    test(
      'keeps a month before the first cap without one, spending still counted',
      () {
        final r = statuses(
          months: [DateTime(2019, 7)],
          caps: [capOf(150000, aug)],
          spent: {DateTime(2019, 7): Money(3300)},
        );
        expect(r.single.cap, isNull);
        expect(r.single.spent, Money(3300));
      },
    );

    test('answers each month with the cap in force at its time', () {
      final r = statuses(
        months: [aug, oct],
        caps: [capOf(150000, aug), capOf(180000, DateTime(2019, 9))],
      );
      expect(r[0].cap!.amount, Money(150000));
      expect(r[1].cap!.amount, Money(180000));
      expect(r[1].cap!.effectiveFrom, DateTime(2019, 9));
    });

    test(
      'a cap starting in the month applies, one starting next month does not',
      () {
        final r = statuses(
          months: [aug],
          caps: [capOf(100, aug), capOf(200, DateTime(2019, 9))],
        );
        expect(r.single.cap!.amount, Money(100));
      },
    );

    test(
      'answers ordered by month, once per month, not in the order asked',
      () {
        final r = statuses(months: [oct, aug, DateTime(2019, 10, 15)]);
        expect(r.map((s) => s.month), [aug, oct].toIList());
      },
    );

    test('sums every key that falls in the month', () {
      final r = statuses(
        months: [aug, oct],
        spent: {
          DateTime(2019, 8, 10): Money(1000),
          DateTime(2019, 8, 20): Money(500),
        },
      );
      expect(r[0].spent, Money(1500));
      expect(r[1].spent, Money.zero);
    });

    test('reads a stamp as crossed and a missing row as not crossed', () {
      final r = statuses(
        months: [aug, oct],
        alerts: [stored(aug, a: stamp)],
      );
      expect(r[0].alerts, wanted(aug, true, false));
      expect(r[1].alerts, wanted(oct, false, false));
    });

    test('answers an empty list for no month asked', () {
      expect(statuses(caps: [capOf(100, aug)]), isEmpty);
    });
  });

  group('planCapAlertWrites', () {
    test('creates the row stamping only the crossed cut', () {
      final s = plan([wanted(aug, true, false)], []).single;
      expect(s.write, CapAlertWrite.create);
      expect(s.recordId, isNull);
      expect(s.warned80At, stamp);
      expect(s.warned100At, isNull);
    });

    test('creates the row with both stamps', () {
      final s = plan([wanted(aug, true, true)], []).single;
      expect(s.write, CapAlertWrite.create);
      expect(s.warned80At, stamp);
      expect(s.warned100At, stamp);
    });

    test('keeps the first stamp and writes nothing', () {
      final s = plan(
        [wanted(aug, true, false)],
        [stored(aug, a: older)],
      ).single;
      expect(s.write, CapAlertWrite.none);
      expect(s.warned80At, older);
      expect(s.recordId, 'r1');
    });

    test('deletes the row when no cut is crossed any more', () {
      final s = plan(
        [wanted(aug, false, false)],
        [stored(aug, a: older)],
      ).single;
      expect(s.write, CapAlertWrite.delete);
      expect(s.recordId, 'r1');
    });

    test('updates keeping one stamp and clearing the other', () {
      final s = plan(
        [wanted(aug, true, false)],
        [stored(aug, a: older, b: older)],
      ).single;
      expect(s.write, CapAlertWrite.update);
      expect(s.warned80At, older);
      expect(s.warned100At, isNull);
    });

    test('stamps only the newly crossed cut', () {
      final s = plan([wanted(aug, true, true)], [stored(aug, a: older)]).single;
      expect(s.write, CapAlertWrite.update);
      expect(s.warned80At, older);
      expect(s.warned100At, stamp);
    });

    test('writes nothing for an uncrossed month with no row', () {
      final s = plan([wanted(aug, false, false)], []).single;
      expect(s.write, CapAlertWrite.none);
      expect(s.recordId, isNull);
    });

    test('on rearm ignores the stored stamps but reuses the row', () {
      final row = stored(aug, a: older, b: older);
      final gone = plan([wanted(aug, false, false)], [row], rearm: true).single;
      expect(gone.write, CapAlertWrite.delete);
      final again = plan([wanted(aug, true, false)], [row], rearm: true).single;
      expect(again.write, CapAlertWrite.update);
      expect(again.recordId, 'r1');
      expect(again.warned80At, stamp);
      expect(again.warned100At, isNull);
    });

    test('never touches a month that was not asked', () {
      final r = plan(
        [wanted(aug, true, false)],
        [stored(DateTime(2019, 7), a: older, id: 'j')],
      );
      expect(r.map((s) => s.month), [aug].toIList());
      expect(r.single.write, CapAlertWrite.create);
    });

    test('plans one step per month, in the order asked', () {
      final r = plan([wanted(oct, true, false), wanted(aug, true, false)], []);
      expect(r.map((s) => s.month), [oct, aug].toIList());
    });

    test('plans nothing when no month is wanted', () {
      expect(plan([], [stored(aug, a: older)]), isEmpty);
    });

    test('throws when a month comes twice', () {
      expect(
        () => plan([wanted(aug, true, false), wanted(aug, false, false)], []),
        throwsArgumentError,
      );
      expect(
        () => plan(
          [wanted(aug, true, false)],
          [stored(aug, a: older), stored(aug, b: older, id: 'r2')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('StoredCapAlert', () {
    final base = stored(aug, a: stamp, b: older);

    test('equals with the same fields and differs one field at a time', () {
      final same = stored(aug, a: stamp, b: older);
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(stored(aug, a: stamp, b: older, id: 'x')));
      expect(base, isNot(stored(oct, a: stamp, b: older)));
      expect(base, isNot(stored(aug, a: older, b: older)));
      expect(base, isNot(stored(aug, a: stamp, b: stamp)));
    });

    test('says what it is in the debugger', () {
      expect(base.toString(), contains('StoredCapAlert(r1, 2019-08-01'));
    });
  });

  group('CapAlertStep', () {
    CapAlertStep step({
      DateTime? month,
      String? id = 'r1',
      DateTime? a,
      DateTime? b,
      CapAlertWrite w = CapAlertWrite.update,
    }) => CapAlertStep(
      month: month ?? aug,
      recordId: id,
      warned80At: a,
      warned100At: b,
      write: w,
    );

    test('equals with the same fields and differs one field at a time', () {
      final base = step(a: stamp, b: older);
      final same = step(a: stamp, b: older);
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(step(month: oct, a: stamp, b: older)));
      expect(base, isNot(step(id: null, a: stamp, b: older)));
      expect(base, isNot(step(a: older, b: older)));
      expect(base, isNot(step(a: stamp, b: stamp)));
      expect(base, isNot(step(a: stamp, b: older, w: CapAlertWrite.none)));
    });

    test('says what it is in the debugger', () {
      expect(step(a: stamp).toString(), contains('CapAlertStep(2019-08-01'));
    });
  });
}
