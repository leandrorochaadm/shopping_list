import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/selling_choice.dart';

void main() {
  group('SellingChoice.label', () {
    test('is the word read on screen, in pt-BR', () {
      expect(SellingChoice.weight.label, 'Peso');
      expect(SellingChoice.unit.label, 'Unidade');
      expect(SellingChoice.volume.label, 'Volume');
      expect(SellingChoice.length.label, 'Tamanho');
    });
  });

  group('SellingChoice.mode', () {
    test('maps weight and volume to the SAME by_weight', () {
      expect(SellingChoice.weight.mode, SellingMode.byWeight);
      expect(SellingChoice.volume.mode, SellingMode.byWeight);
    });

    test('maps length to by_weight too — it is the loose product', () {
      expect(SellingChoice.length.mode, SellingMode.byWeight);
    });

    test('maps unit to by_piece', () {
      expect(SellingChoice.unit.mode, SellingMode.byPiece);
    });
  });

  group('SellingChoice.bulkOf', () {
    test('is weight under a type measured in kilograms', () {
      expect(SellingChoice.bulkOf(BaseUnit.gram), SellingChoice.weight);
    });

    test('is volume under a type measured in litres', () {
      expect(SellingChoice.bulkOf(BaseUnit.milliliter), SellingChoice.volume);
    });

    test('is length under a type measured in centimetres', () {
      expect(SellingChoice.bulkOf(BaseUnit.centimeter), SellingChoice.length);
    });

    test('is null under a type counted by unit — there is no bulk', () {
      expect(SellingChoice.bulkOf(BaseUnit.unit), isNull);
    });

    test('is null while no type is chosen', () {
      expect(SellingChoice.bulkOf(null), isNull);
    });
  });

  group('SellingChoice.isAvailableFor', () {
    test('offers weight and unit under kilograms', () {
      expect(SellingChoice.weight.isAvailableFor(BaseUnit.gram), isTrue);
      expect(SellingChoice.unit.isAvailableFor(BaseUnit.gram), isTrue);
      expect(SellingChoice.volume.isAvailableFor(BaseUnit.gram), isFalse);
    });

    test('offers volume and unit under litres', () {
      expect(SellingChoice.volume.isAvailableFor(BaseUnit.milliliter), isTrue);
      expect(SellingChoice.unit.isAvailableFor(BaseUnit.milliliter), isTrue);
      expect(SellingChoice.weight.isAvailableFor(BaseUnit.milliliter), isFalse);
    });

    test('offers only unit under a type counted by unit', () {
      expect(SellingChoice.unit.isAvailableFor(BaseUnit.unit), isTrue);
      expect(SellingChoice.weight.isAvailableFor(BaseUnit.unit), isFalse);
      expect(SellingChoice.volume.isAvailableFor(BaseUnit.unit), isFalse);
    });

    test('offers only unit while no type is chosen', () {
      expect(SellingChoice.unit.isAvailableFor(null), isTrue);
      expect(SellingChoice.weight.isAvailableFor(null), isFalse);
      expect(SellingChoice.volume.isAvailableFor(null), isFalse);
    });
  });

  group('SellingChoice.looseNameOf', () {
    test('names the loose product after the grandeza of its type', () {
      expect(SellingChoice.looseNameOf(BaseUnit.gram), 'Peso');
      expect(SellingChoice.looseNameOf(BaseUnit.milliliter), 'Volume');
    });

    test('falls back to Unidade, never to Peso', () {
      expect(SellingChoice.looseNameOf(BaseUnit.unit), 'Unidade');
      expect(SellingChoice.looseNameOf(null), 'Unidade');
    });
  });

  group('SellingChoice.of', () {
    test('is always unit when the saved mode is by_piece', () {
      for (final baseUnit in [...BaseUnit.values, null]) {
        expect(
          SellingChoice.of(SellingMode.byPiece, baseUnit),
          SellingChoice.unit,
          reason: 'by_piece under $baseUnit',
        );
      }
    });

    test('names the saved by_weight after the grandeza of the type', () {
      expect(
        SellingChoice.of(SellingMode.byWeight, BaseUnit.gram),
        SellingChoice.weight,
      );
      expect(
        SellingChoice.of(SellingMode.byWeight, BaseUnit.milliliter),
        SellingChoice.volume,
      );
    });

    test('normalizes a by_weight with no bulk down to unit', () {
      expect(
        SellingChoice.of(SellingMode.byWeight, BaseUnit.unit),
        SellingChoice.unit,
      );
      expect(SellingChoice.of(SellingMode.byWeight, null), SellingChoice.unit);
    });
  });
}
