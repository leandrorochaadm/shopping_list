import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'category.dart';
import 'name_normalization.dart';
import 'product_type.dart';

/// One category name and the types under it, in the order the `#1a` panel
/// draws them. The name and not the [Category] because a type with no
/// category still has to appear, under 'Sem categoria'.
final class ProductTypeGroup {
  const ProductTypeGroup({required this.name, required this.types});

  /// pt-BR: read on screen, and it may be the literal 'Sem categoria'.
  final String name;
  final IList<ProductType> types;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductTypeGroup &&
          other.name == name &&
          other.types == types;

  @override
  int get hashCode => Object.hash(name, types);
}

/// The types grouped by category, alphabetically by normalized name — the
/// same organization the list itself uses, so the eye does not have to
/// relearn it between screen 1 and the `#1a` panel.
IList<ProductTypeGroup> groupTypesByCategory(
  IList<ProductType> types,
  IList<Category> categories,
) {
  final byId = {for (final category in categories) category.id: category};
  final groups = <String, List<ProductType>>{};
  for (final type in types) {
    final name = byId[type.categoryId]?.name ?? 'Sem categoria';
    (groups[name] ??= []).add(type);
  }

  final names = groups.keys.toList()
    ..sort((a, b) => normalizeName(a).compareTo(normalizeName(b)));
  return [
    for (final name in names)
      ProductTypeGroup(name: name, types: groups[name]!.lock),
  ].lock;
}
