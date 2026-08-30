import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/money.dart';
import '../../../domain/models/report_section.dart';
import '../../core/formatting.dart';

/// The closed view of screen 5: one line per category with its share of the
/// period, the total, and the door to the breakdown.
///
/// ```
/// Carnes                     R$ 480,00   (40%)
/// Limpeza                    R$ 360,00   (30%)
/// ─────────────────────────────────────────────
/// Total do período           R$ 1.200,00
///           [ Ver por tipo de produto ]
/// ```
///
/// It reads NO provider: the sections and the total arrive already built, and
/// that is what lets its test run without a container.
class ReportSummary extends StatelessWidget {
  const ReportSummary({
    required this.sections,
    required this.total,
    required this.onShowDetail,
    this.capLine,
    super.key,
  });

  final IList<ReportSection> sections;

  /// The total of the period, which the H12 percentages are shares of.
  final Money total;

  final VoidCallback onShowDetail;

  /// H13's "Gastou R$ X de R$ Y", drawn above the first category — or null,
  /// which is a free interval or a month that had no cap. Whether it exists at
  /// all is the SCREEN's decision; this widget only places it.
  final Widget? capLine;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      ?capLine,
      for (final section in sections)
        ListTile(
          key: ValueKey('category-${section.category.categoryId}'),
          title: Text(section.category.name),
          // The percentage the domain computed, never divided again here.
          trailing: Text(
            '${formatMoney(section.category.spent)}   '
            '(${section.percentage}%)',
          ),
        ),
      const Divider(),
      ListTile(
        title: Text(
          'Total do período',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Text(
          formatMoney(total),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: FilledButton(
          key: const ValueKey('show-detail'),
          onPressed: onShowDetail,
          child: const Text('Ver por tipo de produto'),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
