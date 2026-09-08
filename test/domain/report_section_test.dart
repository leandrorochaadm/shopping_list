import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';
import 'package:shopping_list/domain/models/report_section.dart';

CategorySpending category(String id, String name, int cents) =>
    CategorySpending(categoryId: id, name: name, spent: Money(cents));

TypeSpending type(
  String id,
  String categoryId,
  String name,
  int cents, {
  int quantity = 1000,
  BaseUnit baseUnit = BaseUnit.gram,
}) => TypeSpending(
  productTypeId: id,
  categoryId: categoryId,
  name: name,
  baseUnit: baseUnit,
  quantityInBaseUnit: quantity,
  spent: Money(cents),
);

BrandSpending brand(
  String typeId,
  String? id,
  String? name,
  int cents, {
  int quantity = 1000,
}) => BrandSpending(
  productTypeId: typeId,
  brandId: id,
  name: name,
  quantityInBaseUnit: quantity,
  spent: Money(cents),
);

PeriodReport reportOf({
  List<CategorySpending> categories = const [],
  List<TypeSpending> types = const [],
  List<BrandSpending> brands = const [],
}) => PeriodReport(
  categories: categories.lock,
  types: types.lock,
  brands: brands.lock,
);

void main() {
  group('order — where the money went comes first', () {
    test('categories come from the most expensive to the cheapest', () {
      final sections = buildReportSections(
        reportOf(
          categories: [
            category('cat-1', 'Bebidas', 10000),
            category('cat-2', 'Carnes', 48000),
            category('cat-3', 'Limpeza', 13600),
          ],
        ),
      );

      expect(
        sections.map((s) => s.category.name).toList(),
        ['Carnes', 'Limpeza', 'Bebidas'],
      );
    });

    test('a tie in value breaks on the NORMALIZED name', () {
      // "Água" before "Bebidas": without normalizing, the accented A sorts
      // after every unaccented letter and the order looks random.
      final sections = buildReportSections(
        reportOf(
          categories: [
            category('cat-2', 'Bebidas', 10000),
            category('cat-1', 'Água', 10000),
          ],
        ),
      );

      expect(sections.map((s) => s.category.name).toList(), ['Água', 'Bebidas']);
    });

    test('a tie in name breaks on the id, so the order never oscillates', () {
      final sections = buildReportSections(
        reportOf(
          categories: [
            category('cat-9', 'Carnes', 10000),
            category('cat-1', 'Carnes', 10000),
          ],
        ),
      );

      expect(
        sections.map((s) => s.category.categoryId).toList(),
        ['cat-1', 'cat-9'],
      );
    });

    test('types are ordered inside their category, by the same rule', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-2', 'Carnes', 60000)],
          types: [
            type('type-2', 'cat-2', 'Acém moído', 19200),
            type('type-5', 'cat-2', 'Frango', 40800),
          ],
        ),
      );

      expect(
        sections.single.types.map((t) => t.type.name).toList(),
        ['Frango', 'Acém moído'],
      );
    });

    test('brands are ordered inside their type, by the same rule', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-3', 'Limpeza', 13600)],
          types: [type('type-4', 'cat-3', 'Sabão em pó', 13600, quantity: 6800)],
          brands: [
            brand('type-4', 'brand-4', 'Tixan', 5000, quantity: 2500),
            brand('type-4', 'brand-2', 'Omo', 8600, quantity: 4300),
          ],
        ),
      );

      expect(
        sections.single.types.single.brands.map((b) => b.brand.name).toList(),
        ['Omo', 'Tixan'],
      );
    });
  });

  group('C2 — the product with no brand stays out of the breakdown', () {
    test('the null-brand group does not become a line', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-3', 'Limpeza', 13600)],
          types: [type('type-4', 'cat-3', 'Sabão em pó', 13600, quantity: 6800)],
          brands: [
            brand('type-4', 'brand-2', 'Omo', 8600, quantity: 4300),
            brand('type-4', null, null, 5000, quantity: 2500),
          ],
        ),
      );

      final line = sections.single.types.single;
      expect(line.brands, hasLength(1));
      expect(line.brands.single.brand.name, 'Omo');
      // The type's total still counts what the unbranded purchase spent: the
      // open lines may add up to LESS than the line above them, and that is
      // accepted.
      expect(line.type.spent, const Money(13600));
      expect(line.brands.single.brand.spent, const Money(8600));
    });

    test('D-a — a type with only unbranded purchases offers no expansion', () {
      // The ground beef: there would not be a single line to show.
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-2', 'Carnes', 19200)],
          types: [type('type-2', 'cat-2', 'Acém moído', 19200, quantity: 6000)],
          brands: [brand('type-2', null, null, 19200, quantity: 6000)],
        ),
      );

      expect(sections.single.types.single.hasBrandBreakdown, isFalse);
      expect(sections.single.types.single.brands, isEmpty);
    });

    test('D-a — one brand plus unbranded still expands, with one line', () {
      // The chicken: a Sadia and the rest with no brand.
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-2', 'Carnes', 40800)],
          types: [type('type-5', 'cat-2', 'Frango', 40800, quantity: 8000)],
          brands: [
            brand('type-5', 'brand-5', 'Sadia', 15000, quantity: 3000),
            brand('type-5', null, null, 25800, quantity: 5000),
          ],
        ),
      );

      final line = sections.single.types.single;
      expect(line.hasBrandBreakdown, isTrue);
      expect(line.brands, hasLength(1));
      expect(line.brands.single.brand.name, 'Sadia');
    });

    test('a type with no brand row at all offers no expansion either', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-2', 'Carnes', 19200)],
          types: [type('type-2', 'cat-2', 'Acém moído', 19200, quantity: 6000)],
        ),
      );

      expect(sections.single.types.single.hasBrandBreakdown, isFalse);
    });
  });

  group('the tree', () {
    test('each section carries the percentage H12 computed', () {
      final report = reportOf(
        categories: [
          category('cat-2', 'Carnes', 48000),
          category('cat-1', 'Bebidas', 72000),
        ],
      );
      final sections = buildReportSections(report);

      for (final section in sections) {
        expect(
          section.percentageInTenths,
          report.percentageInTenthsOf(section.category),
          reason: section.category.name,
        );
      }
      expect(sections.first.percentageInTenths, 600);
      expect(sections.last.percentageInTenths, 400);
    });

    test('a category with no type comes back with an empty list, not absent', () {
      final sections = buildReportSections(
        reportOf(categories: [category('cat-1', 'Bebidas', 10000)]),
      );

      expect(sections, hasLength(1));
      expect(sections.single.types, isEmpty);
    });

    test('a type whose category is not in the report is simply not drawn', () {
      // It cannot happen with the real query — both come from the same join —
      // but the tree must not lose a category over it.
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-1', 'Bebidas', 10000)],
          types: [type('type-9', 'cat-9', 'Órfão', 500)],
        ),
      );

      expect(sections, hasLength(1));
      expect(sections.single.types, isEmpty);
    });

    test('an empty report gives an empty list of sections', () {
      expect(buildReportSections(PeriodReport.empty), isEmpty);
    });
  });

  group('the percentage of each level, against the one above', () {
    test('the type divides by its CATEGORY, not by the period', () {
      // The second category is what makes the two divisors differ — and the
      // types are 80/20 on purpose, so the smaller one does not land on the
      // same number as the section.
      final sections = buildReportSections(
        reportOf(
          categories: [
            category('cat-1', 'Bebidas', 10000),
            category('cat-2', 'Carnes', 30000),
          ],
          types: [
            type('type-1', 'cat-1', 'Refrigerante', 8000),
            type('type-3', 'cat-1', 'Suco', 2000),
          ],
        ),
      );

      final drinks = sections.firstWhere(
        (s) => s.category.categoryId == 'cat-1',
      );
      // G-a: 25,0% of the period, and the types below it read 80% and 20% of
      // the category — not 20% and 5% of the period.
      expect(drinks.percentageInTenths, 250);
      expect(
        drinks.types.map((t) => t.percentageInTenths).toList(),
        [800, 200],
      );
    });

    test('the brand divides by its TYPE', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-1', 'Bebidas', 10000)],
          types: [type('type-1', 'cat-1', 'Refrigerante', 10000)],
          brands: [
            brand('type-1', 'brand-1', 'Coca-Cola', 8000),
            brand('type-1', 'brand-9', 'Pepsi', 2000),
          ],
        ),
      );

      expect(
        sections.single.types.single.brands
            .map((b) => b.percentageInTenths)
            .toList(),
        [800, 200],
      );
    });

    test('G-b — the brands add up to less than 100% when C2 dropped a group', () {
      // R$ 100,00 with a brand out of R$ 150,00 spent: the third with no
      // brand is not a line, and the shown one is 66,7% — never 100%.
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-2', 'Carnes', 15000)],
          types: [type('type-5', 'cat-2', 'Frango', 15000)],
          brands: [
            brand('type-5', 'brand-5', 'Sadia', 10000),
            brand('type-5', null, null, 5000),
          ],
        ),
      );

      final line = sections.single.types.single;
      expect(line.brands, hasLength(1));
      expect(line.brands.single.percentageInTenths, 667);
      // And the type did not lose anything: it is still the whole category.
      expect(line.percentageInTenths, 1000);
    });

    test('a category that spent nothing does not divide by zero', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-1', 'Bebidas', 0)],
          types: [type('type-1', 'cat-1', 'Refrigerante', 0)],
        ),
      );

      expect(sections.single.types.single.percentageInTenths, 0);
    });

    test('a type that spent nothing does not divide by zero', () {
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-1', 'Bebidas', 0)],
          types: [type('type-1', 'cat-1', 'Refrigerante', 0)],
          brands: [brand('type-1', 'brand-1', 'Coca-Cola', 0)],
        ),
      );

      expect(sections.single.types.single.brands.single.percentageInTenths, 0);
    });

    test('the half tenth rounds up all the way to the line', () {
      // R$ 48,06 of R$ 120,00 is 40,05% — up, to 40,1%. Without this case
      // nothing says the line calls spendingShareInTenths and not a `~/`
      // written by hand.
      final sections = buildReportSections(
        reportOf(
          categories: [category('cat-1', 'Bebidas', 12000)],
          types: [type('type-1', 'cat-1', 'Refrigerante', 4806)],
        ),
      );

      expect(sections.single.types.single.percentageInTenths, 401);
    });
  });

  test('the three toStrings name the row, for a failed expect()', () {
    expect(
      ReportBrandLine(
        brand: brand('type-4', 'brand-2', 'Omo', 8600, quantity: 4300),
        percentageInTenths: 632,
      ).toString(),
      'ReportBrandLine(Omo, 632)',
    );
    expect(
      ReportTypeLine(
        type: type('type-4', 'cat-3', 'Sabão em pó', 13600, quantity: 6800),
        percentageInTenths: 791,
        brands: [
          ReportBrandLine(
            brand: brand('type-4', 'brand-2', 'Omo', 8600, quantity: 4300),
            percentageInTenths: 632,
          ),
        ].lock,
      ).toString(),
      'ReportTypeLine(Sabão em pó, 791, 1 marcas)',
    );
    expect(
      ReportSection(
        category: category('cat-2', 'Carnes', 48000),
        percentageInTenths: 400,
        types: const IList<ReportTypeLine>.empty(),
      ).toString(),
      'ReportSection(Carnes, 400, 0 tipos)',
    );
  });

  group('equality', () {
    test('ReportBrandLine covers both fields', () {
      final line = ReportBrandLine(
        brand: brand('type-1', 'brand-1', 'Coca-Cola', 6200),
        percentageInTenths: 1000,
      );
      final same = ReportBrandLine(
        brand: brand('type-1', 'brand-1', 'Coca-Cola', 6200),
        percentageInTenths: 1000,
      );

      expect(line, same);
      expect(line.hashCode, same.hashCode);

      expect(
        line ==
            ReportBrandLine(
              brand: brand('type-1', 'brand-9', 'Pepsi', 6200),
              percentageInTenths: 1000,
            ),
        isFalse,
      );
      expect(
        line ==
            ReportBrandLine(brand: line.brand, percentageInTenths: 999),
        isFalse,
      );
    });

    test('ReportTypeLine covers all three fields', () {
      ReportBrandLine coke() => ReportBrandLine(
        brand: brand('type-1', 'brand-1', 'Coca-Cola', 6200),
        percentageInTenths: 1000,
      );
      final line = ReportTypeLine(
        type: type('type-1', 'cat-1', 'Refrigerante', 6200),
        percentageInTenths: 1000,
        brands: [coke()].lock,
      );
      final same = ReportTypeLine(
        type: type('type-1', 'cat-1', 'Refrigerante', 6200),
        percentageInTenths: 1000,
        brands: [coke()].lock,
      );

      expect(line, same);
      expect(line.hashCode, same.hashCode);

      expect(
        line ==
            ReportTypeLine(
              type: type('type-9', 'cat-1', 'Refrigerante', 6200),
              percentageInTenths: line.percentageInTenths,
              brands: line.brands,
            ),
        isFalse,
      );
      expect(
        line ==
            ReportTypeLine(
              type: line.type,
              percentageInTenths: 999,
              brands: line.brands,
            ),
        isFalse,
      );
      expect(
        line ==
            ReportTypeLine(
              type: line.type,
              percentageInTenths: line.percentageInTenths,
              brands: const IList<ReportBrandLine>.empty(),
            ),
        isFalse,
      );
    });

    test('ReportSection covers all three fields', () {
      final section = ReportSection(
        category: category('cat-1', 'Bebidas', 6200),
        percentageInTenths: 400,
        types: const IList<ReportTypeLine>.empty(),
      );
      final same = ReportSection(
        category: category('cat-1', 'Bebidas', 6200),
        percentageInTenths: 400,
        types: const IList<ReportTypeLine>.empty(),
      );

      expect(section, same);
      expect(section.hashCode, same.hashCode);

      expect(
        section ==
            ReportSection(
              category: category('cat-2', 'Bebidas', 6200),
              percentageInTenths: 400,
              types: const IList<ReportTypeLine>.empty(),
            ),
        isFalse,
      );
      expect(
        section ==
            ReportSection(
              category: section.category,
              percentageInTenths: 401,
              types: const IList<ReportTypeLine>.empty(),
            ),
        isFalse,
      );
      expect(
        section ==
            ReportSection(
              category: section.category,
              percentageInTenths: 400,
              types: [
                ReportTypeLine(
                  type: type('type-1', 'cat-1', 'Refrigerante', 6200),
                  percentageInTenths: 1000,
                  brands: const IList<ReportBrandLine>.empty(),
                ),
              ].lock,
            ),
        isFalse,
      );
    });
  });
}
