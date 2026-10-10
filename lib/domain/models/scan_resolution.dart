import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'barcode.dart';
import 'base_unit.dart';
import 'product_option.dart';
import 'scale_label.dart';

/// What a read (raw camera text or typed digits) means. The screen only
/// switches over it, exhaustively.
sealed class ScanResolution {
  const ScanResolution();
}

/// The code belongs to a packaging.
final class PackagingMatch extends ScanResolution {
  const PackagingMatch({required this.option});

  final ProductOption option;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PackagingMatch && other.option == option);

  @override
  int get hashCode => option.hashCode;

  @override
  String toString() => 'PackagingMatch($option)';
}

/// A store scale label linked to a product.
final class ScaleMatch extends ScanResolution {
  const ScaleMatch({
    required this.option,
    required this.storeId,
    required this.quantity,
  });

  final ProductOption option;
  final String storeId;

  /// The weight in grams, only for a weight-sold leaf of a gram type.
  final int? quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleMatch &&
          other.option == option &&
          other.storeId == storeId &&
          other.quantity == quantity);

  @override
  int get hashCode => Object.hash(option, storeId, quantity);

  @override
  String toString() => 'ScaleMatch($option, $storeId, $quantity)';
}

/// The item code is linked in more than one store and none was chosen.
final class ScaleInManyStores extends ScanResolution {
  const ScaleInManyStores({required this.itemCode, required this.storeIds});

  final String itemCode;

  /// No repeats, ascending.
  final IList<String> storeIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleInManyStores &&
          other.itemCode == itemCode &&
          other.storeIds == storeIds);

  @override
  int get hashCode => Object.hash(itemCode, storeIds);

  @override
  String toString() => 'ScaleInManyStores($itemCode, $storeIds)';
}

/// A valid scale label with no product linked.
final class ScaleUnlinked extends ScanResolution {
  const ScaleUnlinked({required this.itemCode, required this.weightInGrams});

  final String itemCode;
  final int weightInGrams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleUnlinked &&
          other.itemCode == itemCode &&
          other.weightInGrams == weightInGrams);

  @override
  int get hashCode => Object.hash(itemCode, weightInGrams);

  @override
  String toString() => 'ScaleUnlinked($itemCode, $weightInGrams g)';
}

/// An in-store code in a format that is not understood.
final class UnknownLabel extends ScanResolution {
  const UnknownLabel();

  @override
  bool operator ==(Object other) => other is UnknownLabel;

  @override
  int get hashCode => (UnknownLabel).hashCode;

  @override
  String toString() => 'UnknownLabel()';
}

/// A valid packaging code that no product has.
final class NoMatch extends ScanResolution {
  const NoMatch({required this.code});

  final Barcode code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NoMatch && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'NoMatch($code)';
}

/// Not a barcode at all.
final class InvalidScan extends ScanResolution {
  const InvalidScan();

  @override
  bool operator ==(Object other) => other is InvalidScan;

  @override
  int get hashCode => (InvalidScan).hashCode;

  @override
  String toString() => 'InvalidScan()';
}

/// The whole rule of a read. The scale label is tried BEFORE the plain barcode,
/// because both start with the in-store prefix.
///
/// With [storeId] the scale codes are searched in that store only; without it,
/// in every store, and a code linked in more than one is [ScaleInManyStores].
ScanResolution resolveScan(
  String raw,
  IList<ProductOption> options, {
  String? storeId,
}) {
  final label = ScaleLabel.parse(raw);
  if (label != null) return _resolveScale(label, options, storeId);

  try {
    final code = Barcode.typed(raw);
    final option = findOptionByBarcode(options, code);
    return option == null
        ? NoMatch(code: code)
        : PackagingMatch(option: option);
  } on InStoreBarcode {
    return const UnknownLabel();
  } on InvalidBarcode {
    return const InvalidScan();
  }
}

ScanResolution _resolveScale(
  ScaleLabel label,
  IList<ProductOption> options,
  String? storeId,
) {
  final matches = findOptionsByScaleCode(
    options,
    label.itemCode,
    storeId: storeId,
  );
  if (matches.isEmpty) {
    return ScaleUnlinked(
      itemCode: label.itemCode,
      weightInGrams: label.weightInGrams,
    );
  }

  final stores = {
    for (final option in matches)
      for (final code in option.product.scaleCodes)
        if (code.itemCode == label.itemCode &&
            (storeId == null || code.storeId == storeId))
          code.storeId,
  }.toList()..sort();
  if (stores.length > 1) {
    return ScaleInManyStores(itemCode: label.itemCode, storeIds: stores.lock);
  }

  final option = matches.first;
  return ScaleMatch(
    option: option,
    storeId: stores.single,
    quantity: option.isSoldByWeight && option.baseUnit == BaseUnit.gram
        ? label.weightInGrams
        : null,
  );
}
