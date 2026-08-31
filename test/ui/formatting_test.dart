import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/ui/core/formatting.dart';

void main() {
  // `main()` does not run in a test, and without this DateFormat throws on
  // locale data it never loaded.
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('formatMoney', () {
    test('writes reais with a comma and a dot for thousands', () {
      expect(formatMoney(const Money(123456)), r'R$ 1.234,56');
      expect(formatMoney(const Money(6200)), r'R$ 62,00');
      expect(formatMoney(const Money(5)), r'R$ 0,05');
      expect(formatMoney(Money.zero), r'R$ 0,00');
    });

    test('keeps the cent an integer would lose through a division', () {
      // Built digit by digit from the int: this is the boundary where
      // rounding is allowed, not where a float decides the last cent.
      expect(formatMoney(const Money(35)), r'R$ 0,35');
      expect(formatMoney(const Money(107)), r'R$ 1,07');
      expect(formatMoney(const Money(999999)), r'R$ 9.999,99');
    });

    test('a negative total keeps its sign in front of the symbol', () {
      // No screen shows one today; H9's correction can produce one.
      expect(formatMoney(const Money(-6200)), r'-R$ 62,00');
    });

    test('the symbol carries a plain space, which a test can match', () {
      // NumberFormat.currency puts a NON-BREAKING space here, and a
      // find.text() would never match it.
      expect(formatMoney(const Money(6200)).codeUnitAt(2), 0x20);
    });
  });

  group('formatMoneyPlain', () {
    test('writes what goes into a text field, with no symbol', () {
      expect(formatMoneyPlain(const Money(6200)), '62,00');
      expect(formatMoneyPlain(const Money(35)), '0,35');
      expect(formatMoneyPlain(Money.zero), '0,00');
    });

    test('drops the thousands separator', () {
      // A field that came back '1.234,56' would be refused by Money.parse,
      // which reads a dot as a decimal point — and rightly so.
      expect(formatMoneyPlain(const Money(123456)), '1234,56');
    });

    test('what it writes is what Money.parse reads back', () {
      // The round trip the Valor field makes on every quantity change.
      for (final cents in [0, 5, 35, 6200, 123456]) {
        expect(
          Money.parse(formatMoneyPlain(Money(cents))),
          Money(cents),
          reason: '$cents',
        );
      }
    });
  });

  group('formatPercent', () {
    test('writes the tenth with the comma of pt-BR', () {
      expect(formatPercent(585), '58,5%');
    });

    test('the whole share writes the zero of the decimal place', () {
      // What a category with a single type shows.
      expect(formatPercent(1000), '100,0%');
    });

    test('zero is written whole', () {
      expect(formatPercent(0), '0,0%');
    });

    test('half a tenth keeps the units digit', () {
      expect(formatPercent(5), '0,5%');
    });

    test('above 100% is representable, and reaches the screen', () {
      // The rounding drift of three lines adding up past the whole.
      expect(formatPercent(1001), '100,1%');
    });
  });

  group('the month labels of screen 5', () {
    test('formatMonthName capitalizes what DateFormat lowers', () {
      // A button reading `‹ julho` is the kind of thing only seen on the
      // phone: pt-BR writes month names in lower case.
      expect(formatMonthName(DateTime(2026, 7, 1)), 'Julho');
      expect(formatMonthName(DateTime(2026, 8, 1)), 'Agosto');
      expect(formatMonthName(DateTime(2026, 9, 1)), 'Setembro');
      expect(formatMonthName(DateTime(2026, 3, 1)), 'Março');
    });

    test('formatMonthYear carries the year, because the shortcuts cross it', () {
      expect(formatMonthYear(DateTime(2026, 8, 15)), 'Agosto/2026');
      expect(formatMonthYear(DateTime(2025, 12, 31)), 'Dezembro/2025');
      expect(formatMonthYear(DateTime(2027, 1, 1)), 'Janeiro/2027');
    });
  });

  group('formatDate', () {
    test('writes the Brazilian order', () {
      expect(formatDate(DateTime(2026, 8, 18)), '18/08/2026');
      expect(formatDate(DateTime(2026, 1, 5)), '05/01/2026');
    });

    test('the short form drops the year, for the draft banner', () {
      expect(formatShortDate(DateTime(2026, 8, 18)), '18/08');
    });
  });
}
