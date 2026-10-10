import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';

void main() {
  group('typed', () {
    test('accepts a valid EAN-13', () {
      expect(Barcode.typed('7894900011517').code, '07894900011517');
    });

    test('refuses a wrong check digit', () {
      expect(
        () => Barcode.typed('7894900011518'),
        throwsA(isA<InvalidBarcode>()),
      );
    });

    test('refuses letters and an empty text', () {
      for (final raw in ['789490001151A', '', '   ']) {
        expect(() => Barcode.typed(raw), throwsA(isA<InvalidBarcode>()));
      }
    });

    test('refuses punctuation', () {
      for (final raw in ['789490001151-', '7894900.11517']) {
        expect(() => Barcode.typed(raw), throwsA(isA<InvalidBarcode>()));
      }
    });

    test('refuses lengths 7, 9, 11 and 15', () {
      for (final raw in [
        '1234567',
        '123456789',
        '12345678901',
        '123456789012345',
      ]) {
        expect(() => Barcode.typed(raw), throwsA(isA<InvalidBarcode>()));
      }
    });

    test('accepts lengths 8 and 14', () {
      expect(() => Barcode.typed('96385074'), returnsNormally);
      expect(() => Barcode.typed('17894900011514'), returnsNormally);
    });

    test('strips spaces, inside and around', () {
      final expected = Barcode.typed('7894900011517');
      expect(Barcode.typed(' 7894900011517 '), expected);
      expect(Barcode.typed('7 894900 011517'), expected);
    });

    test('normalizes UPC-A and EAN-13 to the same GTIN-14', () {
      final upc = Barcode.typed('012345678905');
      final ean = Barcode.typed('0012345678905');
      expect(upc, ean);
      expect(upc.hashCode, ean.hashCode);
    });

    test('throws InStoreBarcode for an EAN-13 starting with 2', () {
      expect(
        () => Barcode.typed('2822521001605'),
        throwsA(isA<InStoreBarcode>()),
      );
    });

    test('throws InStoreBarcode for a UPC-A starting with 2', () {
      expect(
        () => Barcode.typed('212345678909'),
        throwsA(isA<InStoreBarcode>()),
      );
    });

    test('does not treat 0789… as in-store', () {
      expect(() => Barcode.typed('07894900011517'), returnsNormally);
    });

    test('checks the digit before the in-store prefix', () {
      expect(
        () => Barcode.typed('2822521001606'),
        throwsA(isA<InvalidBarcode>()),
      );
    });
  });

  group('label', () {
    test('shows the 13 digits of an EAN-13', () {
      expect(Barcode.typed('7894900011517').label, '7894900011517');
    });

    test('shows the 13 digits of a UPC-A', () {
      expect(Barcode.typed('012345678905').label, '0012345678905');
    });

    test('shows the 8 digits of an EAN-8', () {
      expect(Barcode.typed('96385074').label, '96385074');
    });

    test('shows the 14 digits of a GTIN-14', () {
      expect(Barcode.typed('17894900011514').label, '17894900011514');
    });
  });

  group('fromJson', () {
    test('reads the stored GTIN-14', () {
      expect(
        Barcode.fromJson('07894900011517'),
        Barcode.typed('7894900011517'),
      );
    });

    test('toJson gives the GTIN-14', () {
      expect(Barcode.typed('7894900011517').toJson(), '07894900011517');
    });

    test('pads a 13-digit code with a zero', () {
      expect(Barcode.fromJson('7894900011517').code, '07894900011517');
    });
  });

  group('findDuplicateIn', () {
    final a = Barcode.typed('7894900011517');
    final b = Barcode.typed('96385074');

    test('finds the repeated one', () {
      expect(Barcode.findDuplicateIn([a, b, a]), a);
    });

    test('finds the repeated one written in different forms', () {
      final upc = Barcode.typed('012345678905');
      final ean = Barcode.typed('0012345678905');
      expect(Barcode.findDuplicateIn([upc, b, ean]), upc);
    });

    test('is null without a repetition', () {
      expect(Barcode.findDuplicateIn([a, b]), isNull);
    });

    test('is null for an empty list', () {
      expect(Barcode.findDuplicateIn(const []), isNull);
    });
  });

  group('hasValidCheckDigit', () {
    test('is true for right digits', () {
      expect(Barcode.hasValidCheckDigit('96385074'), isTrue);
      expect(Barcode.hasValidCheckDigit('2822521001605'), isTrue);
    });

    test('is false for a wrong digit', () {
      expect(Barcode.hasValidCheckDigit('7894900011518'), isFalse);
    });
  });

  group('equality', () {
    test('the same code is equal and has the same hashCode', () {
      final a = Barcode.typed('7894900011517');
      final b = Barcode.fromJson('07894900011517');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different code is not equal', () {
      expect(
        Barcode.typed('7894900011517') == Barcode.typed('96385074'),
        isFalse,
      );
    });
  });

  test('names itself in a log line', () {
    expect(
      Barcode.typed('7894900011517').toString(),
      contains('07894900011517'),
    );
    expect(const InvalidBarcode().toString(), contains('inválido'));
    expect(const InStoreBarcode().toString(), contains('balança'));
  });
}
