import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/period_report.dart';
import '../../../domain/models/report_section.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/main_menu.dart';
import '../../core/widgets/message_view.dart';
import '../../device_user/widgets/who_is_using_dialog.dart';
import '../view_model/report_view_model.dart';
import 'period_bar.dart';
import 'report_detail.dart';
import 'report_summary.dart';

/// Screen 5, the **Resumo** tab — `/reports`, where the money went (H11) and
/// how much of the period each category took (H12).
///
/// **There is no `TabBar` here, and that is deliberate**: `handoff §H11` says
/// screen 5 opens "com uma aba só, e não com uma aba vazia esperando". The
/// price-comparison tab arrives with H16.
///
/// A `ConsumerStatefulWidget` because `_showByType` is state of the SCREEN and
/// not of the ViewModel: which of the two views is on display survives no
/// reload and is nobody else's business.
///
/// It carries the `≡` and the `👤` of screen 1 — the wireframe draws the same
/// header — and **no Back button**: `/reports` is one of the three permanent
/// destinations of the bottom bar, and switching between them is not going
/// back.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _showByType = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenu.show(context),
        ),
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Quem está usando',
            onPressed: () => showWhoIsUsingDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            // It reports the failure, unlike the pull-to-refresh below only
            // in where it takes the messenger from: with a report already on
            // screen a failed reload changes NOTHING visible, and a tap that
            // does nothing and does not say why is what the `handoff`
            // forbids.
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final error = await ref
                  .read(reportViewModelProvider.notifier)
                  .refresh();
              if (error != null) {
                messenger.showSnackBar(SnackBar(content: Text(error)));
              }
            },
          ),
        ],
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
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
                // Scrollable in EVERY state — that is what MessageView is
                // for; a plain Center kills the pull to refresh exactly on
                // the error screen, where it is used most.
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
                    showByType: _showByType,
                    onToggle: () => setState(() => _showByType = !_showByType),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomBar(current: Routes.reports),
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
    required this.showByType,
    required this.onToggle,
  });

  final PeriodReport report;
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
          );
  }
}
