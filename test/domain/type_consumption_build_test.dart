import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/monthly_average.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/reference_window.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/type_consumption.dart';
import 'package:shopping_list/domain/models/type_consumption_build.dart';

final window = closedWindow(DateTime(2026, 8, 15));
final month = ReportPeriod.monthOf(DateTime(2026, 8, 15));

final meat = Category(id: 'cat-2', name: 'Carnes');
final groceries = Category(id: 'cat-4', name: 'Mercearia');

ProductType typeOf(
  String id,
  String name, {
  BaseUnit unit = BaseUnit.gram,
  Category? category,
  bool active = true,
}) => ProductType(
  id: id,
  name: name,
  categoryId: (category ?? groceries).id!,
  baseUnit: unit,
  active: active,
);

final beef = typeOf('t-beef', 'Acém', category: meat);
final yogurt = typeOf('t-yogurt', 'Iogurte', unit: BaseUnit.milliliter);
final forgotten = typeOf('t-forgotten', 'Esquecido');
final coffee = typeOf('t-coffee', 'Café');
final soap = typeOf('t-soap', 'Sabão');
final disabled = typeOf('t-off', 'Desativado', category: meat, active: false);
final edge = typeOf('t-edge', 'Borda', unit: BaseUnit.unit, category: meat);

ConsumptionLine line(ProductType type, DateTime day, int quantity) =>
    ConsumptionLine(
      type: type,
      category: type.categoryId == meat.id ? meat : groceries,
      purchaseDate: day,
      quantityInBaseUnit: quantity,
    );

// The lines of `type_consumption_cases.sql` read from 01/05 on.
final lines = <ConsumptionLine>[
  line(beef, DateTime(2026, 5, 12), 12000),
  line(beef, DateTime(2026, 6, 10), 10000),
  line(beef, DateTime(2026, 7, 15), 2000),
  line(beef, DateTime(2026, 8, 10), 6000),
  line(yogurt, DateTime(2026, 8, 10), 3000),
  line(coffee, DateTime(2026, 6, 10), 2000),
  line(soap, DateTime(2026, 6, 10), 8000),
  line(soap, DateTime(2026, 7, 15), 8000),
  line(disabled, DateTime(2026, 5, 12), 1000),
  line(edge, DateTime(2026, 7, 31), 7),
  line(edge, DateTime(2026, 8, 1), 9),
];

// Items ever bought per type, including the March ones.
final allTime = <String, int>{
  'ZZ': 0,
  beef.id!: 4,
  yogurt.id!: 1,
  forgotten.id!: 1,
  coffee.id!: 2,
  soap.id!: 2,
  disabled.id!: 1,
  edge.id!: 2,
}.toIMap();

IList<TypeConsumption> build({
  Iterable<ConsumptionLine>? from,
  IMap<String, int>? counts,
}) => buildTypeConsumption(
  windowLines: (from ?? lines).toIList(),
  allTimeCountByType: counts ?? allTime,
  window: window,
  month: month,
);

TypeConsumption? rowOf(IList<TypeConsumption> rows, ProductType type) {
  final found = rows.where((r) => r.type.id == type.id);
  return found.isEmpty ? null : found.single;
}

void main() {
  test('sums the three closed months into consumedInWindow', () {
    expect(rowOf(build(), beef)!.consumedInWindow, 24000);
  });

  test('returns a type bought only this month with window zero', () {
    final row = rowOf(build(), yogurt)!;
    expect(row.consumedInWindow, 0);
    expect(row.consumedInMonth, 3000);
    expect(row.firstPurchaseOn, DateTime(2026, 8, 10));
    expect(closedMonthsOfLife(row.firstPurchaseOn, window), 0);
  });

  test('leaves out a type with no line inside either interval', () {
    expect(rowOf(build(), forgotten), isNull);
    final alone = build(from: [line(forgotten, DateTime(2026, 9, 2), 1000)]);
    expect(alone, isEmpty);
  });

  test('dates the first purchase the day before the read when the history '
      'has more items', () {
    final row = rowOf(build(), coffee)!;
    expect(row.firstPurchaseOn, DateTime(2026, 4, 30));
    expect(closedMonthsOfLife(row.firstPurchaseOn, window), 3);
    expect(monthlyAverageAmount(row, window), 700);
  });

  test('uses the oldest line read when the history has no older item', () {
    expect(rowOf(build(), beef)!.firstPurchaseOn, DateTime(2026, 5, 12));
  });

  test('treats a missing all-time count as no older purchase', () {
    final row = rowOf(build(counts: const IMapConst({})), coffee)!;
    expect(row.firstPurchaseOn, DateTime(2026, 6, 10));
  });

  test('treats an all-time count below the lines read as no older '
      'purchase', () {
    final row = rowOf(build(counts: {beef.id!: 1}.toIMap()), beef)!;
    expect(row.firstPurchaseOn, DateTime(2026, 5, 12));
  });

  test('sums two registrations of one type into a single row', () {
    final rows = build().where((r) => r.type.id == soap.id);
    expect(rows.length, 1);
    expect(rows.single.consumedInWindow, 16000);
  });

  test('keeps a deactivated type flagged', () {
    expect(rowOf(build(), disabled)!.type.active, isFalse);
  });

  test('returns an empty list when there is no line', () {
    expect(build(from: const []), isEmpty);
  });

  test('keeps both sums as exact integers', () {
    final row = rowOf(build(), beef)!;
    expect(row.consumedInWindow, isA<int>());
    expect(row.consumedInWindow, 24000);
    expect(row.consumedInMonth, 6000);
  });

  test('does not cross the two sums of a type in both intervals', () {
    final row = rowOf(build(), beef)!;
    expect(row.consumedInWindow, 24000);
    expect(row.consumedInMonth, 6000);
  });

  test('includes both ends of both intervals', () {
    final row = rowOf(build(), edge)!;
    expect(row.consumedInWindow, 7);
    expect(row.consumedInMonth, 9);
  });

  test('counts a line after the month as read but sums nothing', () {
    final late = line(coffee, DateTime(2026, 9, 2), 500);
    expect(build(from: [late]), isEmpty);
    final row = rowOf(
      build(from: [...lines, late], counts: {coffee.id!: 3}.toIMap()),
      coffee,
    )!;
    expect(row.consumedInWindow, 2000);
    // 3 in history, 2 read: still one older item.
    expect(row.firstPurchaseOn, DateTime(2026, 4, 30));
    final same = rowOf(
      build(from: [...lines, late], counts: {coffee.id!: 2}.toIMap()),
      coffee,
    )!;
    expect(same.firstPurchaseOn, DateTime(2026, 6, 10));
  });

  test('throws when a line predates the read start', () {
    expect(
      () => build(from: [line(beef, DateTime(2026, 4, 30), 1)]),
      throwsArgumentError,
    );
  });

  test('ConsumptionLine rejects a type without id and a negative quantity', () {
    expect(
      () => ConsumptionLine(
        type: ProductType(
          name: 'X',
          categoryId: 'cat-4',
          baseUnit: BaseUnit.gram,
        ),
        category: groceries,
        purchaseDate: DateTime(2026, 6, 1),
        quantityInBaseUnit: 1,
      ),
      throwsArgumentError,
    );
    expect(() => line(beef, DateTime(2026, 6, 1), -1), throwsArgumentError);
  });

  test('consumptionReadStart picks the earlier of the two starts', () {
    expect(consumptionReadStart(window: window, month: month), window.from);
    expect(consumptionReadStart(window: month, month: window), window.from);
  });

  test('ConsumptionLine rounds the purchase date to the day', () {
    final withHour = ConsumptionLine(
      type: beef,
      category: meat,
      purchaseDate: DateTime(2026, 6, 1, 15, 30),
      quantityInBaseUnit: 5,
    );
    expect(withHour.purchaseDate, DateTime(2026, 6, 1));
    expect(withHour, line(beef, DateTime(2026, 6, 1), 5));
  });

  test('ConsumptionLine equality covers every field', () {
    final base = line(beef, DateTime(2026, 6, 1), 5);
    final same = line(beef, DateTime(2026, 6, 1), 5);
    expect(base, same);
    expect(base.hashCode, same.hashCode);
    expect(base, isNot(line(coffee, DateTime(2026, 6, 1), 5)));
    expect(
      base,
      isNot(
        ConsumptionLine(
          type: beef,
          category: groceries,
          purchaseDate: DateTime(2026, 6, 1),
          quantityInBaseUnit: 5,
        ),
      ),
    );
    expect(base, isNot(line(beef, DateTime(2026, 6, 2), 5)));
    expect(base, isNot(line(beef, DateTime(2026, 6, 1), 6)));
    expect(base.toString(), contains('Acém'));
  });
}
