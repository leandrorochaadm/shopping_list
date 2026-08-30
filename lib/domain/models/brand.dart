import 'catalog_entry.dart';

/// A brand, and it is OPTIONAL: ground beef has none, and "Sem marca" is a
/// real answer rather than missing data (decision B2 — the screen offers it,
/// the database stores nothing).
final class Brand implements CatalogEntry {
  factory Brand({String? id, required String name, bool active = true}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const BlankName();
    return Brand._(id: id, name: trimmed, active: active);
  }

  const Brand._({this.id, required this.name, required this.active});

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: json['id'] as String?,
    name: json['name'] as String,
    active: json['active'] as bool? ?? true,
  );

  @override
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

  Brand deactivated() => copyWith(active: false);

  Brand reactivated() => copyWith(active: true);

  Brand copyWith({String? id, String? name, bool? active}) => Brand(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Brand &&
          other.id == id &&
          other.name == name &&
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, active);

  @override
  String toString() => 'Brand($name, active: $active)';
}
