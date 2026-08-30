import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/purchase_summary.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/widgets/message_view.dart';
import '../view_model/purchase_history_view_model.dart';

/// The purchase history — `/purchases`, behind the `≡`, and the app's only
/// paginated screen (`tecnico §1.9`).
///
/// It is what turns a typo into something reversible: without a list of what
/// was registered there is no way to reach the correction screen at all.
class PurchaseHistoryScreen extends ConsumerWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseHistoryViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        // R11: in a standalone PWA there is no browser Back button. Arriving
        // from the `≡` there is a stack to pop; arriving by a pasted link
        // there is not, and the way out is the house.
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
        title: const Text('Histórico de compras'),
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await ref
                .read(purchaseHistoryViewModelProvider.notifier)
                .refresh();
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
            }
          },
          // Scrollable in EVERY state — that is what MessageView is for; a
          // plain Center kills the pull to refresh exactly on the error
          // screen, where it is used most.
          child: switch (state) {
            AsyncLoading() when !state.hasValue => const Center(
              child: CircularProgressIndicator(),
            ),
            AsyncError(:final error) when !state.hasValue => _ErrorBody(
              error: error,
            ),
            _ => _Body(state: state.value!),
          },
        ),
      ),
    );
  }
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
        translateFailure(AppFailure.from(error), 'abrir o histórico'),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-history'),
          onPressed: () =>
              ref.read(purchaseHistoryViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final PurchaseHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.purchases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [MessageView('Nenhuma compra lançada ainda.')],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final purchase in state.purchases)
          _PurchaseTile(key: ValueKey(purchase.id), purchase: purchase),
        const SizedBox(height: 8),
        if (state.loadingMore)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.hasMore)
          Center(
            child: OutlinedButton(
              key: const ValueKey('load-more'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final error = await ref
                    .read(purchaseHistoryViewModelProvider.notifier)
                    .loadMore();
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text('Carregar mais'),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, super.key});

  final PurchaseSummary purchase;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      '${formatDate(purchase.purchaseDate)} · ${purchase.storeName}',
    ),
    subtitle: Text('${formatMoney(purchase.total)} · ${purchase.registeredBy}'),
    trailing: const Icon(Icons.chevron_right),
    // `push`, never `go`: the twelve routes are declared FLAT, so go_router
    // builds no implicit stack out of the path — a `go` would replace this
    // screen and the correction would open with the house icon instead of a
    // Back button, losing the list the person came from.
    onTap: () => context.pushNamed(
      RouteNames.editPurchase,
      pathParameters: {'id': purchase.id},
    ),
  );
}
