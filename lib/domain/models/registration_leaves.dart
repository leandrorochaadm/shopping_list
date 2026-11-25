import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'packaging.dart';
import 'product.dart';
import 'product_registration.dart';
import 'scale_label.dart';

/// The first active loose leaf (no packaging) of [existing], or null.
/// A deactivated loose leaf does not count. The only place with this filter.
Product? activeLooseOf(IList<Product> existing) {
  for (final leaf in existing) {
    if (leaf.isLoose && leaf.active) return leaf;
  }
  return null;
}

/// The rule of what one save may create in a registration: at least one leaf,
/// scale codes only with the loose leaf, and at most one active loose leaf.
///
/// Throws [MissingPackaging], [UnexpectedScaleCode] or [LooseAlreadyExists],
/// in this order.
void checkNewLeaves({
  required IList<Packaging> packagings,
  required bool loose,
  required IList<ScaleCode> scaleCodes,
  IList<Product> existing = const IList.empty(),
}) {
  if (packagings.isEmpty && !loose) throw const MissingPackaging();
  if (scaleCodes.isNotEmpty && !loose) throw const UnexpectedScaleCode();
  if (loose && activeLooseOf(existing) != null) throw const LooseAlreadyExists();
}

/// The registration already has an active loose leaf.
final class LooseAlreadyExists implements Exception {
  const LooseAlreadyExists();

  String get message => 'Esse produto já tem granel.';

  @override
  String toString() => 'LooseAlreadyExists: $message';
}
