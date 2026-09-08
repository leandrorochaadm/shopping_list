import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'product_type.dart';

/// **The rules of H10** — the ones that keep the maintenance screen from
/// quietly ruining the history it exists to protect. Pure Dart, no clock, no
/// I/O.

/// Moving a product registration to another type is only offered BETWEEN
/// TYPES OF THE SAME BASE UNIT (requirement 16): moving a product measured in
/// litres under a type measured in kilos would make that type's total add
/// volume to weight — silently, and with no way back.
///
/// The screen does not even list the incompatible ones; this is what it asks,
/// and it is also the net underneath for whoever calls the ViewModel directly.
IList<ProductType> typesCompatibleWith(
  IList<ProductType> types,
  BaseUnit baseUnit, {
  String? excludingId,
}) => types
    .where(
      (type) =>
          type.active && type.baseUnit == baseUnit && type.id != excludingId,
    )
    .toIList();

/// Changing a TYPE's base unit would convert its whole history between
/// magnitudes, and it is what the criterion asks to be offered when "a medida
/// não bate". It is allowed only while the type has no product and no
/// purchase: after that, the way out is to create the right type and move the
/// registrations one by one.
bool canChangeBaseUnit({
  required int productCount,
  required int purchaseCount,
}) => productCount == 0 && purchaseCount == 0;

/// pt-BR: every message below is read on screen.
final class IncompatibleBaseUnit implements Exception {
  const IncompatibleBaseUnit({
    required this.productLabel,
    required this.typeName,
    required this.from,
    required this.to,
  });

  final String productLabel;
  final String typeName;
  final BaseUnit from;
  final BaseUnit to;

  String get message =>
      'A medida não bate: "$productLabel" é medido em ${_name(from)} e '
      '"$typeName" em ${_name(to)}. Corrija a unidade base do tipo antes de '
      'mover.';

  /// Spelled out, never the symbol: "kg" beside a sentence reads as an
  /// abbreviation of something else.
  static String _name(BaseUnit unit) => switch (unit) {
    BaseUnit.gram => 'gramas',
    BaseUnit.milliliter => 'mililitros',
    BaseUnit.unit => 'unidades',
    BaseUnit.centimeter => 'centímetros',
  };

  @override
  String toString() => 'IncompatibleBaseUnit: $message';
}

final class BaseUnitLocked implements Exception {
  const BaseUnitLocked();

  String get message =>
      'Este tipo já tem produtos ou compras. A unidade base não pode mais '
      'mudar.';

  @override
  String toString() => 'BaseUnitLocked: $message';
}

/// Deactivating a type that is on the list, with the number that makes the
/// warning worth reading. The sentence DERIVES from the count (rule 6) — it
/// never repeats a figure written by hand.
final class TypeInUseOnList implements Exception {
  const TypeInUseOnList({required this.name, required this.itemCount});

  final String name;
  final int itemCount;

  String get message => itemCount == 1
      ? '$name está em 1 item da lista — ele será removido.'
      : '$name está em $itemCount itens da lista — eles serão removidos.';

  @override
  String toString() => 'TypeInUseOnList: $message';
}
