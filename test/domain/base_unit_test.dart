import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';

void main() {
  group('BaseUnit', () {
    test('has one whole unit per magnitude, and four of them', () {
      expect(BaseUnit.values, [
        BaseUnit.gram,
        BaseUnit.milliliter,
        BaseUnit.unit,
        BaseUnit.centimeter,
      ]);
      expect(BaseUnit.gram.label, 'g');
      expect(BaseUnit.milliliter.label, 'ml');
      expect(BaseUnit.unit.label, 'un');
      expect(BaseUnit.centimeter.label, 'cm');
    });

    test('knows how many stored units fit in the large one', () {
      expect(BaseUnit.gram.unitsPerLargeUnit, 1000);
      expect(BaseUnit.milliliter.unitsPerLargeUnit, 1000);
      expect(BaseUnit.unit.unitsPerLargeUnit, 1);
      expect(BaseUnit.centimeter.unitsPerLargeUnit, 100);
    });

    test('survives the round trip through JSON', () {
      for (final unit in BaseUnit.values) {
        expect(BaseUnit.fromJson(unit.toJson()), unit);
      }
    });
  });

  group('BaseUnit.parseAmount', () {
    test('reads a whole number in the stored unit', () {
      expect(BaseUnit.milliliter.parseAmount('350'), 350);
      expect(BaseUnit.gram.parseAmount('500'), 500);
      expect(BaseUnit.unit.parseAmount('6'), 6);
      expect(BaseUnit.centimeter.parseAmount('3000'), 3000);
    });

    test('trims what the keyboard leaves around the number', () {
      expect(BaseUnit.gram.parseAmount('  6000  '), 6000);
    });

    test('refuses any decimal separator, in every magnitude', () {
      // The typed unit became the small one, so there is nothing left to
      // write after a comma.
      for (final typed in ['2,5', '0.35', '1,05']) {
        expect(
          () => BaseUnit.gram.parseAmount(typed),
          throwsA(isA<AmountMustBeWhole>()),
          reason: typed,
        );
      }
    });

    test('refuses what is not a number, and refuses zero', () {
      for (final typed in ['', '   ', 'abc', '-5', '0']) {
        expect(
          () => BaseUnit.milliliter.parseAmount(typed),
          throwsA(isA<InvalidAmount>()),
          reason: typed,
        );
      }
    });

    test('refuses a number too big to hold instead of crashing', () {
      // The RegExp accepts twenty-five digits; `int.parse` would answer that
      // with a raw FormatException, which no screen catches.
      expect(
        () => BaseUnit.gram.parseAmount('9' * 25),
        throwsA(isA<InvalidAmount>()),
      );
    });

    test('says what to do, in pt-BR', () {
      expect(const InvalidAmount().message, 'Informe uma quantidade válida.');
      expect(const AmountMustBeWhole().message, 'Use um número inteiro.');
      expect(const InvalidAmount().toString(), contains('quantidade'));
      expect(const AmountMustBeWhole().toString(), contains('inteiro'));
    });
  });

  group('BaseUnit.formatQuantity', () {
    test('reads in the small unit until the large one is reached', () {
      expect(BaseUnit.gram.formatQuantity(999), '999 g');
      expect(BaseUnit.gram.formatQuantity(1000), '1 kg');
      expect(BaseUnit.gram.formatQuantity(900), '900 g');
      expect(BaseUnit.milliliter.formatQuantity(1250), '1,25 L');
      expect(BaseUnit.centimeter.formatQuantity(99), '99 cm');
      expect(BaseUnit.centimeter.formatQuantity(100), '1 m');
      expect(BaseUnit.centimeter.formatQuantity(110), '1,1 m');
    });

    test('never turns a count into a large unit', () {
      // There is no such thing as a "kilo-unit".
      expect(BaseUnit.unit.formatQuantity(12), '12 un');
      expect(BaseUnit.unit.formatQuantity(6000), '6000 un');
      expect(BaseUnit.unit.usesLargeUnit(6000), isFalse);
    });

    test('pads the fraction before trimming it', () {
      // 1050 g is 1,05 kg, not 1,5 kg.
      expect(BaseUnit.gram.formatQuantity(1050), '1,05 kg');
      expect(BaseUnit.gram.formatQuantity(2000), '2 kg');
    });
  });

  group('BaseUnit.formatQuantityPair', () {
    test('writes both ends at the scale of the whole', () {
      // Without this, 900 g out of a 6 kg average would read '900 de 6 kg'.
      expect(BaseUnit.gram.formatQuantityPair(900, 6000), '0,9 de 6 kg');
      expect(BaseUnit.gram.formatQuantityPair(200, 900), '200 de 900 g');
    });

    test('keeps the zero, which is an answer', () {
      expect(BaseUnit.gram.formatQuantityPair(0, 6000), '0 de 6 kg');
    });

    test('stays in the count, which has no large unit', () {
      expect(BaseUnit.unit.formatQuantityPair(2, 6), '2 de 6 un');
    });
  });

  group('BaseUnit tells the screen which word to use', () {
    test('prices in the large unit, always', () {
      expect(BaseUnit.gram.priceLabel, 'kg');
      expect(BaseUnit.milliliter.priceLabel, 'L');
      expect(BaseUnit.unit.priceLabel, 'un');
      expect(BaseUnit.centimeter.priceLabel, 'm');
    });

    test('fills a typable field in the stored unit, never the large one', () {
      expect(BaseUnit.gram.typedText(6000), '6000');
      expect(BaseUnit.milliliter.typedText(350), '350');
      expect(BaseUnit.centimeter.typedText(3000), '3000');
      expect(BaseUnit.unit.typedText(12), '12');
    });

    test('introduces the magnitude in one single sentence', () {
      expect(BaseUnit.gram.magnitudeLabel, 'Peso — grama (g)');
      expect(BaseUnit.milliliter.magnitudeLabel, 'Volume — mililitro (ml)');
      expect(BaseUnit.unit.magnitudeLabel, 'Contagem — unidade (un)');
      expect(BaseUnit.centimeter.magnitudeLabel, 'Tamanho — centímetro (cm)');
    });

    test('carries the pricing word and its article', () {
      expect(BaseUnit.gram.pricingNoun, 'quilo');
      expect(BaseUnit.gram.pricingArticle, 'o kg');
      expect(BaseUnit.unit.pricingArticle, 'a unidade');
      expect(BaseUnit.centimeter.pricingNoun, 'metro');
      expect(BaseUnit.centimeter.pricingArticle, 'o metro');
    });
  });
}
