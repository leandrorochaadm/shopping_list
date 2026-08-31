import 'base_unit.dart';
import 'calendar_day.dart';
import 'category.dart';
import 'product_type.dart';

/// One row of `type_consumption`, exactly as the query flattens it: a product
/// type, how much of it was consumed in each of the two intervals, and the day
/// it was FIRST ever bought.
///
/// It carries the whole [ProductType] and the whole [Category] and not a pair
/// of ids (D4, the same reason `ShoppingListItem` does): the line on screen
/// needs the type's name, the base unit the quantity is written in, and the
/// category that groups it — and screen 2 has to hand both entities to
/// `ShoppingListViewModel.addMany`, which takes nothing less.
///
/// **It decides nothing.** The divisor, the division and the rounding are
/// `monthly_average.dart`; this is the shape the repository answers in.
final class TypeConsumption {
  TypeConsumption({
    required this.type,
    required this.category,
    required this.consumedInWindow,
    required this.consumedInMonth,
    required DateTime firstPurchaseOn,
    // Rule 9: the day is rounded here, so an instant that carries an hour
    // never breaks the `==` of a row that did not change.
  }) : firstPurchaseOn = dayOf(firstPurchaseOn);

  factory TypeConsumption.fromJson(Map<String, dynamic> json) =>
      TypeConsumption(
        type: ProductType(
          id: json['product_type_id'] as String,
          name: json['product_type_name'] as String,
          categoryId: json['category_id'] as String,
          baseUnit: BaseUnit.fromJson(json['base_unit'] as String),
          active: json['type_active'] as bool? ?? true,
        ),
        category: Category(
          id: json['category_id'] as String,
          name: json['category_name'] as String,
          active: json['category_active'] as bool? ?? true,
        ),
        consumedInWindow: (json['consumed_in_window'] as num).toInt(),
        consumedInMonth: (json['consumed_in_month'] as num).toInt(),
        // Never null on a row that exists: the row is there because there was
        // a purchase. A cast that throws is the right answer to corrupt data.
        firstPurchaseOn: decodeCalendarDay(json['first_purchase_on'] as String),
      );

  final ProductType type;

  /// The type's category, always the CURRENT one — it is what groups both
  /// screens. `active` comes from the query and is kept so the entity does not
  /// lie: a `Category` always built as active would be a false field
  /// travelling into `ShoppingListItem` the moment the suggestion added it.
  final Category category;

  /// In the SMALLEST unit of the base — grams, millilitres, units.
  final int consumedInWindow;

  /// The same, for the month in progress. It is what gives the type born THIS
  /// month an average at all (`requisitos §8`, the single exception).
  final int consumedInMonth;

  /// The oldest purchase of this type in the whole history, with no interval
  /// filter — it is what says whether the product predates the window, and so
  /// what the divisor is.
  final DateTime firstPurchaseOn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TypeConsumption &&
          other.type == type &&
          other.category == category &&
          other.consumedInWindow == consumedInWindow &&
          other.consumedInMonth == consumedInMonth &&
          other.firstPurchaseOn == firstPurchaseOn);

  @override
  int get hashCode => Object.hash(
    type,
    category,
    consumedInWindow,
    consumedInMonth,
    firstPurchaseOn,
  );

  @override
  String toString() =>
      'TypeConsumption(${type.name}, window: $consumedInWindow, '
      'month: $consumedInMonth, first: ${encodeCalendarDay(firstPurchaseOn)})';
}
