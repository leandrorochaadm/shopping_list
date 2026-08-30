import 'package:flutter/material.dart';

import '../../../domain/models/money.dart';
import '../../../domain/models/spending_cap.dart';
import '../../core/formatting.dart';

/// "Gastou R$ 1.200,00 de R$ 1.500,00" — the one line H13 puts on screen 5.
///
/// [spent] is the `PeriodReport.total` the screen already has (D-k): adding
/// the month up a second time, by a second path, is how a report starts
/// disagreeing with itself.
///
/// It reads NO provider — the two numbers arrive already decided, which is
/// what lets its test run without a container.
class SpendingCapLine extends StatelessWidget {
  const SpendingCapLine({
    required this.spent,
    required this.cap,
    super.key,
  });

  final Money spent;
  final SpendingCap cap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('cap-line'),
    title: Text(
      'Gastou ${formatMoney(spent)} de ${formatMoney(cap.amount)}',
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}
