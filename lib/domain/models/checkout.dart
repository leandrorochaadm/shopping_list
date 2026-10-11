import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'barcode.dart';
import 'money.dart';
import 'product_option.dart';
import 'purchase_item.dart';
import 'scan_resolution.dart';

/// What one read does in checkout mode. The screen only switches over it.
sealed class CheckoutStep {
  const CheckoutStep();
}

/// A new line, priced from the last purchase.
final class ItemAdded extends CheckoutStep {
  const ItemAdded({required this.item});

  final PurchaseItem item;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ItemAdded && other.item == item);

  @override
  int get hashCode => item.hashCode;

  @override
  String toString() => 'ItemAdded($item)';
}

/// The existing line, same `id`, one more package and the price rescaled.
final class QuantityIncreased extends CheckoutStep {
  const QuantityIncreased({required this.item});

  final PurchaseItem item;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuantityIncreased && other.item == item);

  @override
  int get hashCode => item.hashCode;

  @override
  String toString() => 'QuantityIncreased($item)';
}

/// The leaf was never bought, so there is no price to start from. It carries
/// no [PurchaseItem], which requires a price.
final class NeedsPrice extends CheckoutStep {
  const NeedsPrice({required this.option, required this.quantity});

  final ProductOption option;
  final int quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NeedsPrice &&
          other.option == option &&
          other.quantity == quantity);

  @override
  int get hashCode => Object.hash(option, quantity);

  @override
  String toString() => 'NeedsPrice(${option.label}, $quantity)';
}

final class CheckoutNoMatch extends CheckoutStep {
  const CheckoutNoMatch({required this.code});

  final Barcode code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckoutNoMatch && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'CheckoutNoMatch($code)';
}

final class CheckoutScaleUnlinked extends CheckoutStep {
  const CheckoutScaleUnlinked({
    required this.itemCode,
    required this.weightInGrams,
  });

  final String itemCode;
  final int weightInGrams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckoutScaleUnlinked &&
          other.itemCode == itemCode &&
          other.weightInGrams == weightInGrams);

  @override
  int get hashCode => Object.hash(itemCode, weightInGrams);

  @override
  String toString() => 'CheckoutScaleUnlinked($itemCode, $weightInGrams g)';
}

final class CheckoutScaleInManyStores extends CheckoutStep {
  const CheckoutScaleInManyStores({
    required this.itemCode,
    required this.storeIds,
  });

  final String itemCode;
  final IList<String> storeIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckoutScaleInManyStores &&
          other.itemCode == itemCode &&
          other.storeIds == storeIds);

  @override
  int get hashCode => Object.hash(itemCode, storeIds);

  @override
  String toString() => 'CheckoutScaleInManyStores($itemCode, $storeIds)';
}

final class CheckoutUnknownLabel extends CheckoutStep {
  const CheckoutUnknownLabel();

  @override
  bool operator ==(Object other) => other is CheckoutUnknownLabel;

  @override
  int get hashCode => (CheckoutUnknownLabel).hashCode;

  @override
  String toString() => 'CheckoutUnknownLabel()';
}

final class CheckoutInvalid extends CheckoutStep {
  const CheckoutInvalid();

  @override
  bool operator ==(Object other) => other is CheckoutInvalid;

  @override
  int get hashCode => (CheckoutInvalid).hashCode;

  @override
  String toString() => 'CheckoutInvalid()';
}

/// The rule of checkout mode: each read becomes a step of the cart. Pure — it
/// does not touch the draft; whoever saves the line is the screen.
CheckoutStep checkoutScan(
  ScanResolution resolution,
  IList<PurchaseItem> items,
) => switch (resolution) {
  PackagingMatch(:final option) => _packaging(option, items),
  ScaleMatch(:final option, :final quantity) =>
    quantity == null
        ? const CheckoutUnknownLabel()
        // A scale label is ALWAYS a new line, never a sum.
        : _priced(option, quantity),
  ScaleInManyStores(:final itemCode, :final storeIds) =>
    CheckoutScaleInManyStores(itemCode: itemCode, storeIds: storeIds),
  ScaleUnlinked(:final itemCode, :final weightInGrams) => CheckoutScaleUnlinked(
    itemCode: itemCode,
    weightInGrams: weightInGrams,
  ),
  UnknownLabel() => const CheckoutUnknownLabel(),
  NoMatch(:final code) => CheckoutNoMatch(code: code),
  InvalidScan() => const CheckoutInvalid(),
};

CheckoutStep _packaging(ProductOption option, IList<PurchaseItem> items) {
  // The packaging is the LEAF: a can and a pack of the same registration are
  // different lines. A packaged leaf is always sold by piece, so +1 is one
  // package.
  final existing = items
      .where((item) => item.option.id == option.id)
      .firstOrNull;
  if (existing != null) {
    final next = existing.quantity + 1;
    return QuantityIncreased(
      item: existing.copyWith(
        quantity: next,
        paid: _scaled(existing.paid, from: existing.quantity, to: next),
      ),
    );
  }
  return _priced(option, 1);
}

CheckoutStep _priced(ProductOption option, int quantity) {
  final reference = option.priceReference;
  if (reference == null) return NeedsPrice(option: option, quantity: quantity);
  return ItemAdded(
    item: PurchaseItem(
      option: option,
      quantity: quantity,
      paid: reference.estimateFor(option.toBaseUnit(quantity)),
      priceOrigin: PriceOrigin.lastPurchase,
    ),
  );
}

// Same formula as `PriceReference.estimateFor`:
// floor(v + 0.5) == (2·numerator + denominator) ~/ (2·denominator).
Money _scaled(Money paid, {required int from, required int to}) =>
    Money((paid.cents * to * 2 + from) ~/ (from * 2));
