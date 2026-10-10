import 'barcode.dart';

/// What a store scale prints on its label: the item code and the weight.
final class ScaleLabel {
  const ScaleLabel({required this.itemCode, required this.weightInGrams});

  /// `null` means "not the known format".
  ///
  /// Only the format of the 10/10/2026 photo (dates, Irmãos Gonçalves) is
  /// understood. The 20-digit QR, a length other than 13/20, a prefix other
  /// than the in-store one, a wrong check digit and a zero weight give
  /// `null`. An EAN-13 starting with 2 from ANOTHER layout (price in place of
  /// the weight, an item code of another size) with a right check digit is
  /// not distinguishable and is read as if digits 8-12 were grams.
  static ScaleLabel? parse(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;

    final String ean13;
    switch (digits.length) {
      case Barcode.ean13Length:
        ean13 = digits;
      case qrLength when digits.startsWith('0'):
        ean13 = digits.substring(
          Barcode.gtinLength - Barcode.ean13Length,
          Barcode.gtinLength,
        );
      default:
        return null;
    }

    if (!ean13.startsWith(Barcode.inStorePrefix)) return null;
    if (!Barcode.hasValidCheckDigit(ean13)) return null;

    final weight = int.parse(
      ean13.substring(itemCodeLength, itemCodeLength + weightDigits),
    );
    if (weight == 0) return null;

    return ScaleLabel(
      itemCode: ean13.substring(0, itemCodeLength),
      weightInGrams: weight,
    );
  }

  static const itemCodeLength = 7;
  static const weightDigits = 5;
  static const expiryDigits = 6; // AAMMDD
  static const qrLength = Barcode.gtinLength + expiryDigits;

  /// The first 7 digits of the EAN-13, the prefix included.
  final String itemCode;

  /// Digits 8 to 12.
  final int weightInGrams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleLabel &&
          other.itemCode == itemCode &&
          other.weightInGrams == weightInGrams);

  @override
  int get hashCode => Object.hash(itemCode, weightInGrams);

  @override
  String toString() => 'ScaleLabel($itemCode, $weightInGrams g)';
}

/// The code a store gives to a product on its scale.
final class ScaleCode {
  const ScaleCode({required this.storeId, required this.itemCode});

  factory ScaleCode.fromJson(Map<String, dynamic> json) => ScaleCode(
    storeId: json[_storeIdKey] as String,
    itemCode: json[_codeKey] as String,
  );

  static const _storeIdKey = 'store_id';
  static const _codeKey = 'code';

  final String storeId;
  final String itemCode;

  Map<String, dynamic> toJson() => {_storeIdKey: storeId, _codeKey: itemCode};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleCode &&
          other.storeId == storeId &&
          other.itemCode == itemCode);

  @override
  int get hashCode => Object.hash(storeId, itemCode);

  @override
  String toString() => 'ScaleCode($storeId, $itemCode)';
}
