import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';

void main() {
  group('BaseUnit', () {
    test('offers only the measures of its own kind', () {
      // Showing all five at once is how "350 g" of soft drink gets typed.
      expect(BaseUnit.kilogram.measures, [
        MeasureUnit.gram,
        MeasureUnit.kilogram,
      ]);
      expect(BaseUnit.liter.measures, [
        MeasureUnit.milliliter,
        MeasureUnit.liter,
      ]);
      expect(BaseUnit.unit.measures, [MeasureUnit.unit]);
    });

    test('survives the round trip through JSON', () {
      for (final unit in BaseUnit.values) {
        expect(BaseUnit.fromJson(unit.toJson()), unit);
      }
    });
  });

  group('MeasureUnit.parseAmount', () {
    test('reads a whole number in the smallest unit', () {
      expect(MeasureUnit.milliliter.parseAmount('350'), 350);
      expect(MeasureUnit.gram.parseAmount('500'), 500);
      expect(MeasureUnit.unit.parseAmount('6'), 6);
    });

    test('converts the bigger unit into the smallest one', () {
      expect(MeasureUnit.liter.parseAmount('2'), 2000);
      expect(MeasureUnit.kilogram.parseAmount('1'), 1000);
    });

    test('reads the decimal without ever touching a double', () {
      // 0.35 * 1000 in binary floating point is 349.99999999999994, and one
      // truncation later the bottle holds 349 ml. This is the boundary the
      // whole B5 decision exists for.
      expect(MeasureUnit.liter.parseAmount('0,35'), 350);
      expect(MeasureUnit.liter.parseAmount('0.35'), 350);
      expect(MeasureUnit.kilogram.parseAmount('1,5'), 1500);
      expect(MeasureUnit.kilogram.parseAmount('0,001'), 1);
    });

    test('accepts the comma of pt-BR and the dot of the keyboard', () {
      expect(
        MeasureUnit.liter.parseAmount('1,25'),
        MeasureUnit.liter.parseAmount('1.25'),
      );
    });

    test('pads a short fraction instead of misreading it', () {
      // '1,5' kg is 1500 g, not 1005 g.
      expect(MeasureUnit.kilogram.parseAmount('1,5'), 1500);
      expect(MeasureUnit.kilogram.parseAmount('1,05'), 1050);
    });

    test('refuses more precision than the unit can hold', () {
      // Half a millilitre does not exist here.
      expect(
        () => MeasureUnit.liter.parseAmount('0,3505'),
        throwsA(isA<AmountTooPrecise>()),
      );
      expect(
        () => MeasureUnit.milliliter.parseAmount('350,5'),
        throwsA(isA<AmountTooPrecise>()),
      );
    });

    test('refuses what is not a number, and refuses zero', () {
      for (final typed in ['', '   ', 'abc', '1,2,3', '-5', '0', '0,0']) {
        expect(
          () => MeasureUnit.liter.parseAmount(typed),
          throwsA(isA<Exception>()),
          reason: typed,
        );
      }
    });

    test('says what to do, in pt-BR', () {
      expect(const InvalidAmount().message, 'Informe uma quantidade válida.');
      expect(
        const AmountTooPrecise(3).message,
        'Use no máximo 3 casas decimais.',
      );
      expect(const InvalidAmount().toString(), contains('quantidade'));
      expect(const AmountTooPrecise(3).toString(), contains('casas'));
    });

    test('never offers decimal places the unit does not have', () {
      // A type counted by unit holds zero places, and the old fixed sentence
      // offered three that do not exist. The item dialog is the first screen
      // to show this one.
      expect(const AmountTooPrecise(0).message, 'Use um número inteiro.');
      expect(
        () => MeasureUnit.unit.parseAmount('0,5'),
        throwsA(
          isA<AmountTooPrecise>().having(
            (e) => e.message,
            'message',
            'Use um número inteiro.',
          ),
        ),
      );
    });
  });

  group('MeasureUnit.decimalPlaces and format', () {
    test('knows how many places each unit can hold', () {
      expect(MeasureUnit.kilogram.decimalPlaces, 3);
      expect(MeasureUnit.liter.decimalPlaces, 3);
      expect(MeasureUnit.gram.decimalPlaces, 0);
      expect(MeasureUnit.milliliter.decimalPlaces, 0);
      expect(MeasureUnit.unit.decimalPlaces, 0);
    });

    test('writes the integer the way it is read', () {
      expect(MeasureUnit.milliliter.format(350), '350');
      expect(MeasureUnit.liter.format(2500), '2,5');
      // No ',0' dangling on a round amount.
      expect(MeasureUnit.liter.format(2000), '2');
      expect(MeasureUnit.kilogram.format(1050), '1,05');
      expect(MeasureUnit.unit.format(3), '3');
    });
  });

  group('BaseUnit measures the list quantity', () {
    test('types in the base measure, never in the smallest one', () {
      expect(BaseUnit.kilogram.typedMeasure, MeasureUnit.kilogram);
      expect(BaseUnit.liter.typedMeasure, MeasureUnit.liter);
      expect(BaseUnit.unit.typedMeasure, MeasureUnit.unit);

      expect(BaseUnit.kilogram.smallestUnits, 1000);
      expect(BaseUnit.liter.smallestUnits, 1000);
      expect(BaseUnit.unit.smallestUnits, 1);
    });

    test('composes the amount with the label of the base', () {
      expect(BaseUnit.kilogram.formatQuantity(6000), '6 kg');
      expect(BaseUnit.liter.formatQuantity(2500), '2,5 L');
      expect(BaseUnit.unit.formatQuantity(3), '3 un');
    });
  });
}
