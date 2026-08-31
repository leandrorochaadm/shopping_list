import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/monthly_average.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/widgets/message_view.dart';
import '../../shopping_list/view_model/shopping_list_view_model.dart';
import '../view_model/monthly_average_view_model.dart';

/// Screen 2 — `/suggestions`. What they usually buy, with the quantity already
/// worked out, so the list does not depend on anybody's memory (H17).
///
/// It offers **every type bought at least once in the closed window**, plus
/// the one born in the month in progress — nothing is filtered for being a
/// rare purchase, because "quem decide o que é rotina é ele, olhando a lista".
///
/// **It opens with everything unticked**, and that is a written criterion:
/// `[ Adicionar selecionados ]` over a fully ticked list would tip the whole
/// suggestion into the list with one tap, which is the opposite of the rule
/// above.
///
/// It has an exit of its own (`R11`): screen 1 pushes it, so the Back button
/// pops back to the list — and so does adding.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  /// The chosen type ids. It is state of the SCREEN: which lines are ticked
  /// survives no reload and is nobody else's business.
  final _selected = <String>{};

  bool _adding = false;

  /// Which types are already on the list — repeating an item helps nobody in
  /// an aisle, and it is the `{–}` of the wireframe. It includes the one
  /// marked "não encontrei", which is still on the list.
  IMap<String, ShoppingListItem> _onTheList() {
    final items =
        ref.watch(shoppingListViewModelProvider).value ??
        const IList<ShoppingListItem>.empty();
    return {
      for (final item in items)
        if (item.isOpen && item.type.id != null) item.type.id!: item,
    }.lock;
  }

  Future<void> _add(IList<MonthlyAverage> lines) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _adding = true);
    // One action, ONE guard: `add` in a loop would be swallowed by the
    // reentrancy guard from the second call on, and a `null` back would read
    // as success.
    final error = await ref
        .read(shoppingListViewModelProvider.notifier)
        .addMany(lines);
    if (!mounted) return;

    setState(() => _adding = false);
    if (error != null) {
      // What went in stayed in — the lines that made it come back locked on
      // the next frame, so there is nothing to count here.
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // `pop`, not `go`: screen 1 pushed this one, and the wireframe sends it
    // back there.
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthlyAverageViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        // R11: in a standalone PWA there is no browser Back button. Arriving
        // from screen 1 there is a stack to pop; arriving by a pasted link
        // there is not, and the way out is the house.
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
        title: const Text('Sugestão de itens'),
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
            AsyncLoading() when !state.hasValue => const _LoadingBody(),
            AsyncError(:final error) when !state.hasValue => _ErrorBody(
              error: error,
            ),
            _ => _Body(
              lines: state.value!,
              onTheList: _onTheList(),
              selected: _selected,
              adding: _adding,
              onToggle: (typeId, chosen) => setState(() {
                if (chosen) {
                  _selected.add(typeId);
                } else {
                  _selected.remove(typeId);
                }
              }),
              onAdd: _add,
            ),
          },
        ),
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
      MessageView('Calculando o que vocês costumam comprar...'),
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
        translateFailure(AppFailure.from(error), 'carregar a sugestão'),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-suggestions'),
          onPressed: () =>
              ref.read(monthlyAverageViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.lines,
    required this.onTheList,
    required this.selected,
    required this.adding,
    required this.onToggle,
    required this.onAdd,
  });

  final IList<MonthlyAverage> lines;
  final IMap<String, ShoppingListItem> onTheList;
  final Set<String> selected;
  final bool adding;
  final void Function(String typeId, bool chosen) onToggle;
  final void Function(IList<MonthlyAverage>) onAdd;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      // No action button here, and it is what the wireframe draws: there is
      // nothing to suggest and nothing a tap could do about it.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          MessageView('Ainda não há compras suficientes para sugerir nada.'),
        ],
      );
    }

    final chosen = lines
        .where((line) => selected.contains(line.type.id))
        .toIList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Baseado no que compraram nos três meses fechados anteriores.',
          ),
        ),
        // By CATEGORY and alphabetical inside it — the same organization
        // screen 1 uses, so the suggestion is read in the order the aisle is
        // walked. Never "do mais comprado para o menos comprado": 12 unidades
        // de papel higiênico não são "mais" que 5 kg de arroz.
        for (final group in groupAveragesByCategory(lines)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              group.category.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final line in group.lines)
            _SuggestionTile(
              line: line,
              // `?[]` because a type with no id has not been written yet.
              listItem: line.type.id == null ? null : onTheList[line.type.id!],
              selected: selected.contains(line.type.id),
              enabled: !adding,
              onToggle: onToggle,
            ),
        ],
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            key: const ValueKey('add-selected'),
            // Nothing ticked is nothing to do — and a tap that does nothing
            // and does not say why is what the `handoff` forbids, so the
            // button is plainly disabled instead.
            onPressed: chosen.isEmpty || adding ? null : () => onAdd(chosen),
            child: Text(adding ? 'Adicionando...' : 'Adicionar selecionados'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One line: the type, the suggested quantity, and a tick — unless it is
/// already on the list, and then it is locked.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.line,
    required this.listItem,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final MonthlyAverage line;
  final ShoppingListItem? listItem;
  final bool selected;
  final bool enabled;
  final void Function(String typeId, bool chosen) onToggle;

  @override
  Widget build(BuildContext context) {
    final onTheList = listItem != null;
    final typeId = line.type.id;

    return CheckboxListTile(
      key: typeId == null ? null : ValueKey('suggestion-$typeId'),
      // With no average there is no quantity to offer (E-j): the line still
      // appears — nothing is filtered for being a rare purchase — and goes in
      // with no quantity, leaving the list on the first purchase of the type.
      title: Text(
        line.hasAverage
            ? '${line.type.name} — ${line.averageLabel}'
            : line.type.name,
      ),
      subtitle: switch (listItem) {
        // The `{–}` of the wireframe, in its two shapes. The one marked "não
        // encontrei" is still on the list, so it is locked all the same.
        final item? when item.notFound => const Text('(não encontrei)'),
        final _? => const Text('(já está na lista)'),
        null => null,
      },
      value: onTheList ? false : selected,
      // Locked: it does not answer the tap and cannot be added again.
      onChanged: onTheList || !enabled || typeId == null
          ? null
          : (chosen) => onToggle(typeId, chosen ?? false),
    );
  }
}
