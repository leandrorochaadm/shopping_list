import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/period_report.dart';
import '../../../domain/models/report_section.dart';
import '../../../domain/models/spending_cap.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/widgets/message_view.dart';
import '../../settings/view_model/spending_cap_view_model.dart';
import '../view_model/report_period_notifier.dart';
import '../view_model/report_view_model.dart';
import 'period_bar.dart';
import 'report_detail.dart';
import 'report_summary.dart';
import 'spending_cap_line.dart';

/// The **Resumo** tab of screen 5 — where the money went (H11) and how much of
/// the period each category took (H12).
///
/// It was the whole body of `ReportsScreen` until H16 gave the screen its
/// second tab. The [PeriodBar] and the spending cap came along with it, and
/// that is where both belong: the cap only exists for a whole month, and the
/// period is a concept of THIS tab — the comparison tab reads a rolling window
/// nobody chooses.
///
/// A `ConsumerStatefulWidget` because `_showByType` is state of the TAB and
/// not of the ViewModel: which of the two views is on display survives no
/// reload and is nobody else's business.
class ReportSummaryTab extends ConsumerStatefulWidget {
  const ReportSummaryTab({super.key});

  @override
  ConsumerState<ReportSummaryTab> createState() => _ReportSummaryTabState();
}

class _ReportSummaryTabState extends ConsumerState<ReportSummaryTab> {
  bool _showByType = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportViewModelProvider);
    final period = ref.watch(reportPeriodProvider);

    // The rule the wireframe's `*` states, ASKED of the domain (rule 11):
    // "Gastou X de Y" only exists when the period is a whole month, because
    // comparing an arbitrary slice with a monthly cap is a number with no
    // meaning.
    //
    // A CONDITIONAL `ref.watch`, and it is allowed: the ban on conditional
    // hooks is Flutter's, not Riverpod's — a dependency this build did not
    // register is simply not one.
    //
    // And it is watched IN PARALLEL with the report, never summed into it: a
    // failure to read the cap takes the line away and leaves the report
    // standing.
    final cap = period.wholeMonth == null
        ? null
        : ref.watch(spendingCapViewModelProvider(period)).value?.cap;

    // A Builder so the SnackBar finds a context BELOW the Scaffold, which is
    // the screen's, one level up.
    return Builder(
      builder: (context) => Column(
        children: [
          const PeriodBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final messenger = ScaffoldMessenger.of(context);
                final error = await ref
                    .read(reportViewModelProvider.notifier)
                    .refresh();
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                }
              },
              // Scrollable in EVERY state — that is what MessageView is for;
              // a plain Center kills the pull to refresh exactly on the error
              // screen, where it is used most.
              //
              // The `when !state.hasValue` guards are what keep a change of
              // period from ERASING the report being read: the reload is a
              // pure AsyncLoading, and Riverpod 3 keeps the previous value.
              child: switch (state) {
                AsyncLoading() when !state.hasValue => const _LoadingBody(),
                AsyncError(:final error) when !state.hasValue => _ErrorBody(
                  error: error,
                ),
                _ => _Body(
                  report: state.value!,
                  cap: cap,
                  showByType: _showByType,
                  onToggle: () => setState(() => _showByType = !_showByType),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
      MessageView('Somando as compras do período...'),
      Center(child: CircularProgressIndicator()),
    ],
  );
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      // The raw exception NEVER reaches the screen — it goes to debugPrint.
      MessageView(
        translateFailure(AppFailure.from(error), 'carregar o relatório'),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-report'),
          onPressed: () => ref.read(reportViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.report,
    required this.cap,
    required this.showByType,
    required this.onToggle,
  });

  final PeriodReport report;

  /// The cap in force in this month, or null — a free interval, a month that
  /// never had one, or a cap the read failed on.
  final SpendingCap? cap;
  final bool showByType;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [MessageView('Nenhuma compra lançada nesse período.')],
      );
    }

    // Built ONCE per frame, here, and handed down ready: a call inside each of
    // the two children would build the tree twice on every frame.
    final sections = buildReportSections(report);

    return showByType
        ? ReportDetail(sections: sections, onShowSummary: onToggle)
        : ReportSummary(
            sections: sections,
            total: report.total,
            onShowDetail: onToggle,
            // The "Gastou R$ X" is the total ALREADY on screen (D-k); the cap
            // only answers the "de R$ Y".
            capLine: cap == null
                ? null
                : SpendingCapLine(spent: report.total, cap: cap!),
          );
  }
}
