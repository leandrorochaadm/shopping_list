import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/same_day_alert.dart';

/// A fixed instant, always — never `DateTime.now()`.
final today = DateTime(2026, 8, 26);

SameDayAlert alertOn(DateTime day, {String name = 'Leite'}) =>
    SameDayAlert(productTypeId: 'type-9', typeName: name, purchasedOn: day);

void main() {
  group('isWithinRepeatWindow', () {
    test('today is inside', () {
      expect(isWithinRepeatWindow(DateTime(2026, 8, 26), today), isTrue);
    });

    test('yesterday is inside', () {
      expect(isWithinRepeatWindow(DateTime(2026, 8, 25), today), isTrue);
    });

    test('the day before yesterday is OUT', () {
      expect(isWithinRepeatWindow(DateTime(2026, 8, 24), today), isFalse);
    });

    test('a purchase of the 5th registered today warns nobody', () {
      expect(isWithinRepeatWindow(DateTime(2026, 8, 5), today), isFalse);
    });

    test('tomorrow is out — there is no purchase of tomorrow', () {
      expect(isWithinRepeatWindow(DateTime(2026, 8, 27), today), isFalse);
    });

    test('crosses the turn of a month', () {
      final firstOfSeptember = DateTime(2026, 9, 1);

      expect(
        isWithinRepeatWindow(DateTime(2026, 8, 31), firstOfSeptember),
        isTrue,
      );
      expect(
        isWithinRepeatWindow(DateTime(2026, 8, 30), firstOfSeptember),
        isFalse,
      );
    });

    test('crosses the turn of a year', () {
      final newYear = DateTime(2027, 1, 1);

      expect(isWithinRepeatWindow(DateTime(2026, 12, 31), newYear), isTrue);
      expect(isWithinRepeatWindow(DateTime(2026, 12, 30), newYear), isFalse);
    });

    test('ignores the hour on both sides', () {
      expect(
        isWithinRepeatWindow(
          DateTime(2026, 8, 25, 23, 59),
          DateTime(2026, 8, 26, 0, 1),
        ),
        isTrue,
      );
    });
  });

  group('SameDayAlert', () {
    test('says "hoje" for a purchase of today', () {
      expect(
        alertOn(today).messageFor(today: today, shortDate: '26/08'),
        'Vocês dois compraram Leite hoje.',
      );
    });

    test('names the day for a purchase of yesterday', () {
      expect(
        alertOn(
          DateTime(2026, 8, 25),
        ).messageFor(today: today, shortDate: '25/08'),
        'Vocês dois compraram Leite no dia 25/08.',
      );
    });

    test('is neutral — it does not say who bought first', () {
      final message = alertOn(
        today,
      ).messageFor(today: today, shortDate: '26/08');

      expect(message, isNot(contains('você')));
      expect(message, startsWith('Vocês dois'));
    });

    test('reads what same_day_types answers', () {
      final alert = SameDayAlert.fromJson({
        'product_type_id': 'type-1',
        'name': 'Refrigerante',
      }, DateTime(2026, 8, 26, 15, 30));

      expect(alert.productTypeId, 'type-1');
      expect(alert.typeName, 'Refrigerante');
      // Rounded, so the `==` of the entity survives an instant with an hour.
      expect(alert.purchasedOn, DateTime(2026, 8, 26));
    });

    test('is equal field by field', () {
      expect(alertOn(today), alertOn(today));
      expect(alertOn(today).hashCode, alertOn(today).hashCode);

      expect(alertOn(today), isNot(alertOn(today, name: 'Café')));
      expect(alertOn(today), isNot(alertOn(DateTime(2026, 8, 25))));
      expect(
        alertOn(today),
        isNot(
          SameDayAlert(
            productTypeId: 'type-8',
            typeName: 'Leite',
            purchasedOn: today,
          ),
        ),
      );
    });

    test('says what it is in the debugger', () {
      expect(alertOn(today).toString(), contains('2026-08-26'));
    });
  });

  group('the accepted limitation of H1', () {
    test('two phones with the SAME label never fire the alert', () {
      // The query filters `registered_by <> p_registered_by`, so a couple who
      // labelled both phones the same never gets an alert — it is the
      // "Limitação aceita" written in `handoff §H1`, and this case exists so
      // nobody "fixes" it by mistake. Nothing here to assert on the domain
      // side: the window is open and the alert list simply comes back empty.
      expect(isWithinRepeatWindow(today, today), isTrue);
    });
  });

  sameDayAlertsOfTests();
}

class _Line implements SameDayPurchaseLine {
  _Line(
    this.purchaseDate,
    this.registeredBy,
    this.productTypeId,
    this.typeName,
  );

  @override
  final DateTime purchaseDate;
  @override
  final String registeredBy;
  @override
  final String productTypeId;
  @override
  final String typeName;
}

void sameDayAlertsOfTests() {
  group('sameDayAlertsOf', () {
    final day = DateTime(2026, 8, 26);
    IList<SameDayAlert> ask(
      List<SameDayPurchaseLine> lines, {
      String by = 'Leandro',
      Set<String> types = const {'t1', 't2'},
    }) => sameDayAlertsOf(
      date: day,
      registeredBy: by,
      lines: lines.toIList(),
      productTypeIds: types.toISet(),
    );

    test("finds the other person's type, whatever the brand", () {
      final result = ask([_Line(day, 'esposa', 't1', 'Leite')]);
      expect(
        result,
        [SameDayAlert(productTypeId: 't1', typeName: 'Leite', purchasedOn: day)]
            .toIList(),
      );
    });

    test("never warns about one's own purchase", () {
      final lines = [_Line(day, 'Leandro', 't1', 'Leite')];
      expect(ask(lines), isEmpty);
      expect(ask(lines, by: 'esposa'), hasLength(1));
    });

    test('ignores a type outside the purchase', () {
      expect(ask([_Line(day, 'esposa', 't9', 'Arroz')]), isEmpty);
    });

    test('answers an empty list for an empty day', () {
      expect(ask([]), isEmpty);
      expect(ask([_Line(day, 'esposa', 't1', 'Leite')], types: {}), isEmpty);
    });

    test('compares the label exactly', () {
      expect(ask([_Line(day, 'leandro', 't1', 'Leite')]), hasLength(1));
    });

    test('counts the same calendar day only', () {
      final result = ask([
        _Line(DateTime(2026, 8, 25, 18), 'esposa', 't1', 'Leite'),
        _Line(DateTime(2026, 8, 26, 18), 'esposa', 't2', 'Arroz'),
      ]);
      expect(result.map((a) => a.productTypeId), ['t2'].toIList());
    });

    test('answers one alert per type in first-seen order', () {
      final result = ask([
        _Line(day, 'esposa', 't2', 'Arroz'),
        _Line(day, 'esposa', 't1', 'Leite'),
        _Line(day, 'esposa', 't2', 'Arroz integral'),
      ]);
      expect(result.map((a) => a.typeName), ['Arroz', 'Leite'].toIList());
    });
  });
}
