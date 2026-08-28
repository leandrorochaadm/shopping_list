import 'catalog_entry.dart';

/// Where a purchase was made: supermarket, street market, butcher,
/// greengrocer. The same duplicate guard as every other catalog, including
/// the deactivated ones (decision B3).
final class Store implements CatalogEntry {
  factory Store({String? id, required String name, bool active = true}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const BlankName();
    return Store._(id: id, name: trimmed, active: active);
  }

  const Store._({this.id, required this.name, required this.active});

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: json['id'] as String?,
    name: json['name'] as String,
    active: json['active'] as bool? ?? true,
  );

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

  Store deactivated() => copyWith(active: false);

  Store reactivated() => copyWith(active: true);

  Store copyWith({String? id, String? name, bool? active}) => Store(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Store &&
          other.id == id &&
          other.name == name &&
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, active);

  @override
  String toString() => 'Store($name, active: $active)';
}
