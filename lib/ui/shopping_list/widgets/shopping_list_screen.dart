import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/shopping_list.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../../routing/routes.dart';
import '../../core/error_translation.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/message_view.dart';
import '../../core/widgets/pending_destinations.dart';
import '../../device_user/view_model/device_user_view_model.dart';
import '../../device_user/widgets/device_user_options.dart';
import '../view_model/pending_changes_notifier.dart';
import '../view_model/shopping_list_view_model.dart';
import 'add_item_panel.dart';
import 'item_dialog.dart';
import 'shopping_list_menu.dart';
import 'shopping_list_tile.dart';

/// Screen 1 — the shared list, grouped by category, that **warns instead of
/// moving** when the other phone changed something.
///
/// A `ConsumerWidget`: no form state lives here. The line is read-only, and
/// everything that gets typed lives in the panel or in the dialog.
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shoppingListViewModelProvider);
    final banner = ref.watch(pendingChangesProvider).label;

    return Scaffold(
      appBar: AppBar(
        // No BackButton: the list is the root, and a control that navigates to
        // the screen already on display does nothing.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => ShoppingListMenu.show(context),
        ),
        title: const Text('Lista de compras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Quem está usando',
            onPressed: () => _askWhoIsUsing(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () =>
                ref.read(shoppingListViewModelProvider.notifier).refresh(),
          ),
        ],
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => Column(
          children: [
            if (banner != null) _Banner(label: banner),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await ref
                      .read(shoppingListViewModelProvider.notifier)
                      .refresh();
                  if (error != null) {
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  }
                },
                // The child is scrollable in EVERY state — that is what
                // MessageView exists for; a plain Center kills the pull to
                // refresh exactly on the error screen, where it is used most.
                child: switch (state) {
                  AsyncLoading() when !state.hasValue => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  AsyncError(:final error, :final stackTrace)
                      when !state.hasValue =>
                    _ErrorBody(error: error, stackTrace: stackTrace),
                  _ => _Body(items: state.value!),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomBar(current: Routes.shoppingList),
    );
  }

  /// The same `DeviceUserOptions` picker H1 wrote — written a third time it
  /// would be three touch targets drifting apart.
  static Future<void> _askWhoIsUsing(BuildContext context, WidgetRef ref) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Quem está usando?'),
          content: Consumer(
            builder: (context, ref, _) => DeviceUserOptions(
              selected: ref.watch(deviceUserViewModelProvider).value?.name,
              onChanged: (name) async {
                if (name == null) return;
                final navigator = Navigator.of(dialogContext);
                await ref
                    .read(deviceUserViewModelProvider.notifier)
                    .save(name);
                navigator.pop();
              },
            ),
          ),
        ),
      );
}

/// What arrived from the other phone. **Nothing moves until it is tapped** —
/// that is the requirement the story is named after.
class _Banner extends ConsumerWidget {
  const _Banner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      child: Material(
        color: scheme.secondaryContainer,
        child: InkWell(
          onTap: () {
            // Clear BEFORE the refresh, never after: an event that arrives
            // during the round trip has to keep counting, and a clear at the
            // end would erase it — the banner would vanish with a change the
            // screen has not shown yet.
            ref.read(pendingChangesProvider.notifier).clear();
            ref.read(shoppingListViewModelProvider.notifier).refresh();
          },
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      // The raw exception NEVER reaches the screen — it goes to debugPrint.
      MessageView(translateFailure(AppFailure.from(error), 'abrir a lista')),
      Center(
        child: FilledButton(
          onPressed: () =>
              ref.read(shoppingListViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.items});

  final IList<ShoppingListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const MessageView('Sua lista está vazia.'),
          Center(
            child: Column(
              children: [
                FilledButton(
                  onPressed: () => AddItemPanel.show(context),
                  child: const Text('Adicionar item'),
                ),
                const SizedBox(height: 8),
                _PendingButton(
                  route: Routes.suggestions,
                  label: 'Sugerir itens',
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final group in groupByCategory(items)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              group.category.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final item in group.items)
            ShoppingListTile(
              key: ValueKey(item.id),
              item: item,
              onTogglePicked: () => ref
                  .read(shoppingListViewModelProvider.notifier)
                  .togglePicked(item),
              onOpen: () => ItemDialog.show(context, item),
            ),
        ],
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              FilledButton.icon(
                onPressed: () => AddItemPanel.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar item'),
              ),
              const SizedBox(height: 8),
              _PendingButton(route: Routes.suggestions, label: 'Sugerir itens'),
              const SizedBox(height: 8),
              _PendingButton(
                route: Routes.newPurchase,
                label: 'Lançar compra',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A destination that does not exist yet: greyed out, and it SAYS which story
/// brings it. Never a tap that does nothing and does not explain why.
class _PendingButton extends StatelessWidget {
  const _PendingButton({required this.route, required this.label});

  final String route;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pendingDestinations[route]!)),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).disabledColor,
    ),
    child: Text(label),
  );
}
