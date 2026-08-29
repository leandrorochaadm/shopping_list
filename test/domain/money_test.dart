import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/money.dart';

void main() {
  group('parse', () {
    test('reads a comma and a dot as the same separator', () {
      // The iOS number keyboard offers whichever the layout feels like.
      expect(Money.parse('56,70'), const Money(5670));
      expect(Money.parse('56.70'), const Money(5670));
    });

    test('reads a whole number as reais', () {
      expect(Money.parse('56'), const Money(5600));
      expect(Money.parse(' 7 '), const Money(700));
    });

    test('pads a single decimal place', () {
      // '56,7' is fifty-six reais and seventy cents, not seven.
      expect(Money.parse('56,7'), const Money(5670));
    });

    test('keeps the cent that a double would lose', () {
      // 0.35 * 100 in binary floating point is 34.999999999999996, and one
      // truncation later this would be Money(34). It is the whole reason the
      // parsing is done digit by digit.
      expect(Money.parse('0,35'), const Money(35));
      expect(Money.parse('1,07'), const Money(107));
      expect(Money.parse('8,29'), const Money(829));
    });

    test('accepts zero', () {
      // A free item is not a rule violation — the domain of `total_paid`
      // starts at zero, and the check in the schema says so.
      expect(Money.parse('0'), Money.zero);
      expect(Money.parse('0,00'), Money.zero);
    });

    test('refuses a third decimal place', () {
      // There is no tenth of a cent. Swallowing it would put a value on the
      // screen that the receipt never said.
      expect(() => Money.parse('56,700'), throwsA(isA<InvalidMoney>()));
    });

    test('refuses what is not a number', () {
      for (final typed in ['', '  ', 'abc', '5,6,7', '-3', '1 2', ',']) {
        expect(
          () => Money.parse(typed),
          throwsA(isA<InvalidMoney>()),
          reason: typed,
        );
      }
    });

    test('the exception carries the sentence the screen shows', () {
      expect(const InvalidMoney().message, 'Informe um valor válido.');
      expect(const InvalidMoney().toString(), contains('Informe um valor'));
    });
  });

  group('arithmetic', () {
    test('adds and subtracts in cents', () {
      expect(const Money(5670) + const Money(330), const Money(6000));
      expect(const Money(6000) - const Money(330), const Money(5670));
    });

    test('compares and orders', () {
      expect(const Money(100) < const Money(200), isTrue);
      expect(const Money(200) > const Money(100), isTrue);
      expect(const Money(100).compareTo(const Money(100)), 0);
      expect(
        ([const Money(300), const Money(100), const Money(200)]..sort())
            .first,
        const Money(100),
      );
    });

    test('knows it is zero', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money(1).isZero, isFalse);
    });
  });

  group('json', () {
    test('travels as the bare cents', () {
      expect(const Money(5670).toJson(), 5670);
      expect(Money.fromJson(5670), const Money(5670));
    });

    test('reads a num, which is what some PostgREST paths return', () {
      expect(Money.fromJson(5670.0), const Money(5670));
    });

    test('reads a missing value as zero', () {
      expect(Money.fromJson(null), Money.zero);
    });
  });

  test('equality is by cents, so Riverpod can filter an update', () {
    expect(const Money(5670), const Money(5670));
    expect(const Money(5670).hashCode, const Money(5670).hashCode);
    expect(const Money(5670), isNot(const Money(5671)));
    expect(const Money(5670).toString(), 'Money(5670)');
  });
}
