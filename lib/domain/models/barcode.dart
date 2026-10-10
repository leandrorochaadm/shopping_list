/// The barcode printed on a PACKAGE, validated and normalized to GTIN-14.
///
/// EAN-8, UPC-A, EAN-13 and GTIN-14 are the same family: padding with zeros
/// on the left turns each one into the GTIN-14, so the stored form never
/// depends on which of them the scanner read.
final class Barcode {
  const Barcode._(this.code);

  /// What was typed or scanned. Throws [InvalidBarcode] for a wrong format or
  /// check digit, and [InStoreBarcode] for a scale code (see the order below:
  /// a misread code is "invalid", never "from a scale").
  factory Barcode.typed(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty ||
        !_onlyDigits.hasMatch(digits) ||
        !acceptedLengths.contains(digits.length)) {
      throw const InvalidBarcode();
    }
    if (!hasValidCheckDigit(digits)) throw const InvalidBarcode();

    final gtin = digits.padLeft(gtinLength, '0');
    final ean13 = gtin.substring(gtinLength - ean13Length);
    if (ean13.startsWith(inStorePrefix) ||
        ean13.startsWith('0$inStorePrefix')) {
      throw const InStoreBarcode();
    }
    return Barcode._(gtin);
  }

  /// The `code` column of `product_barcode` (a row with a null `store_id`).
  /// The database is trusted; the padding only keeps `==` independent of who
  /// wrote the row.
  factory Barcode.fromJson(String code) =>
      Barcode._(code.padLeft(gtinLength, '0'));

  static const acceptedLengths = {8, 12, 13, 14};
  static const gtinLength = 14;
  static const ean13Length = 13;
  static const ean8Length = 8;
  static const inStorePrefix = '2';

  static final _onlyDigits = RegExp(r'^\d+$');

  /// Always the GTIN-14: 14 digits, zeros on the left.
  final String code;

  String toJson() => code;

  /// The number the screen shows. It is NOT the stored one — the stored one
  /// is always [code].
  String get label {
    if (code.startsWith('0' * (gtinLength - ean8Length))) {
      return code.substring(gtinLength - ean8Length);
    }
    if (code.startsWith('0')) return code.substring(gtinLength - ean13Length);
    // A GTIN-14 with a case indicator: cutting the first digit would show a
    // number that does not exist on the package.
    return code;
  }

  /// The first code that shows up for the second time, or null.
  static Barcode? findDuplicateIn(Iterable<Barcode> codes) {
    final seen = <Barcode>{};
    for (final barcode in codes) {
      if (!seen.add(barcode)) return barcode;
    }
    return null;
  }

  /// [digits] is digits only, with 2 or more of them. Mod 10, weights 3/1
  /// from the right, not counting the check digit itself.
  static bool hasValidCheckDigit(String digits) {
    var sum = 0;
    var weight = 3;
    for (var i = digits.length - 2; i >= 0; i--) {
      sum += (digits.codeUnitAt(i) - 0x30) * weight;
      weight = 4 - weight; // 3, 1, 3, 1...
    }
    return (10 - sum % 10) % 10 == digits.codeUnitAt(digits.length - 1) - 0x30;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Barcode && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Barcode($code)';
}

/// The typed code is not a barcode. pt-BR: it is read on screen.
final class InvalidBarcode implements Exception {
  const InvalidBarcode();

  String get message => 'Código de barras inválido.';

  @override
  String toString() => 'InvalidBarcode: $message';
}

/// The code belongs to a store scale, not to a package. pt-BR: read on screen.
final class InStoreBarcode implements Exception {
  const InStoreBarcode();

  String get message => 'Esse é um código de balança.';

  @override
  String toString() => 'InStoreBarcode: $message';
}
