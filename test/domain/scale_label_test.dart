import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/scale_label.dart';

void main() {
  const expected = ScaleLabel(itemCode: '2822521', weightInGrams: 160);

  group('parse', () {
    test('reads the date label QR', () {
      expect(ScaleLabel.parse('02822521001605261107'), expected);
    });

    test('reads the plain EAN-13 of the same label', () {
      expect(ScaleLabel.parse('2822521001605'), expected);
    });

    test('strips spaces', () {
      expect(ScaleLabel.parse(' 2822521 00160 5 '), expected);
    });

    test('returns null for a wrong check digit', () {
      expect(ScaleLabel.parse('2822521001606'), isNull);
      expect(ScaleLabel.parse('02822521001606261107'), isNull);
    });

    test('returns null when the prefix is not 2', () {
      expect(ScaleLabel.parse('7894900011517'), isNull);
      expect(ScaleLabel.parse('07894900011517261107'), isNull);
    });

    test('returns null when the QR does not start with 0', () {
      expect(ScaleLabel.parse('12822521001605261107'), isNull);
    });

    test('returns null for lengths outside the format', () {
      expect(ScaleLabel.parse('282252100160'), isNull);
      expect(ScaleLabel.parse('02822521001605'), isNull);
      expect(ScaleLabel.parse('028225210016052611070'), isNull);
    });

    test('returns null for letters and punctuation', () {
      expect(ScaleLabel.parse('282252100160A'), isNull);
      expect(ScaleLabel.parse('282252100160-'), isNull);
    });

    test('returns null for a zero weight', () {
      expect(ScaleLabel.parse('2822521000004'), isNull);
    });

    test('reads the smallest weight', () {
      expect(ScaleLabel.parse('2822521000011')?.weightInGrams, 1);
    });
  });

  group('ScaleLabel equality', () {
    test('equal fields are equal', () {
      const other = ScaleLabel(itemCode: '2822521', weightInGrams: 160);
      expect(other, expected);
      expect(other.hashCode, expected.hashCode);
    });

    test('changing itemCode breaks equality', () {
      const other = ScaleLabel(itemCode: '2822522', weightInGrams: 160);
      expect(other == expected, isFalse);
    });

    test('changing weightInGrams breaks equality', () {
      const other = ScaleLabel(itemCode: '2822521', weightInGrams: 161);
      expect(other == expected, isFalse);
    });
  });

  group('ScaleCode', () {
    const code = ScaleCode(storeId: 'store-1', itemCode: '2822521');

    test('equal fields are equal with the same hashCode', () {
      const other = ScaleCode(storeId: 'store-1', itemCode: '2822521');
      expect(other, code);
      expect(other.hashCode, code.hashCode);
    });

    test('changing only storeId breaks equality', () {
      const other = ScaleCode(storeId: 'store-2', itemCode: '2822521');
      expect(other == code, isFalse);
    });

    test('changing only itemCode breaks equality', () {
      const other = ScaleCode(storeId: 'store-1', itemCode: '2822522');
      expect(other == code, isFalse);
    });

    test('round-trips through JSON', () {
      final json = {'store_id': 'store-1', 'code': '2822521'};
      expect(ScaleCode.fromJson(json), code);
      expect(code.toJson(), json);
    });
  });

  test('names itself in a log line', () {
    expect(expected.toString(), allOf(contains('2822521'), contains('160')));
    expect(
      const ScaleCode(storeId: 'store-1', itemCode: '2822521').toString(),
      allOf(contains('store-1'), contains('2822521')),
    );
  });
}
