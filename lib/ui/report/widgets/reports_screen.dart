import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/main_menu.dart';
import '../../device_user/widgets/who_is_using_dialog.dart';
import '../view_model/price_comparison_view_model.dart';
import '../view_model/report_view_model.dart';
import 'price_comparison_tab.dart';
import 'report_summary_tab.dart';

/// Screen 5 — `/reports`. **Two tabs since H16**, and it is now that the
/// `TabBar` is born: until here the screen opened "com uma aba só, e não com
/// uma aba vazia esperando" (`handoff §H11`).
///
///   * **Resumo** — where the money went (H11) and how much of the period each
///     category took (H12). It is the one carrying the `PeriodBar`, because it
///     is the one answering for a free period.
///   * **Comparação de preço** — where each product comes out cheaper (H16).
///     **No `PeriodBar`**: its window is rolling, three months long, and
///     nobody chooses it.
///
/// No Back button: `/reports` is one of the three permanent destinations of
/// the bottom bar, and switching between them is not going back.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  /// A `TabController` of its own, and **not a `DefaultTabController`**: the
  /// `↻` of the `AppBar` has to know which tab is in front in order to reload
  /// the right ViewModel, and a `DefaultTabController` only hands its
  /// controller to a DESCENDANT — which would need a `Builder` between the
  /// `Scaffold` and the `AppBar`.
  ///
  /// `AutomaticKeepAliveClientMixin` does not come in: both tabs keep the
  /// little they have in providers, not in fragile local state, and letting
  /// the `TabBarView` drop and rebuild them is the right behaviour.
  late final TabController _controller = TabController(length: 2, vsync: this)
    // Without this the `↻` keeps pointing at whichever tab was in front when
    // the screen was built.
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The `↻` reloads the tab IN FRONT — reloading both would be two round
  /// trips for a button the user pressed once.
  Future<String?> _reloadCurrentTab() => _controller.index == 0
      ? ref.read(reportViewModelProvider.notifier).refresh()
      : ref.read(priceComparisonViewModelProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) => Scaffold(
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
          // It reports the failure, unlike the pull-to-refresh of each tab
          // only in where it takes the messenger from: with something already
          // on screen a failed reload changes NOTHING visible, and a tap that
          // does nothing and does not say why is what the `handoff` forbids.
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await _reloadCurrentTab();
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
      ],
      bottom: TabBar(
        controller: _controller,
        tabs: const [
          Tab(text: 'Resumo'),
          Tab(text: 'Comparação de preço'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _controller,
      children: const [ReportSummaryTab(), PriceComparisonTab()],
    ),
    bottomNavigationBar: const MainBottomBar(current: Routes.reports),
  );
}
