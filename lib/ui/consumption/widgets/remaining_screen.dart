import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/monthly_average.dart';
import '../../../domain/models/shopping_list.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/online_status.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/main_menu.dart';
import '../../core/widgets/message_view.dart';
import '../../device_user/widgets/who_is_using_dialog.dart';
import '../../shopping_list/view_model/shopping_list_view_model.dart';
import '../../shopping_list/widgets/item_dialog.dart';
import '../view_model/monthly_average_view_model.dart';

/// Screen 6 — `/remaining`. How much of each type is still missing this month
/// against what they usually consume (H18).
///
/// The question is ONE: *o que ainda falta comprar neste mês, para bater o que
/// vocês costumam consumir?* It is not the shopping list and it is not the
/// suggestion — `faltam` here and `restam` on screen 1 are different numbers
/// and the two words never swap places.
///
/// **This screen never touches the list on its own.** It marks nothing, writes
/// nothing off and takes nothing out of anywhere: it shows numbers and opens
/// the dialog when a line is tapped. Whoever takes an item off the list is
/// still the purchase registered on screen 3.
///
/// No Back button: `/remaining` is one of the three permanent destinations of
/// the bottom bar, and switching between them is not going back.
class RemainingScreen extends ConsumerStatefulWidget {
  const RemainingScreen({super.key});

  @override
  ConsumerState<RemainingScreen> createState() => _RemainingScreenState();
}

class _RemainingScreenState extends ConsumerState<RemainingScreen> {
  /// Which of the two bands is open. It is state of the SCREEN — it survives
  /// no reload and is nobody else's business, the same as the `_scope` of the
  /// comparison tab.
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineStatusProvider);
    final state = ref.watch(monthlyAverageViewModelProvider);
    final month = ref.watch(monthlyAverageViewModelProvider.notifier).month;

    return Scaffold(
      appBar: AppBar(
        // No BackButton: this is a permanent destination, and a control that
        // navigates to the screen already on display does nothing.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenu.show(context),
        ),
        title: const Text('Falta comprar este mês'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Quem está usando',
            onPressed: () => showWhoIsUsingDialog(context, ref),
          ),
        ],
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await ref
                .read(monthlyAverageViewModelProvider.notifier)
                .refresh();
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
            }
          },
          // Scrollable in EVERY state — that is what MessageView is for; a
          // plain Center kills the pull to refresh exactly on the error state,
          // where it is used most.
          child: switch (state) {
            // **The only screen of the app that does not open offline**, and it
            // is the wireframe that says so: every number here comes from
            // outside the phone, and there is nothing to draw without them.
            // The `OnlineStatus` flips on its own when the browser comes back,
            // and the screen redraws with nobody tapping anything.
            _ when !online => const _OfflineBody(),
            AsyncLoading() when !state.hasValue => const _LoadingBody(),
            AsyncError(:final error) when !state.hasValue => _ErrorBody(
              error: error,
            ),
            _ => _Body(
              lines: state.value!,
              month: month.from,
              showAll: _showAll,
              onToggleShowAll: () => setState(() => _showAll = !_showAll),
            ),
          },
        ),
      ),
      bottomNavigationBar: const MainBottomBar(
        current: Routes.remainingThisMonth,
      ),
    );
  }
}

class _OfflineBody extends ConsumerWidget {
  const _OfflineBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const MessageView('Sem conexão — não é possível abrir agora.'),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-remaining-offline'),
          onPressed: () =>
              ref.read(monthlyAverageViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
      MessageView('Somando o que vocês já compraram este mês...'),
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
        translateFailure(AppFailure.from(error), 'carregar o que falta'),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-remaining'),
          onPressed: () =>
              ref.read(monthlyAverageViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.lines,
    required this.month,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final IList<MonthlyAverage> lines;
  final DateTime month;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      // The state of the first weeks: no history to take an average from, and
      // no button, because there is nothing a tap could do about it.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const MessageView(
            'Ainda não há compras suficientes para calcular a média.',
          ),
        ],
      );
    }

    final missing = lines.where((line) => line.hasShortage).toIList();
    final satisfied = lines.where((line) => !line.hasShortage).toIList();
    final items =
        ref.watch(shoppingListViewModelProvider).value ??
        const IList<ShoppingListItem>.empty();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            formatMonthYear(month),
            // The month is at the top because EVERY number on this screen is
            // its: on the turn, what was bought goes back to zero and each
            // "faltam" goes back to the whole average, on its own.
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (missing.isEmpty)
          // Not an empty state: they bought everything they usually buy. The
          // `[ Ver todos ]` stays standing, for whoever wants to add anyway.
          MessageView(
            'Vocês já compraram tudo que costumam comprar em '
            '${formatMonthName(month).toLowerCase()}.',
          )
        else
          for (final group in groupAveragesByCategory(missing))
            ..._groupTiles(context, ref, group, items, missing: true),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            key: const ValueKey('toggle-show-all'),
            onPressed: onToggleShowAll,
            child: Text(
              showAll
                  ? 'Mostrar só o que falta'
                  // The count comes from the very list the band draws, so the
                  // two can never disagree — a count that did not match is what
                  // version 2.0 of the wireframes had to fix.
                  : 'Ver todos (${satisfied.length} sem faltar)',
            ),
          ),
        ),
        if (showAll) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              // Not "já atingiram a média": the yoghurt that arrived this month
              // has the purchase itself for an average, so there was no target
              // to reach — and nothing is missing of it all the same.
              'NADA FALTANDO ESTE MÊS',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (satisfied.isEmpty)
            const MessageView('Está faltando de tudo o que vocês compram.')
          else
            for (final group in groupAveragesByCategory(satisfied))
              ..._groupTiles(context, ref, group, items, missing: false),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// One category header and its lines — the same shape in both bands, because
  /// `wireframes §Tela 6` groups the two the same way.
  List<Widget> _groupTiles(
    BuildContext context,
    WidgetRef ref,
    MonthlyAverageGroup group,
    IList<ShoppingListItem> items, {
    required bool missing,
  }) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        group.category.name,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
    for (final line in group.lines)
      _RemainingTile(line: line, items: items, missing: missing),
  ];
}

/// One type: what is missing of it, and what the list is asking for underneath.
class _RemainingTile extends ConsumerWidget {
  const _RemainingTile({
    required this.line,
    required this.items,
    required this.missing,
  });

  final MonthlyAverage line;
  final IList<ShoppingListItem> items;
  final bool missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeId = line.type.id;
    // The open item of this type, and the OLDEST one when there is more than
    // one (E-i) — it is where "editando o item que já existe, nunca criando um
    // segundo" is actually decided.
    final existing = typeId == null ? null : findOpenItemOfType(items, typeId);

    return ListTile(
      key: typeId == null ? null : ValueKey('remaining-$typeId'),
      title: Text(line.type.name),
      // What the list is asking for, and it may differ from the number above
      // on purpose: the leite asks 6 L on the list while the average says they
      // consume 8 L. It is the reader who decides which to follow.
      subtitle: existing == null ? null : Text(existing.listStatusLabel),
      trailing: Text(
        missing
            ? 'faltam ${line.remainingLabel}'
            : line.consumedOverAverageLabel,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      // The SAME dialog of screen 1, already filled in — the screen informs and
      // then hands over; it does not act on its own.
      onTap: () => ItemDialog.showForType(
        context,
        type: line.type,
        category: line.category,
        // Null in the bottom band: nothing is missing there, and a prefilled
        // `0` would make saving throw `InvalidQuantity`.
        missing: line.prefillQuantity,
        existing: existing,
      ),
    );
  }
}
