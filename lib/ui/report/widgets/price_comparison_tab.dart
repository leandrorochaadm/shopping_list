import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/money.dart';
import '../../../domain/models/price_comparison.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/product_option.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/widgets/message_view.dart';
import '../../purchase/widgets/product_field.dart';
import '../view_model/price_comparison_view_model.dart';

/// The **Comparação de preço** tab of screen 5 — where each product comes out
/// cheaper (H16), over the ROLLING window of three months.
///
/// **No [PeriodBar] here**: that window is not chosen, and drawing the two
/// date fields above it would promise a control that does nothing.
///
/// The widget re-implements no rule (rule 11): it asks the domain for the
/// groups of the picker (`buildComparisonGroups`), for what to offer
/// (`distinctOptionsOf`) and for the lines (`buildComparison`), and draws the
/// answer. Switching between the two views does NO I/O — it is the same
/// `IList<PriceQuote>` read another way.
class PriceComparisonTab extends ConsumerStatefulWidget {
  const PriceComparisonTab({super.key});

  @override
  ConsumerState<PriceComparisonTab> createState() => _PriceComparisonTabState();
}

class _PriceComparisonTabState extends ConsumerState<PriceComparisonTab> {
  ProductOption? _selected;
  ComparisonScope _scope = ComparisonScope.thisProduct;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceComparisonViewModelProvider);

    // A Builder so the SnackBar finds a context BELOW the Scaffold, which is
    // the screen's, one level up.
    return Builder(
      builder: (context) => RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          final error = await ref
              .read(priceComparisonViewModelProvider.notifier)
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
            quotes: state.value!,
            selected: _selected,
            scope: _scope,
            onSelected: (option) => setState(() => _selected = option),
            onScope: (scope) => setState(() => _scope = scope),
          ),
        },
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
      MessageView('Buscando os preços dos últimos 3 meses...'),
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
        translateFailure(
          AppFailure.from(error),
          'carregar a comparação de preço',
        ),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-comparison'),
          onPressed: () =>
              ref.read(priceComparisonViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.quotes,
    required this.selected,
    required this.scope,
    required this.onSelected,
    required this.onScope,
  });

  final IList<PriceQuote> quotes;
  final ProductOption? selected;
  final ComparisonScope scope;
  final ValueChanged<ProductOption> onSelected;
  final ValueChanged<ComparisonScope> onScope;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) {
      // The picker does NOT appear: there is nothing to choose.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          MessageView('Nenhuma compra nos últimos 3 meses.'),
        ],
      );
    }

    // All three of them the domain's, and all three built ONCE per frame.
    final options = distinctOptionsOf(quotes);
    final categoryNames = categoryNamesOf(quotes);
    final option = selected;
    final lines = option == null
        ? const IList<ComparisonLine>.empty()
        : buildComparison(quotes: quotes, selected: option, scope: scope);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ProductField(
          // Its own key: the two tabs coexist in the tree of the TabBarView,
          // and `field-product` would be found twice.
          fieldKey: const ValueKey('field-comparison-product'),
          options: options,
          // By CATEGORY and alphabetical, unlike screen 3 — there the
          // question is "pick fast what I am putting in the trolley", here it
          // is "find a product in a list that keeps growing".
          groupBy: (filtered) => buildComparisonGroups(
            options: filtered,
            categoryNames: categoryNames,
          ),
          hintText: 'Escolha um produto',
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        // The wireframe draws a pair of radios; this is the project's
        // Material 3 for a binary choice (decision D-t).
        SegmentedButton<ComparisonScope>(
          segments: [
            for (final value in ComparisonScope.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {scope},
          onSelectionChanged: (selection) => onScope(selection.first),
        ),
        const SizedBox(height: 16),
        if (option == null)
          const MessageView('Escolha um produto para comparar os mercados.')
        else ...[
          // Never empty: the picker only offers what `distinctOptionsOf`
          // found, so a chosen product always has at least one store.
          for (final line in lines) _ComparisonRow(line: line),
          // Decision D-n: the line APPEARS, and the sentence below it says
          // there is nothing to compare it with. Hiding the price it does
          // have would be hiding data.
          if (lines.length == 1)
            const MessageView(
              'Comprado em um mercado só nos últimos 3 meses — ainda não há '
              'com o que comparar.',
            ),
        ],
      ],
    );
  }
}

/// `Carrefour   R$ 11,43 /L   03/07` — one store, its price per base unit and
/// the day of the purchase that produced it.
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.line});

  final ComparisonLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(line.store.name)),
          Text(
            '${formatMoney(Money(line.costPerBaseUnit))}/'
            '${line.baseUnit.label}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 16),
          // The date INFORMS, it does not order (`requisitos §Regras`):
          // without it three prices look simultaneous when one is from
          // yesterday and another from seven weeks ago.
          Text(
            formatShortDate(line.purchasedOn),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
