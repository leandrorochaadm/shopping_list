import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/ui/core/unit_specs.dart';
import 'package:tekton_core/tekton_core.dart';

void main() {
  group('specOf', () {
    test('pairs the gram with the kilogram mask', () {
      expect(specOf(BaseUnit.gram), UnitSpec.weight);
      expect(specOf(BaseUnit.gram).decimalDigits, 3);
      expect(specOf(BaseUnit.gram).suffix, 'kg');
    });

    test('pairs the millilitre with the litre mask', () {
      expect(specOf(BaseUnit.milliliter), UnitSpec.volume);
      expect(specOf(BaseUnit.milliliter).decimalDigits, 3);
      expect(specOf(BaseUnit.milliliter).suffix, 'L');
    });

    test('pairs the centimetre with the metre mask', () {
      expect(specOf(BaseUnit.centimeter), UnitSpec.length);
      expect(specOf(BaseUnit.centimeter).decimalDigits, 2);
      expect(specOf(BaseUnit.centimeter).suffix, 'm');
    });

    test('counts whole units and keeps the un suffix', () {
      expect(specOf(BaseUnit.unit).decimalDigits, 0);
      expect(specOf(BaseUnit.unit).suffix, 'un');
    });
  });

  group('countSpec', () {
    test('counts pieces with no unit at all', () {
      expect(countSpec.decimalDigits, 0);
      expect(countSpec.suffix, isNull);
    });

    test('is not the spec of a type counted by unit', () {
      expect(countSpec.suffix, isNot(specOf(BaseUnit.unit).suffix));
    });
  });

  group('round trip', () {
    const values = <int>[1, 350, 1000, 999999999];

    for (final unit in BaseUnit.values) {
      test('parse undoes format for ${unit.name}', () {
        final spec = specOf(unit);
        for (final value in values) {
          expect(spec.parse(spec.format(value)), value, reason: '$value');
        }
      });
    }

    test('parse undoes format for the piece count', () {
      for (final value in values) {
        expect(countSpec.parse(countSpec.format(value)), value);
      }
    });

    test('parse undoes format for money', () {
      for (final value in values) {
        expect(UnitSpec.currency.parse(UnitSpec.currency.format(value)), value);
      }
    });
  });

  group('the empty field', () {
    test('reads as zero and never throws', () {
      expect(UnitSpec.currency.parse(''), 0);
      expect(specOf(BaseUnit.gram).parse(''), 0);
      expect(countSpec.parse(''), 0);
    });

    test('format of zero is text, not the empty string', () {
      expect(specOf(BaseUnit.gram).format(0), '0,000');
      expect(countSpec.format(0), '0');
    });
  });
}
