import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';

void main() {
  group('Packaging', () {
    test('multiplies the pieces by the size of each one', () {
      final packaging = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
      );

      expect(packaging.totalContent, 2100);
      expect(packaging.baseUnit, BaseUnit.milliliter);
    });

    test('reads what was typed as a whole number of the base unit', () {
      // The screen calls this: '6' and '350' in millilitres is 2100 ml.
      final packaging = Packaging.typed(
        pieceCount: '6',
        pieceSize: '350',
        baseUnit: BaseUnit.milliliter,
      );

      expect(packaging.pieceSize, 350);
      expect(packaging.totalContent, 2100);
    });

    test('refuses a decimal, because the typed unit is the small one', () {
      expect(
        () => Packaging.typed(
          pieceCount: '1',
          pieceSize: '0,35',
          baseUnit: BaseUnit.milliliter,
        ),
        throwsA(isA<AmountMustBeWhole>()),
      );
    });

    test('recognises 2 × 500 g and 1 × 1000 g as the same amount', () {
      // The acceptance criterion of H2, and the reason everything here is an
      // integer: the comparison happens on the total.
      final twoHalves = Packaging.typed(
        pieceCount: '2',
        pieceSize: '500',
        baseUnit: BaseUnit.gram,
      );
      final whole = Packaging.typed(
        pieceCount: '1',
        pieceSize: '1000',
        baseUnit: BaseUnit.gram,
      );

      expect(twoHalves.hasSameContentAs(whole), isTrue);
      // Same content, different way of writing it: NOT the same object.
      expect(twoHalves, isNot(whole));
    });

    test('keeps weight and volume apart even at the same number', () {
      final grams = Packaging(
        pieceCount: 1,
        pieceSize: 350,
        baseUnit: BaseUnit.gram,
      );
      final milliliters = Packaging(
        pieceCount: 1,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
      );

      expect(grams.hasSameContentAs(milliliters), isFalse);
    });

    test('counts pieces for a type measured by unit', () {
      final eggs = Packaging.typed(
        pieceCount: '2',
        pieceSize: '12',
        baseUnit: BaseUnit.unit,
      );

      expect(eggs.totalContent, 24);
      expect(eggs.baseUnit, BaseUnit.unit);
    });

    test('refuses a package with no pieces, which is the boundary', () {
      expect(
        () => Packaging(
          pieceCount: 0,
          pieceSize: 350,
          baseUnit: BaseUnit.milliliter,
        ),
        throwsA(isA<InvalidPieceCount>()),
      );
      expect(
        () => Packaging(
          pieceCount: 1,
          pieceSize: 0,
          baseUnit: BaseUnit.milliliter,
        ),
        throwsA(isA<InvalidAmount>()),
      );
      // And one of each is accepted — the other side of the same boundary.
      expect(
        Packaging(
          pieceCount: 1,
          pieceSize: 1,
          baseUnit: BaseUnit.milliliter,
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
          baseUnit: BaseUnit.milliliter,
        ).label,
        '350 ml',
      );
      expect(
        Packaging.typed(
          pieceCount: '12',
          pieceSize: '350',
          baseUnit: BaseUnit.milliliter,
        ).label,
        '12 × 350 ml',
      );
    });

    test('reads the large unit as soon as the amount reaches it', () {
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '2000',
          baseUnit: BaseUnit.milliliter,
        ).label,
        '2 L',
      );
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '1500',
          baseUnit: BaseUnit.gram,
        ).label,
        '1,5 kg',
      );
      // The composed form crosses the threshold too — '12 × 1 L', never
      // '12 × 1000 ml'.
      expect(
        Packaging.typed(
          pieceCount: '12',
          pieceSize: '1000',
          baseUnit: BaseUnit.milliliter,
        ).label,
        '12 × 1 L',
      );
      // The new magnitude: 30 m of foil, stored in centimetres.
      expect(
        Packaging.typed(
          pieceCount: '1',
          pieceSize: '3000',
          baseUnit: BaseUnit.centimeter,
        ).label,
        '30 m',
      );
    });

    test('survives the round trip through JSON', () {
      final packaging = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
      );

      expect(Packaging.fromJson(packaging.toJson()), packaging);
      expect(packaging.toJson()['total_content'], 2100);
    });

    test('compares by every field it has', () {
      final one = Packaging(
        pieceCount: 6,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
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
          baseUnit: BaseUnit.milliliter,
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
