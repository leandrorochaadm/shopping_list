import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';

void main() {
  group('Packaging', () {
    test('multiplies the pieces by the size of each one', () {
      final packaging = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        pieceSizeUnit: MeasureUnit.milliliter,
      );

      expect(packaging.totalContent, 2100);
      expect(packaging.baseUnit, BaseUnit.liter);
    });

    test('converts what was typed before storing anything', () {
      // The screen calls this: '6' and '0,35' in litres is 2100 ml.
      final packaging = Packaging.typed(
        pieceCount: '6',
        pieceSize: '0,35',
        pieceSizeUnit: MeasureUnit.liter,
      );

      expect(packaging.pieceSize, 350);
      expect(packaging.totalContent, 2100);
    });

    test('recognises the same content written two different ways', () {
      // The acceptance criterion of H2, and the reason everything here is an
      // integer: 1 × 0,35 L and 1 × 350 ml are the SAME packaging.
      final asLiters = Packaging.typed(
        pieceCount: '1',
        pieceSize: '0,35',
        pieceSizeUnit: MeasureUnit.liter,
      );
      final asMilliliters = Packaging.typed(
        pieceCount: '1',
        pieceSize: '350',
        pieceSizeUnit: MeasureUnit.milliliter,
      );

      expect(asLiters.hasSameContentAs(asMilliliters), isTrue);
      // Same content, different way of writing it: NOT the same object.
      expect(asLiters, isNot(asMilliliters));
    });

    test('recognises 2 × 500 g and 1 × 1 kg as the same amount', () {
      final twoHalves = Packaging.typed(
        pieceCount: '2',
        pieceSize: '500',
        pieceSizeUnit: MeasureUnit.gram,
      );
      final whole = Packaging.typed(
        pieceCount: '1',
        pieceSize: '1',
        pieceSizeUnit: MeasureUnit.kilogram,
      );

      expect(twoHalves.hasSameContentAs(whole), isTrue);
    });

    test('keeps weight and volume apart even at the same number', () {
      final grams = Packaging(
        pieceCount: 1,
        pieceSize: 350,
        pieceSizeUnit: MeasureUnit.gram,
      );
      final milliliters = Packaging(
        pieceCount: 1,
        pieceSize: 350,
        pieceSizeUnit: MeasureUnit.milliliter,
      );

      expect(grams.hasSameContentAs(milliliters), isFalse);
    });

    test('counts pieces for a type measured by unit', () {
      final eggs = Packaging.typed(
        pieceCount: '2',
        pieceSize: '12',
        pieceSizeUnit: MeasureUnit.unit,
      );

      expect(eggs.totalContent, 24);
      expect(eggs.baseUnit, BaseUnit.unit);
    });

    test('refuses a package with no pieces, which is the boundary', () {
      expect(
        () => Packaging(
          pieceCount: 0,
          pieceSize: 350,
          pieceSizeUnit: MeasureUnit.milliliter,
        ),
        throwsA(isA<InvalidPieceCount>()),
      );
      expect(
        () => Packaging(
          pieceCount: 1,
          pieceSize: 0,
          pieceSizeUnit: MeasureUnit.milliliter,
        ),
        throwsA(isA<InvalidAmount>()),
      );
      // And one of each is accepted — the other side of the same boundary.
      expect(
        Packaging(
          pieceCount: 1,
          pieceSize: 1,
          pieceSizeUnit: MeasureUnit.milliliter,
        ).totalContent,
        1,
      );
    });

    test('drops the "1 ×" of a single piece, which is the shelf name', () {
      // The wireframe of screen 4 names it "350ml", not "1 × 350 ml": that is
      // what gets searched for when a purchase is registered.
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '350',
          pieceSizeUnit: MeasureUnit.milliliter,
        ).label,
        '350 ml',
      );
      expect(
        Packaging.typed(
          pieceCount: '12',
          pieceSize: '350',
          pieceSizeUnit: MeasureUnit.milliliter,
        ).label,
        '12 × 350 ml',
      );
    });

    test('writes itself back the way it was typed', () {
      expect(
        Packaging.typed(
          pieceCount: '6',
          pieceSize: '350',
          pieceSizeUnit: MeasureUnit.milliliter,
        ).label,
        '6 × 350 ml',
      );
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '0,35',
          pieceSizeUnit: MeasureUnit.liter,
        ).label,
        '0,35 L',
      );
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '2',
          pieceSizeUnit: MeasureUnit.liter,
        ).label,
        '2 L',
      );
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '1,500',
          pieceSizeUnit: MeasureUnit.kilogram,
        ).label,
        '1,5 kg',
      );
    });

    test('survives the round trip through JSON', () {
      final packaging = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        pieceSizeUnit: MeasureUnit.milliliter,
      );

      expect(Packaging.fromJson(packaging.toJson()), packaging);
      expect(packaging.toJson()['total_content'], 2100);
    });

    test('compares by every field it has', () {
      final one = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        pieceSizeUnit: MeasureUnit.milliliter,
      );

      expect(one, one.copyWith());
      expect(one.hashCode, one.copyWith().hashCode);
      expect(one, isNot(one.copyWith(pieceCount: 12)));
    });

    test('names itself in a log line', () {
      expect(
        Packaging(
          pieceCount: 6,
          pieceSize: 350,
          pieceSizeUnit: MeasureUnit.milliliter,
        ).toString(),
        'Packaging(6 × 350 ml = 2100)',
      );
      expect(
        const InvalidPieceCount().toString(),
        contains('pelo menos uma peça'),
      );
    });
  });
}
