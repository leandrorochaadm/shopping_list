import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/money.dart';
import '../../../domain/models/report_section.dart';
import '../../core/formatting.dart';

/// The open view of screen 5: the categories broken into product types, and
/// each type into its brands.
///
/// ```
/// Carnes                                  R$ 480,00
///   Acém moído        6 kg   R$ 32,00/kg  R$ 192,00   (40,0%)
///   Sabão em pó     6,8 kg   R$ 20,00/kg  R$ 136,00   (28,3%)   ▾
///     Omo           4,3 kg                 R$ 86,00   (63,2%)
///     Tixan         2,5 kg                 R$ 50,00   (36,8%)
/// ```
///
/// **The description of a registration never appears here** — `wireframes
/// §Tela 5` is explicit: what a report groups by is the type and the brand.
///
/// It reads NO provider: the sections arrive already built, ordered and
/// filtered by the domain.
class ReportDetail extends StatelessWidget {
  const ReportDetail({
    required this.sections,
    required this.onShowSummary,
    super.key,
  });

  final IList<ReportSection> sections;
  final VoidCallback onShowSummary;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      for (final section in sections) ...[
        ListTile(
          key: ValueKey('detail-category-${section.category.categoryId}'),
          title: Text(
            section.category.name,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          trailing: Text(
            formatMoney(section.category.spent),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final line in section.types) _TypeLine(line: line),
      ],
      const SizedBox(height: 8),
      Center(
        child: OutlinedButton(
          key: const ValueKey('show-summary'),
          onPressed: onShowSummary,
          child: const Text('Ver por categoria'),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}

/// One product type. It only offers the arrow when there is something to open
/// — the View ASKS `hasBrandBreakdown` (rule 11), and a type bought only
/// without a brand has not a single line to show (decision D-a).
class _TypeLine extends StatelessWidget {
  const _TypeLine({required this.line});

  final ReportTypeLine line;

  @override
  Widget build(BuildContext context) {
    final type = line.type;
    final title = Text(type.name);
    final trailing = Text(
      '${type.baseUnit.formatQuantity(type.quantityInBaseUnit)}   '
      '${formatMoney(Money(type.costPerBaseUnit))}/${type.baseUnit.label}   '
      '${formatMoney(type.spent)}   '
      '(${formatPercent(line.percentageInTenths)})',
    );

    if (!line.hasBrandBreakdown) {
      return ListTile(
        key: ValueKey('type-${type.productTypeId}'),
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        title: title,
        subtitle: trailing,
      );
    }

    return ExpansionTile(
      // The open state survives the rebuild a refresh or a period change
      // causes — without the key, every reload closes what was open.
      key: PageStorageKey('type-${type.productTypeId}'),
      tilePadding: const EdgeInsets.only(left: 32, right: 16),
      title: title,
      subtitle: trailing,
      children: [
        for (final brandLine in line.brands)
          ListTile(
            key: ValueKey(
              'brand-${type.productTypeId}-${brandLine.brand.brandId}',
            ),
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            title: Text(brandLine.brand.name!),
            trailing: Text(
              '${type.baseUnit.formatQuantity(brandLine.brand.quantityInBaseUnit)}   '
              '${formatMoney(brandLine.brand.spent)}   '
              '(${formatPercent(brandLine.percentageInTenths)})',
            ),
          ),
      ],
    );
  }
}
