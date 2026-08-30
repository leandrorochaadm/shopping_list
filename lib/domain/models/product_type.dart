import 'base_unit.dart';
import 'catalog_entry.dart';

/// **The level that sums.** Every report adds up here, which is why the base
/// unit lives on it: "Leite" is measured in litres, and every packaging below
/// it is converted into litres before anything is added.
///
/// It is also why the name is unique across the whole catalog and not per
/// category: two "Leite" types would split that sum in half with nothing on
/// screen explaining the difference.
final class ProductType implements CatalogEntry {
  factory ProductType({
    String? id,
    required String name,
    required String categoryId,
    required BaseUnit baseUnit,
    bool active = true,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const BlankName();
    return ProductType._(
      id: id,
      name: trimmed,
      categoryId: categoryId,
      baseUnit: baseUnit,
      active: active,
    );
  }

  const ProductType._({
    this.id,
    required this.name,
    required this.categoryId,
    required this.baseUnit,
    required this.active,
  });

  factory ProductType.fromJson(Map<String, dynamic> json) => ProductType(
    id: json['id'] as String?,
    name: json['name'] as String,
    categoryId: json['category_id'] as String,
    baseUnit: BaseUnit.fromJson(json['base_unit'] as String),
    active: json['active'] as bool? ?? true,
  );

  @override
  final String? id;

  @override
  final String name;

  /// A key, never a copied name: renaming a category has to hold for the
  /// whole history.
  final String categoryId;

  final BaseUnit baseUnit;

  @override
  final bool active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'category_id': categoryId,
    'base_unit': baseUnit.toJson(),
    'active': active,
  };

  /// Which measures the packaging rows may offer. Asking the type instead of
  /// rebuilding the list on screen is what stops a soft drink from being
  /// typed in grams.
  List<MeasureUnit> get measures => baseUnit.measures;

  ProductType deactivated() => copyWith(active: false);

  ProductType reactivated() => copyWith(active: true);

  ProductType copyWith({
    String? id,
    String? name,
    String? categoryId,
    BaseUnit? baseUnit,
    bool? active,
  }) => ProductType(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    baseUnit: baseUnit ?? this.baseUnit,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductType &&
          other.id == id &&
          other.name == name &&
          other.categoryId == categoryId &&
          other.baseUnit == baseUnit &&
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, categoryId, baseUnit, active);

  @override
  String toString() =>
      'ProductType($name, ${baseUnit.name}, active: $active)';
}
