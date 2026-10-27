import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';
import 'package:shopping_list/domain/models/period_summary.dart';

PeriodLine line({
  String categoryId = 'ca01',
  String categoryName = 'Check Carnes',
  String typeId = 'bb01',
  String typeName = 'Acém',
  BaseUnit baseUnit = BaseUnit.gram,
  String? brandId,
  String? brandName,
  int quantity = 1000,
  int paid = 1000,
}) => PeriodLine(
  categoryId: categoryId,
  categoryName: categoryName,
  productTypeId: typeId,
  productTypeName: typeName,
  baseUnit: baseUnit,
  brandId: brandId,
  brandName: brandName,
  quantityInBaseUnit: quantity,
  paid: Money(paid),
);

IList<PeriodLine> fixture() => IList([
  line(quantity: 5000, paid: 15000),
  line(quantity: 1000, paid: 4200),
  line(
    typeId: 'bb02',
    typeName: 'Sabão',
    brandId: 'bd01',
    brandName: 'Omo',
    quantity: 4300,
    paid: 8600,
  ),
  line(
    typeId: 'bb02',
    typeName: 'Sabão',
    brandId: 'bd02',
    brandName: 'Tixan',
    quantity: 2500,
    paid: 5000,
  ),
  line(
    categoryId: 'ca02',
    categoryName: 'Check Limpeza',
    typeId: 'bb03',
    typeName: 'Frango',
    quantity: 1000,
    paid: 1100,
  ),
  line(
    categoryId: 'ca02',
    categoryName: 'Check Limpeza',
    typeId: 'bb03',
    typeName: 'Frango',
    quantity: 1000,
    paid: 2200,
  ),
]);

TypeSpending typeOf(PeriodReport r, String id) =>
    r.types.firstWhere((t) => t.productTypeId == id);

void main() {
  group('summarizePeriod', () {
    test('sums quantity and money of a type across purchases', () {
      final beef = typeOf(summarizePeriod(fixture()), 'bb01');

      expect(beef.quantityInBaseUnit, 6000);
      expect(beef.spent, const Money(19200));
      expect(beef.costPerBaseUnit, 3200);
    });

    test('the type sums every brand under it', () {
      final powder = typeOf(summarizePeriod(fixture()), 'bb02');

      expect(powder.quantityInBaseUnit, 6800);
      expect(powder.spent, const Money(13600));
    });

    test('breaks a type into one row per brand', () {
      final rows = summarizePeriod(
        fixture(),
      ).brands.where((b) => b.productTypeId == 'bb02' && b.hasBrand).toList();

      expect(rows, hasLength(2));
      expect(rows[0].name, 'Omo');
      expect(rows[0].quantityInBaseUnit, 4300);
      expect(rows[0].spent, const Money(8600));
      expect(rows[1].name, 'Tixan');
      expect(rows[1].quantityInBaseUnit, 2500);
      expect(rows[1].spent, const Money(5000));
    });

    test('a category with two types is one line summing them', () {
      final categories = summarizePeriod(fixture()).categories;
      final meat = categories.where((c) => c.categoryId == 'ca01').toList();

      expect(meat, hasLength(1));
      expect(meat.single.spent, const Money(32800));
      expect(meat.single.name, 'Check Carnes');
    });

    test('the category carries money only', () {
      final cleaning = summarizePeriod(
        fixture(),
      ).categories.firstWhere((c) => c.categoryId == 'ca02');

      expect(cleaning.spent, const Money(3300));
    });

    test('the total of the report adds up to every line', () {
      expect(summarizePeriod(fixture()).total, const Money(36100));
    });

    test('the unbranded product is a brand row with null id and name', () {
      final report = summarizePeriod(fixture());
      final unbranded = report.brands.firstWhere(
        (b) => b.productTypeId == 'bb01',
      );

      expect(typeOf(report, 'bb01'), isNotNull);
      expect(unbranded.brandId, isNull);
      expect(unbranded.name, isNull);
      expect(unbranded.quantityInBaseUnit, 6000);
      expect(unbranded.spent, const Money(19200));
    });

    test('a deactivated brand or type still reports', () {
      final report = summarizePeriod(fixture());
      final tixan = report.brands.firstWhere((b) => b.brandId == 'bd02');

      expect(tixan.quantityInBaseUnit, 2500);
      expect(tixan.spent, const Money(5000));
      expect(typeOf(report, 'bb03').spent, const Money(3300));
    });

    test('no line is the empty report', () {
      final report = summarizePeriod(const IList.empty());

      expect(report, PeriodReport.empty);
      expect(report.isEmpty, isTrue);
    });

    test('sums stay exact integers past 32 bits', () {
      final report = summarizePeriod(
        IList([
          for (var i = 0; i < 3; i++)
            line(quantity: 1000000000, paid: 1000000000),
        ]),
      );

      expect(report.total, const Money(3000000000));
      expect(report.types.single.quantityInBaseUnit, 3000000000);
    });

    test('a single line yields one row at each level', () {
      final report = summarizePeriod(
        IList([line(brandId: 'bd01', brandName: 'Omo')]),
      );

      expect(report.categories, hasLength(1));
      expect(report.types, hasLength(1));
      expect(report.brands, hasLength(1));
      expect(report.types.single.quantityInBaseUnit, 1000);
      expect(report.brands.single.spent, const Money(1000));
    });

    test('the same brand under two types is two rows', () {
      final report = summarizePeriod(
        IList([
          line(typeId: 't1', brandId: 'bd01', brandName: 'Omo', paid: 100),
          line(typeId: 't2', brandId: 'bd01', brandName: 'Omo', paid: 200),
        ]),
      );

      expect(report.brands, hasLength(2));
      expect(report.brands[0].spent, const Money(100));
      expect(report.brands[1].spent, const Money(200));
    });

    test('groups by id, never by name', () {
      final report = summarizePeriod(
        IList([
          line(categoryId: 'c1', categoryName: 'Same', typeId: 't1'),
          line(categoryId: 'c2', categoryName: 'Same', typeId: 't2'),
        ]),
      );

      expect(report.categories, hasLength(2));
      expect(report.types, hasLength(2));
    });

    test('keeps the order of first appearance and does not sort', () {
      final a = line(categoryId: 'b', typeId: 'tb', paid: 1);
      final b = line(categoryId: 'a', typeId: 'ta', paid: 2);

      final forward = summarizePeriod(IList([a, b]));
      final backward = summarizePeriod(IList([b, a]));

      expect(forward.categories.map((c) => c.categoryId), ['b', 'a']);
      expect(backward.categories.map((c) => c.categoryId), ['a', 'b']);
      expect(forward.types.map((t) => t.productTypeId), ['tb', 'ta']);
      expect(backward.brands.map((x) => x.productTypeId), ['ta', 'tb']);
      expect(forward.total, backward.total);
    });

    test('a free line sums to zero money', () {
      final report = summarizePeriod(IList([line(paid: 0)]));

      expect(report.categories.single.spent, Money.zero);
      expect(report.types.single.spent, Money.zero);
    });

    test('a type whose quantity sums to zero throws ArgumentError', () {
      expect(
        () => summarizePeriod(IList([line(quantity: 0)])),
        throwsArgumentError,
      );
    });
  });

  group('PeriodLine', () {
    test('PeriodLine equality, field by field', () {
      final base = line(brandId: 'b', brandName: 'Omo');
      final same = line(brandId: 'b', brandName: 'Omo');

      expect(base, same);
      expect(base.hashCode, same.hashCode);

      final others = <PeriodLine>[
        line(categoryId: 'x', brandId: 'b', brandName: 'Omo'),
        line(categoryName: 'x', brandId: 'b', brandName: 'Omo'),
        line(typeId: 'x', brandId: 'b', brandName: 'Omo'),
        line(typeName: 'x', brandId: 'b', brandName: 'Omo'),
        line(baseUnit: BaseUnit.unit, brandId: 'b', brandName: 'Omo'),
        line(brandName: 'Omo'),
        line(brandId: 'b'),
        line(quantity: 1, brandId: 'b', brandName: 'Omo'),
        line(paid: 1, brandId: 'b', brandName: 'Omo'),
      ];
      for (final other in others) {
        expect(base == other, isFalse);
      }
    });

    test('PeriodLine toString names the line', () {
      expect(
        line(brandId: 'b', brandName: 'Omo').toString(),
        allOf(contains('Check Carnes'), contains('Acém'), contains('Omo')),
      );
      expect(line().toString(), contains('sem marca'));
    });
  });
}
