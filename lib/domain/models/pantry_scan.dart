import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'monthly_average.dart';
import 'product_type.dart';
import 'shopping_list.dart';
import 'shopping_list_item.dart';

/// What a code read on screen 2 (the pantry check) does.
sealed class PantryScan {
  const PantryScan();
}

/// Tick the line of the type and scroll to it. Nothing is written.
final class TickLine extends PantryScan {
  const TickLine(this.typeId);

  final String typeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TickLine && other.typeId == typeId);

  @override
  int get hashCode => Object.hash(TickLine, typeId);
}

/// The line is locked: scroll to it, tick nothing.
final class LineAlreadyOnList extends PantryScan {
  const LineAlreadyOnList(this.typeId);

  final String typeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineAlreadyOnList && other.typeId == typeId);

  @override
  int get hashCode => Object.hash(LineAlreadyOnList, typeId);
}

/// The pantry does not show the type: offer `[ Pôr na lista ]`.
final class TypeNotInPantry extends PantryScan {
  const TypeNotInPantry();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TypeNotInPantry;

  @override
  int get hashCode => (TypeNotInPantry).hashCode;
}

/// What reading the code of a product of [type] does on the pantry check.
///
/// The order matters: a type the pantry does not show offers `[ Pôr na lista ]`
/// even with an open line of it — whether the PRODUCT is already asked for is
/// answered by `isRegistrationTaken`, as in the `#1a` panel. An open line
/// includes the one marked "não encontrei", the same locked line.
PantryScan pantryScanOf(
  IList<MonthlyAverage> lines,
  IList<ShoppingListItem> items,
  ProductType type,
) {
  final typeId = type.id;
  if (typeId == null || !lines.any((line) => line.type.id == typeId)) {
    return const TypeNotInPantry();
  }
  if (findOpenItemOfType(items, typeId) != null) {
    return LineAlreadyOnList(typeId);
  }
  return TickLine(typeId);
}
