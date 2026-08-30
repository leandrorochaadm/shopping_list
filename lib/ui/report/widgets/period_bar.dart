import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/report_period.dart';
import '../../core/formatting.dart';
import '../view_model/report_period_notifier.dart';

/// The period selector of screen 5: two month shortcuts over two date fields.
///
/// ```
/// ‹ Julho        Agosto/2026        Setembro ›
/// Período:  ▤ 01/08/2026   a   ▤ 31/08/2026
/// ```
///
/// **The two shortcuts are a deliberate divergence from `wireframes §Tela 5`**
/// (decision D-b), which draws only the two date fields. Reading the month
/// before is the most frequent question this screen answers, and two taps on a
/// calendar to ask it is the friction the shortcut removes. Removing them
/// again is deleting one widget.
///
/// Two things about them are rules, not looks:
///
///   * starting from a FREE interval — 10/08 to 20/08 — `‹` gives back the
///     whole of July, never eleven days of it. It is what the label promises,
///     and it is what makes `‹` and `›` reversible between themselves.
///   * `›` stops at the current month (decision D-d), because there is no
///     report of tomorrow. The screen ASKS
///     [ReportPeriod.canShiftForward] — it does not compare years and months
///     inside `build()` (rule 11) — and it is not cosmetic: while the period
///     does not pass the current month, `from <= today`, which is exactly the
///     `!initialDate.isAfter(lastDate)` assert of `showDatePicker`. Enabling
///     `›` without touching `lastDate` is a crash, not an empty report.
class PeriodBar extends ConsumerWidget {
  const PeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);
    final today = notifier.today;
    final canGoForward = period.canShiftForward(today);
    // The end of the month in progress, not today: the report opens on the
    // WHOLE current month, so its own 31/08 has to be a day the picker can
    // show. The View asks the domain for it (rule 11).
    final lastSelectable = ReportPeriod.latestSelectableDay(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthShortcut(
                key: const ValueKey('previous-month'),
                icon: Icons.chevron_left,
                label: formatMonthName(period.shiftedByMonths(-1).from),
                onPressed: () => notifier.shiftMonth(-1),
              ),
              Text(
                formatMonthYear(period.from),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _MonthShortcut(
                key: const ValueKey('next-month'),
                icon: Icons.chevron_right,
                iconFirst: false,
                label: formatMonthName(period.shiftedByMonths(1).from),
                onPressed: canGoForward ? () => notifier.shiftMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Período:'),
              _DayField(
                key: const ValueKey('period-from'),
                tooltip: 'Data inicial do período',
                day: period.from,
                lastDay: lastSelectable,
                onPicked: (picked) =>
                    _report(context, notifier.setFrom(picked)),
              ),
              const Text('a'),
              _DayField(
                key: const ValueKey('period-to'),
                tooltip: 'Data final do período',
                day: period.to,
                lastDay: lastSelectable,
                onPicked: (picked) => _report(context, notifier.setTo(picked)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `‹ Julho` and `Setembro ›`. A `TextButton.icon` and not an `IconButton`,
/// because the month name is the label a screen reader has to read out — the
/// arrow alone says nothing.
class _MonthShortcut extends StatelessWidget {
  const _MonthShortcut({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconFirst = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool iconFirst;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: iconFirst ? 'Mês anterior: $label' : 'Mês seguinte: $label',
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      iconAlignment: iconFirst ? IconAlignment.start : IconAlignment.end,
    ),
  );
}

/// One end of the interval. It opens `showDatePicker`, and the two bounds it
/// takes are not decoration: the API REQUIRES both, and passing them wrong is
/// an assert, not a wrong result.
class _DayField extends StatelessWidget {
  const _DayField({
    required this.tooltip,
    required this.day,
    required this.lastDay,
    required this.onPicked,
    super.key,
  });

  final String tooltip;
  final DateTime day;

  /// The last day the picker offers — the end of the month in progress
  /// ([ReportPeriod.latestSelectableDay]). There is no report of NEXT month,
  /// and that is the bound [ReportPeriod.canShiftForward] keeps the period
  /// inside of.
  final DateTime lastDay;

  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) => Tooltip(
    // Also the semantic label: a screen reader must not have to tap to find
    // out which end of the interval this is.
    message: tooltip,
    child: TextButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: day,
          // A constant of the DOMAIN, not a number loose in a widget
          // (rule 6): a bound that walked with the clock would hide, in the
          // sixth year of use, a purchase that is in the database.
          firstDate: ReportPeriod.earliestSelectableDay,
          lastDate: lastDay,
        );
        if (picked != null) onPicked(picked);
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(formatDate(day)),
      style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
    ),
  );
}

/// An inverted interval is refused by the domain and SAID on the screen — the
/// period stays as it was, which is why this is a SnackBar and not a state.
void _report(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
