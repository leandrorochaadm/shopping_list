import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/monthly_average.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/reference_window.dart';
import 'package:shopping_list/domain/models/type_consumption.dart';

/// The closed window of a phone whose clock says 15/08/2026 — 01/05 to 31/07.
/// A fixed instant, never `DateTime.now()`.
final window = closedWindow(DateTime(2026, 8, 15));

final groceries = Category(id: 'cat-4', name: 'Mercearia');
final meat = Category(id: 'cat-2', name: 'Carnes');

ProductType typeOf(
  String id,
  String name, {
  BaseUnit unit = BaseUnit.gram,
  String categoryId = 'cat-4',
  bool active = true,
}) => ProductType(
  id: id,
  name: name,
  categoryId: categoryId,
  baseUnit: unit,
  active: active,
);

TypeConsumption rowOf({
  String id = 'type-1',
  String name = 'Café',
  BaseUnit unit = BaseUnit.gram,
  Category? category,
  bool active = true,
  int window = 0,
  int month = 0,
  required DateTime firstPurchaseOn,
}) => TypeConsumption(
  type: typeOf(
    id,
    name,
    unit: unit,
    categoryId: (category ?? groceries).id!,
    active: active,
  ),
  category: category ?? groceries,
  consumedInWindow: window,
  consumedInMonth: month,
  firstPurchaseOn: firstPurchaseOn,
);

MonthlyAverage averageOf({
  String id = 'type-1',
  String name = 'Café',
  BaseUnit unit = BaseUnit.gram,
  Category? category,
  required int average,
  int consumedInMonth = 0,
}) => MonthlyAverage(
  type: typeOf(
    id,
    name,
    unit: unit,
    // A category with no id is a real case — the one not written yet — and
    // `ProductType` needs a non-null key either way.
    categoryId: (category ?? groceries).id ?? 'unwritten',
  ),
  category: category ?? groceries,
  average: average,
  consumedInMonth: consumedInMonth,
);

void main() {
  group('closedMonthsOfLife — the divisor', () {
    test('bought before the window divides by three', () {
      // The coffee: already bought in March, so all three closed months of the
      // window count, including the two with no purchase at all.
      expect(closedMonthsOfLife(DateTime(2026, 3, 10), window), 3);
    });

    test('the FIRST day of the window still divides by three', () {
      // The boundary: a product born on 01/05 has May, June and July.
      expect(closedMonthsOfLife(DateTime(2026, 5, 1), window), 3);
    });

    test('born in the middle of the window divides by two', () {
      // The chocolate of `requisitos §8`: first bought in June, so June and
      // July — and dividing by three would say they consume a third of what
      // they consume.
      expect(closedMonthsOfLife(DateTime(2026, 6, 5), window), 2);
    });

    test('the LAST day of the window divides by one', () {
      expect(closedMonthsOfLife(DateTime(2026, 7, 31), window), 1);
    });

    test('the FIRST day of the month in progress divides by nothing', () {
      // The boundary that separates the single exception from all the rest:
      // no closed month at all, so the average is the month's own purchase.
      expect(closedMonthsOfLife(DateTime(2026, 8, 1), window), 0);
      expect(closedMonthsOfLife(DateTime(2026, 8, 31), window), 0);
    });

    test('never answers more than the window is wide', () {
      // A product bought since 2020 still divides by three: the divisor is
      // months of life INSIDE the window, not months of life.
      expect(closedMonthsOfLife(DateTime(2020, 1, 1), window), 3);
      expect(
        closedMonthsOfLife(DateTime(2020, 1, 1), window),
        lessThanOrEqualTo(referenceWindowMonths),
      );
    });

    test('the day of the month does not move the divisor', () {
      // It is built from `firstDayOfMonth`: a first purchase on 01/06 and one
      // on 30/06 both give two closed months.
      expect(
        closedMonthsOfLife(DateTime(2026, 6, 1), window),
        closedMonthsOfLife(DateTime(2026, 6, 30), window),
      );
    });
  });

  group('roundToAverageStep — one decimal place of the base unit', () {
    test('the coffee of the wireframe: 667 g becomes 700 g', () {
      // `wireframes §Tela 2` writes `Café — 0,7 kg`. Without this the screen
      // would say 0,667 and contradict the document the client reads.
      expect(roundToAverageStep(667, BaseUnit.gram), 700);
    });

    test('half goes UP, and the neighbour below goes down', () {
      expect(roundToAverageStep(650, BaseUnit.gram), 700);
      expect(roundToAverageStep(649, BaseUnit.gram), 600);
    });

    test('a multiple of the step does not move', () {
      expect(roundToAverageStep(6000, BaseUnit.gram), 6000);
      expect(roundToAverageStep(4200, BaseUnit.milliliter), 4200);
    });

    test('a positive amount NEVER becomes zero (E-d)', () {
      // 49 g in three months would round to 0 kg, and a line offering "0 kg"
      // is not an offer — `requisitos §8` says nothing is filtered for being a
      // rare purchase.
      expect(roundToAverageStep(49, BaseUnit.gram), 100);
      expect(roundToAverageStep(1, BaseUnit.milliliter), 100);
    });

    test('a zero stays zero (E-j) — it is a different case', () {
      // The product bought in March and again in August consumed NOTHING
      // inside the closed window, and the honest answer is nothing.
      expect(roundToAverageStep(0, BaseUnit.gram), 0);
      expect(roundToAverageStep(-5, BaseUnit.gram), 0);
    });

    test('the unit base counts whole things: the step is one', () {
      // There is no 0,5 roll of toilet paper.
      expect(averageStepOf(BaseUnit.unit), 1);
      expect(roundToAverageStep(12, BaseUnit.unit), 12);
      expect(roundToAverageStep(1, BaseUnit.unit), 1);
    });

    test('the step is one decimal place of each base', () {
      expect(averageStepOf(BaseUnit.gram), 100);
      expect(averageStepOf(BaseUnit.milliliter), 100);
      // The metre has two decimal places, so one of them is ten centimetres.
      expect(averageStepOf(BaseUnit.centimeter), 10);
      expect(averageDecimalPlaces, 1);
    });
  });

  group('monthlyAverageAmount — the whole rule of requirement 8', () {
    test('the beef: 24 kg over three closed months is 8 kg', () {
      expect(
        monthlyAverageAmount(
          rowOf(
            window: 24000,
            month: 6000,
            firstPurchaseOn: DateTime(2026, 5, 12),
          ),
          window,
        ),
        8000,
      );
    });

    test('the coffee: 2 kg over three months is 0,7 kg', () {
      // 2000 ÷ 3 is 666,66… g, which rounds to 700 g. The two months with no
      // purchase count zero and still divide — that is the written criterion.
      expect(
        monthlyAverageAmount(
          rowOf(window: 2000, firstPurchaseOn: DateTime(2026, 3, 10)),
          window,
        ),
        700,
      );
    });

    test('the washing powder: 16 kg over TWO closed months is 8 kg', () {
      expect(
        monthlyAverageAmount(
          rowOf(
            window: 16000,
            month: 6800,
            firstPurchaseOn: DateTime(2026, 6, 5),
          ),
          window,
        ),
        8000,
      );
    });

    test('born this month: the average is the month, with no division', () {
      // The single exception of `requisitos §8`. 12 units bought in August,
      // nothing in the window: the average is 12, not 4.
      expect(
        monthlyAverageAmount(
          rowOf(
            unit: BaseUnit.unit,
            month: 12,
            firstPurchaseOn: DateTime(2026, 8, 5),
          ),
          window,
        ),
        12,
      );
    });

    test('nothing in the window with a divisor of three gives an average of '
        'zero (E-j)', () {
      // The product bought before the window and again this month. The query
      // only returns a type with a purchase in ONE of the two intervals, so a
      // row like this always has `consumedInMonth > 0` — which is what stops
      // `consumedOverAverageLabel` ever writing "0 un comprados".
      final row = rowOf(
        window: 0,
        month: 5000,
        firstPurchaseOn: DateTime(2026, 3, 10),
      );
      expect(closedMonthsOfLife(row.firstPurchaseOn, window), 3);
      expect(monthlyAverageAmount(row, window), 0);
      expect(row.consumedInMonth, greaterThan(0));
    });
  });

  group('MonthlyAverage — the entity', () {
    test(
      'remainingForMonth is the average minus the month, never negative',
      () {
        expect(
          averageOf(average: 8000, consumedInMonth: 6000).remainingForMonth,
          2000,
        );
        // Buying more than the average is not a debt.
        expect(
          averageOf(average: 4200, consumedInMonth: 12000).remainingForMonth,
          0,
        );
      },
    );

    test('the three states of the two bands and the two prefills', () {
      final missing = averageOf(average: 8000, consumedInMonth: 6000);
      expect(missing.hasShortage, isTrue);
      expect(missing.hasAverage, isTrue);
      expect(missing.suggestedQuantity, 8000);
      expect(missing.prefillQuantity, 2000);

      final satisfied = averageOf(average: 4200, consumedInMonth: 4200);
      expect(satisfied.hasShortage, isFalse);
      expect(satisfied.hasAverage, isTrue);
      expect(satisfied.suggestedQuantity, 4200);
      // Null, not zero: a prefilled `0` would make saving throw
      // InvalidQuantity.
      expect(satisfied.prefillQuantity, isNull);

      final noAverage = averageOf(average: 0, consumedInMonth: 5000);
      expect(noAverage.hasShortage, isFalse);
      expect(noAverage.hasAverage, isFalse);
      // Null, not zero: the entity refuses a quantity of zero, and an item
      // with no quantity leaves the list on the first purchase of the type.
      expect(noAverage.suggestedQuantity, isNull);
      expect(noAverage.prefillQuantity, isNull);
    });

    test('the labels are what the two screens write', () {
      final coffee = averageOf(average: 700, consumedInMonth: 0);
      // Below the kilo the reading stays in grams: the large unit steps in
      // only once the amount reaches it.
      expect(coffee.averageLabel, '700 g');
      expect(coffee.remainingLabel, '700 g');

      final drink = averageOf(
        unit: BaseUnit.milliliter,
        average: 4200,
        consumedInMonth: 4200,
      );
      // The first number carries no unit because the second one does.
      expect(drink.consumedOverAverageLabel, '4,2 de 4,2 L');

      // With no average there is nothing to be "de" (E-j).
      final noAverage = averageOf(average: 0, consumedInMonth: 5000);
      expect(noAverage.consumedOverAverageLabel, '5 kg comprados');
    });

    test('a negative average is refused', () {
      expect(() => averageOf(average: -1), throwsA(isA<ArgumentError>()));
    });
  });

  group('monthlyAverages — from the rows to the lines', () {
    test('drops the deactivated type and keeps the rest', () {
      // The written criterion of H17: "Dado um tipo desativado, quando a
      // sugestão for montada, então ele fica de fora (H10)". The flag comes
      // from SQL and the decision is here (E-e).
      final lines = monthlyAverages(
        [
          rowOf(window: 24000, firstPurchaseOn: DateTime(2026, 5, 12)),
          rowOf(
            id: 'type-9',
            name: 'Desativado',
            active: false,
            window: 3000,
            firstPurchaseOn: DateTime(2026, 5, 12),
          ),
        ].lock,
        window,
      );

      expect(lines, hasLength(1));
      expect(lines.first.type.name, 'Café');
      expect(lines.first.average, 8000);
    });

    test('carries the whole type and the whole category (E-f)', () {
      final lines = monthlyAverages(
        [
          rowOf(
            category: meat,
            window: 24000,
            month: 6000,
            firstPurchaseOn: DateTime(2026, 5, 12),
          ),
        ].lock,
        window,
      );

      // Screen 2 hands both entities to `addMany`, which takes nothing less.
      expect(lines.first.category, meat);
      expect(lines.first.type.baseUnit, BaseUnit.gram);
      expect(lines.first.consumedInMonth, 6000);
    });

    test('no row at all is an empty list, not an error', () {
      expect(monthlyAverages(const IList.empty(), window), isEmpty);
    });
  });

  group('groupAveragesByCategory', () {
    test('orders category and line by the NORMALIZED name', () {
      // 'Açougue'.compareTo('Bebidas') in Dart compares code units and the 'ç'
      // would land after the 'z'.
      final butcher = Category(id: 'cat-9', name: 'Açougue');
      final drinks = Category(id: 'cat-1', name: 'Bebidas');

      final groups = groupAveragesByCategory(
        [
          averageOf(
            id: 'type-1',
            name: 'Refrigerante',
            category: drinks,
            average: 4200,
          ),
          averageOf(
            id: 'type-2',
            name: 'Acém moído',
            category: butcher,
            average: 8000,
          ),
          averageOf(
            id: 'type-3',
            name: 'Água',
            category: drinks,
            average: 2000,
          ),
        ].lock,
      );

      expect(groups.map((g) => g.category.name), ['Açougue', 'Bebidas']);
      // Inside 'Bebidas': 'Água' before 'Refrigerante', which only happens
      // with the accent normalized away.
      expect(groups[1].lines.map((l) => l.type.name), ['Água', 'Refrigerante']);
    });

    test('the id breaks a tie so the order is stable across fetches', () {
      final groups = groupAveragesByCategory(
        [
          averageOf(id: 'type-b', name: 'Café', average: 700),
          averageOf(id: 'type-a', name: 'Café', average: 700),
        ].lock,
      );

      expect(groups.single.lines.map((l) => l.type.id), ['type-a', 'type-b']);
    });

    test('a category with no id groups by its name instead of vanishing', () {
      final unwritten = Category(name: 'Nova');
      final groups = groupAveragesByCategory(
        [averageOf(category: unwritten, average: 100)].lock,
      );

      expect(groups.single.category.name, 'Nova');
      expect(groups.single.lines, hasLength(1));
    });
  });

  group('equality covers every field', () {
    test('TypeConsumption', () {
      final row = rowOf(
        window: 100,
        month: 200,
        firstPurchaseOn: DateTime(2026, 5, 1),
      );
      final same = rowOf(
        window: 100,
        month: 200,
        firstPurchaseOn: DateTime(2026, 5, 1),
      );

      expect(row, same);
      expect(row.hashCode, same.hashCode);

      // One field at a time.
      expect(
        row,
        isNot(
          rowOf(window: 101, month: 200, firstPurchaseOn: DateTime(2026, 5, 1)),
        ),
      );
      expect(
        row,
        isNot(
          rowOf(window: 100, month: 201, firstPurchaseOn: DateTime(2026, 5, 1)),
        ),
      );
      expect(
        row,
        isNot(
          rowOf(window: 100, month: 200, firstPurchaseOn: DateTime(2026, 5, 2)),
        ),
      );
      expect(
        row,
        isNot(
          rowOf(
            name: 'Outro',
            window: 100,
            month: 200,
            firstPurchaseOn: DateTime(2026, 5, 1),
          ),
        ),
      );
      expect(
        row,
        isNot(
          rowOf(
            category: meat,
            window: 100,
            month: 200,
            firstPurchaseOn: DateTime(2026, 5, 1),
          ),
        ),
      );
    });

    test('an hour inside the first purchase does not break the ==', () {
      // Rule 9: the day is rounded in the constructor, so a row that did not
      // change stays `==` and Riverpod keeps filtering the update.
      expect(
        rowOf(firstPurchaseOn: DateTime(2026, 5, 1, 23, 59)),
        rowOf(firstPurchaseOn: DateTime(2026, 5, 1)),
      );
    });

    test('MonthlyAverage', () {
      final line = averageOf(average: 8000, consumedInMonth: 6000);
      final same = averageOf(average: 8000, consumedInMonth: 6000);

      expect(line, same);
      expect(line.hashCode, same.hashCode);

      expect(line, isNot(averageOf(average: 8001, consumedInMonth: 6000)));
      expect(line, isNot(averageOf(average: 8000, consumedInMonth: 6001)));
      expect(
        line,
        isNot(averageOf(name: 'Outro', average: 8000, consumedInMonth: 6000)),
      );
      expect(
        line,
        isNot(averageOf(category: meat, average: 8000, consumedInMonth: 6000)),
      );
    });

    test('MonthlyAverageGroup', () {
      final lines = [averageOf(average: 700)].lock;
      final group = MonthlyAverageGroup(category: groceries, lines: lines);

      expect(group, MonthlyAverageGroup(category: groceries, lines: lines));
      expect(
        group.hashCode,
        MonthlyAverageGroup(category: groceries, lines: lines).hashCode,
      );

      expect(group, isNot(MonthlyAverageGroup(category: meat, lines: lines)));
      expect(
        group,
        isNot(
          MonthlyAverageGroup(
            category: groceries,
            lines: [averageOf(average: 800)].lock,
          ),
        ),
      );
    });
  });
}
