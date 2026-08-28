import 'catalog_entry.dart';

/// "Limpeza", "Carnes" — the top of the five levels, and the grouping the
/// shopping list is read by in the aisle.
final class Category implements CatalogEntry {
  factory Category({String? id, required String name, bool active = true}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const BlankName();
    return Category._(id: id, name: trimmed, active: active);
  }

  const Category._({this.id, required this.name, required this.active});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String?,
    name: json['name'] as String,
    active: json['active'] as bool? ?? true,
  );

  /// Null before the row exists — the database generates it.
  final String? id;

  @override
  final String name;

  @override
  final bool active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'active': active,
  };

  /// The transition of decision 19: nothing is deleted, and reactivating is
  /// what the duplicate guard offers when the name is already taken.
  Category deactivated() => copyWith(active: false);

  Category reactivated() => copyWith(active: true);

  Category copyWith({String? id, String? name, bool? active}) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == id &&
          other.name == name &&
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, active);

  @override
  String toString() => 'Category($name, active: $active)';
}
