import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';

void main() {
  group('TypeSpending.costPerBaseUnit — the written acceptance criterion', () {
    test('5 kg at R\$ 30 plus 1 kg at R\$ 42 is R\$ 32 a kilo', () {
      // NOT R$ 36, which is the average of the two prices. The report answers
      // total spent ÷ total quantity, and this test fails with 3600.
      final beef = TypeSpending(
        productTypeId: 'type-2',
        categoryId: 'cat-2',
        name: 'Acém moído',
        baseUnit: BaseUnit.gram,
        quantityInBaseUnit: 6000,
        spent: const Money(19200),
      );

      expect(beef.costPerBaseUnit, 3200);
      expect(beef.costPerBaseUnit, isNot(3600));
      expect(beef.baseUnit.formatQuantity(beef.quantityInBaseUnit), '6 kg');
    });

    test('6,8 kg of washing powder for R\$ 136,00 is R\$ 20,00 a kilo', () {
      final powder = TypeSpending(
        productTypeId: 'type-4',
        categoryId: 'cat-3',
        name: 'Sabão em pó',
        baseUnit: BaseUnit.gram,
        quantityInBaseUnit: 6800,
        spent: const Money(13600),
      );

      expect(powder.costPerBaseUnit, 2000);
      expect(powder.baseUnit.formatQuantity(6800), '6,8 kg');
    });

    test('the rounding is half-up, and never through a double', () {
      // 100 cents over 3 units is 33,333… — down. 200 over 3 is 66,666… — up.
      expect(
        TypeSpending(
          productTypeId: 't',
          categoryId: 'c',
          name: 'x',
          baseUnit: BaseUnit.unit,
          quantityInBaseUnit: 3,
          spent: const Money(100),
        ).costPerBaseUnit,
        33,
      );
      expect(
        TypeSpending(
          productTypeId: 't',
          categoryId: 'c',
          name: 'x',
          baseUnit: BaseUnit.unit,
          quantityInBaseUnit: 3,
          spent: const Money(200),
        ).costPerBaseUnit,
        67,
      );
      // Exactly a half goes UP: 5 cents over 2 units is 2,5.
      expect(
        TypeSpending(
          productTypeId: 't',
          categoryId: 'c',
          name: 'x',
          baseUnit: BaseUnit.unit,
          quantityInBaseUnit: 2,
          spent: const Money(5),
        ).costPerBaseUnit,
        3,
      );
    });

    test('a zero quantity is refused instead of answering zero', () {
      // The schema refuses it, so a zero here is corrupt data or a bug of
      // ours — and an average price of zero would hide it behind a plausible
      // number.
      expect(
        () => TypeSpending(
          productTypeId: 't',
          categoryId: 'c',
          name: 'x',
          baseUnit: BaseUnit.gram,
          quantityInBaseUnit: 0,
          spent: const Money(1000),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TypeSpending(
          productTypeId: 't',
          categoryId: 'c',
          name: 'x',
          baseUnit: BaseUnit.gram,
          quantityInBaseUnit: -1,
          spent: const Money(1000),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PeriodReport.total and isEmpty', () {
    test('the total adds up the categories', () {
      final report = PeriodReport(
        categories: [
          const CategorySpending(
            categoryId: 'cat-2',
            name: 'Carnes',
            spent: Money(48000),
          ),
          const CategorySpending(
            categoryId: 'cat-1',
            name: 'Bebidas',
            spent: Money(72000),
          ),
        ].lock,
        types: const IList.empty(),
        brands: const IList.empty(),
      );

      expect(report.total, const Money(120000));
    });

    test('a report with no category is empty and totals zero', () {
      expect(PeriodReport.empty.isEmpty, isTrue);
      expect(PeriodReport.empty.total, Money.zero);
    });

    test('a report WITH categories is not empty, even totalling zero', () {
      // `check (total_paid >= 0)` allows it: a period where everything was
      // free draws its lines instead of the empty state.
      final report = PeriodReport(
        categories: [
          const CategorySpending(
            categoryId: 'cat-1',
            name: 'Bebidas',
            spent: Money.zero,
          ),
        ].lock,
        types: const IList.empty(),
        brands: const IList.empty(),
      );

      expect(report.isEmpty, isFalse);
      expect(report.total, Money.zero);
    });
  });

  group('spendingShareInTenths — the arithmetic the three levels share', () {
    test('the whole part comes back in tenths', () {
      // R$ 48,00 out of R$ 120,00 is 40,0%.
      expect(
        spendingShareInTenths(part: const Money(4800), whole: const Money(12000)),
        400,
      );
    });

    test('the rounding is half-up', () {
      // 6,25% — up, to 6,3%. The integer case (12,5%) no longer serves: in
      // tenths it is exact.
      expect(
        spendingShareInTenths(part: const Money(1), whole: const Money(16)),
        63,
      );
    });

    test('below the half it rounds down', () {
      // 3,33...% — down, to 3,3%.
      expect(
        spendingShareInTenths(part: const Money(1), whole: const Money(30)),
        33,
      );
    });

    test('a whole of zero answers zero instead of dividing by zero', () {
      expect(spendingShareInTenths(part: Money.zero, whole: Money.zero), 0);
    });

    test('a part of zero answers zero', () {
      expect(
        spendingShareInTenths(part: Money.zero, whole: const Money(12000)),
        0,
      );
    });

    test('a part equal to the whole answers 1000', () {
      expect(
        spendingShareInTenths(
          part: const Money(12000),
          whole: const Money(12000),
        ),
        1000,
      );
    });

    test('percentageInTenthsOf is this same function, over the total', () {
      // The case that keeps the delegation from changing H12's behaviour
      // without anyone noticing.
      final meat = const CategorySpending(
        categoryId: 'cat-2',
        name: 'Carnes',
        spent: Money(48000),
      );
      final drinks = const CategorySpending(
        categoryId: 'cat-1',
        name: 'Bebidas',
        spent: Money(72000),
      );
      final report = PeriodReport(
        categories: [meat, drinks].lock,
        types: const IList.empty(),
        brands: const IList.empty(),
      );

      for (final category in [meat, drinks]) {
        expect(
          report.percentageInTenthsOf(category),
          spendingShareInTenths(part: category.spent, whole: report.total),
          reason: category.name,
        );
      }
    });
  });

  group('percentageInTenthsOf — H12, with the decimal place of G-d', () {
    final meat = const CategorySpending(
      categoryId: 'cat-2',
      name: 'Carnes',
      spent: Money(48000),
    );
    final drinks = const CategorySpending(
      categoryId: 'cat-1',
      name: 'Bebidas',
      spent: Money(72000),
    );

    PeriodReport reportOf(List<CategorySpending> categories) => PeriodReport(
      categories: categories.lock,
      types: const IList.empty(),
      brands: const IList.empty(),
    );

    test('R\$ 480 of R\$ 1.200 is 40,0%', () {
      final report = reportOf([meat, drinks]);

      expect(report.percentageInTenthsOf(meat), 400);
      expect(report.percentageInTenthsOf(drinks), 600);
    });

    test('the percentage is over the total of the PERIOD, not of the month', () {
      // The same category, in a period that also holds something else, gets a
      // different percentage — which is the whole point of H12.
      expect(reportOf([meat]).percentageInTenthsOf(meat), 1000);
      expect(reportOf([meat, drinks]).percentageInTenthsOf(meat), 400);
    });

    test('the rounding is half-up', () {
      final odd = const CategorySpending(
        categoryId: 'cat-2',
        name: 'Carnes',
        spent: Money(48060),
      );
      final rest = const CategorySpending(
        categoryId: 'cat-1',
        name: 'Bebidas',
        spent: Money(71940),
      );

      // 40,05% — up, to 40,1%.
      expect(reportOf([odd, rest]).percentageInTenthsOf(odd), 401);
    });

    test('an empty report answers zero instead of dividing by zero', () {
      expect(PeriodReport.empty.percentageInTenthsOf(meat), 0);
    });

    test('a report of free purchases answers zero, and reaches the screen', () {
      final free = const CategorySpending(
        categoryId: 'cat-1',
        name: 'Bebidas',
        spent: Money.zero,
      );
      final report = reportOf([free]);

      expect(report.isEmpty, isFalse);
      expect(report.percentageInTenthsOf(free), 0);
    });

    test('three equal thirds do not add up to 100, and that is accepted', () {
      // Half-up on each line can give 99,9% or 100,1%. The screen shows
      // `(NN,N%)` per line and the total in money — never the sum of the
      // percentages —, and forcing the close would make one line lie so
      // another could balance.
      final a = const CategorySpending(
        categoryId: 'a',
        name: 'A',
        spent: Money(100),
      );
      final b = const CategorySpending(
        categoryId: 'b',
        name: 'B',
        spent: Money(100),
      );
      final c = const CategorySpending(
        categoryId: 'c',
        name: 'C',
        spent: Money(100),
      );
      final report = reportOf([a, b, c]);

      // 33,3% each, and 99,9% together.
      expect(
        report.percentageInTenthsOf(a) +
            report.percentageInTenthsOf(b) +
            report.percentageInTenthsOf(c),
        999,
      );
    });
  });

  group('fromJson', () {
    test('reads the three keys the function returns', () {
      final report = PeriodReport.fromJson(const {
        'categories': [
          {
            'category_id': 'cat-2',
            'category_name': 'Carnes',
            'total_paid': 19200,
          },
        ],
        'types': [
          {
            'product_type_id': 'type-2',
            'product_type_name': 'Acém moído',
            'category_id': 'cat-2',
            'base_unit': 'gram',
            'quantity_in_base_unit': 6000,
            'total_paid': 19200,
          },
        ],
        'brands': [
          {
            'product_type_id': 'type-2',
            'brand_id': null,
            'brand_name': null,
            'quantity_in_base_unit': 6000,
            'total_paid': 19200,
          },
        ],
      });

      expect(report.categories.single.name, 'Carnes');
      expect(report.categories.single.spent, const Money(19200));
      expect(report.types.single.baseUnit, BaseUnit.gram);
      expect(report.types.single.quantityInBaseUnit, 6000);
      expect(report.brands.single.hasBrand, isFalse);
      expect(report.brands.single.name, isNull);
    });

    test('three empty arrays are the empty period, not an error', () {
      // `jsonb_agg` of zero rows is NULL, so the function coalesces to `[]` —
      // and the empty period is a STATE to draw.
      final report = PeriodReport.fromJson(const {
        'categories': <Object>[],
        'types': <Object>[],
        'brands': <Object>[],
      });

      expect(report, PeriodReport.empty);
      expect(report.isEmpty, isTrue);
    });

    test('a missing key is read as empty rather than crashing the screen', () {
      expect(PeriodReport.fromJson(const {}), PeriodReport.empty);
    });
  });

  test('every toString names the row, for the debugger and a failed test', () {
    // Never read on screen — `formatMoney` and `formatQuantity` are what the
    // user sees. These are what a failing expect() prints.
    expect(
      const CategorySpending(
        categoryId: 'cat-2',
        name: 'Carnes',
        spent: Money(19200),
      ).toString(),
      'CategorySpending(Carnes, 19200)',
    );
    expect(
      TypeSpending(
        productTypeId: 'type-2',
        categoryId: 'cat-2',
        name: 'Acém moído',
        baseUnit: BaseUnit.gram,
        quantityInBaseUnit: 6000,
        spent: const Money(19200),
      ).toString(),
      'TypeSpending(Acém moído, 6000, 19200)',
    );
    expect(
      const BrandSpending(
        productTypeId: 'type-4',
        brandId: 'brand-2',
        name: 'Omo',
        quantityInBaseUnit: 4300,
        spent: Money(8600),
      ).toString(),
      'BrandSpending(Omo, 4300, 8600)',
    );
    // The unbranded group says so instead of printing 'null'.
    expect(
      const BrandSpending(
        productTypeId: 'type-2',
        brandId: null,
        name: null,
        quantityInBaseUnit: 6000,
        spent: Money(19200),
      ).toString(),
      'BrandSpending(sem marca, 6000, 19200)',
    );
    expect(
      PeriodReport.empty.toString(),
      'PeriodReport(0 categorias, 0 tipos, 0 marcas)',
    );
  });

  group('equality, field by field', () {
    test('CategorySpending', () {
      const base = CategorySpending(
        categoryId: 'cat-1',
        name: 'Bebidas',
        spent: Money(100),
      );

      expect(
        base,
        const CategorySpending(
          categoryId: 'cat-1',
          name: 'Bebidas',
          spent: Money(100),
        ),
      );
      expect(
        base.hashCode,
        const CategorySpending(
          categoryId: 'cat-1',
          name: 'Bebidas',
          spent: Money(100),
        ).hashCode,
      );

      expect(
        base ==
            const CategorySpending(
              categoryId: 'cat-2',
              name: 'Bebidas',
              spent: Money(100),
            ),
        isFalse,
      );
      expect(
        base ==
            const CategorySpending(
              categoryId: 'cat-1',
              name: 'Carnes',
              spent: Money(100),
            ),
        isFalse,
      );
      expect(
        base ==
            const CategorySpending(
              categoryId: 'cat-1',
              name: 'Bebidas',
              spent: Money(101),
            ),
        isFalse,
      );
    });

    test('TypeSpending', () {
      TypeSpending typeOf({
        String productTypeId = 'type-1',
        String categoryId = 'cat-1',
        String name = 'Refrigerante',
        BaseUnit baseUnit = BaseUnit.milliliter,
        int quantityInBaseUnit = 12000,
        Money spent = const Money(6200),
      }) => TypeSpending(
        productTypeId: productTypeId,
        categoryId: categoryId,
        name: name,
        baseUnit: baseUnit,
        quantityInBaseUnit: quantityInBaseUnit,
        spent: spent,
      );

      expect(typeOf(), typeOf());
      expect(typeOf().hashCode, typeOf().hashCode);

      expect(typeOf() == typeOf(productTypeId: 'type-9'), isFalse);
      expect(typeOf() == typeOf(categoryId: 'cat-9'), isFalse);
      expect(typeOf() == typeOf(name: 'Outro'), isFalse);
      expect(typeOf() == typeOf(baseUnit: BaseUnit.gram), isFalse);
      expect(typeOf() == typeOf(quantityInBaseUnit: 1), isFalse);
      expect(typeOf() == typeOf(spent: const Money(1)), isFalse);
    });

    test('BrandSpending', () {
      BrandSpending brandOf({
        String productTypeId = 'type-1',
        String? brandId = 'brand-1',
        String? name = 'Coca-Cola',
        int quantityInBaseUnit = 4200,
        Money spent = const Money(6200),
      }) => BrandSpending(
        productTypeId: productTypeId,
        brandId: brandId,
        name: name,
        quantityInBaseUnit: quantityInBaseUnit,
        spent: spent,
      );

      expect(brandOf(), brandOf());
      expect(brandOf().hashCode, brandOf().hashCode);

      expect(brandOf() == brandOf(productTypeId: 'type-9'), isFalse);
      expect(brandOf() == brandOf(brandId: null), isFalse);
      expect(brandOf() == brandOf(name: 'Outra'), isFalse);
      expect(brandOf() == brandOf(quantityInBaseUnit: 1), isFalse);
      expect(brandOf() == brandOf(spent: const Money(1)), isFalse);
    });

    test('PeriodReport', () {
      final categories = [
        const CategorySpending(
          categoryId: 'cat-1',
          name: 'Bebidas',
          spent: Money(100),
        ),
      ].lock;
      final types = [
        TypeSpending(
          productTypeId: 'type-1',
          categoryId: 'cat-1',
          name: 'Refrigerante',
          baseUnit: BaseUnit.milliliter,
          quantityInBaseUnit: 12000,
          spent: const Money(100),
        ),
      ].lock;
      final brands = [
        const BrandSpending(
          productTypeId: 'type-1',
          brandId: 'brand-1',
          name: 'Coca-Cola',
          quantityInBaseUnit: 12000,
          spent: Money(100),
        ),
      ].lock;

      final base = PeriodReport(
        categories: categories,
        types: types,
        brands: brands,
      );

      expect(
        base,
        PeriodReport(categories: categories, types: types, brands: brands),
      );
      expect(
        base.hashCode,
        PeriodReport(
          categories: categories,
          types: types,
          brands: brands,
        ).hashCode,
      );

      expect(
        base ==
            PeriodReport(
              categories: const IList.empty(),
              types: types,
              brands: brands,
            ),
        isFalse,
      );
      expect(
        base ==
            PeriodReport(
              categories: categories,
              types: const IList.empty(),
              brands: brands,
            ),
        isFalse,
      );
      expect(
        base ==
            PeriodReport(
              categories: categories,
              types: types,
              brands: const IList.empty(),
            ),
        isFalse,
      );
    });
  });
}
