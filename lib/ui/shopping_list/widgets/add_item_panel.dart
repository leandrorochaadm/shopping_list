import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/product_type_group.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../catalog/view_model/catalog_view_model.dart';
import '../../catalog/widgets/new_product_type_dialog.dart';
import '../../core/widgets/message_view.dart';
import '../view_model/shopping_list_view_model.dart';

/// The `#1a` panel — **the most used path of the app**, more than registering
/// a purchase. Everything here is measured in taps.
///
/// It is a bottom sheet with `isScrollControlled`, which is the `══` of the
/// wireframe and what lets the keyboard come up without covering the results.
class AddItemPanel extends ConsumerStatefulWidget {
  const AddItemPanel({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const AddItemPanel(),
  );

  @override
  ConsumerState<AddItemPanel> createState() => _AddItemPanelState();
}

class _AddItemPanelState extends ConsumerState<AddItemPanel> {
  final _controller = TextEditingController();

  /// Read ONCE, in initState, and kept here: redoing it on every keystroke
  /// would be one round trip per letter.
  IMap<String, int> _counts = const IMap.empty();

  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final counts = await ref
        .read(catalogViewModelProvider.notifier)
        .purchaseCountsByType();
    if (!mounted) return;
    setState(() => _counts = counts);
  }

  /// Which types are already on the list — repeating an item helps nobody in
  /// an aisle.
  Set<String> get _onTheList {
    final items =
        ref.watch(shoppingListViewModelProvider).value ??
        const IList<ShoppingListItem>.empty();
    return {for (final item in items) ?item.type.id};
  }

  Future<void> _add(ProductType type, IList<Category> categories) async {
    final category = categories
        .where((entry) => entry.id == type.categoryId)
        .firstOrNull;
    // If the category is not in the list yet the panel reloads instead of
    // guessing: the line carries the whole category (D4).
    if (category == null) {
      await ref.read(catalogViewModelProvider.notifier).refresh();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _working = true);
    final error = await ref
        .read(shoppingListViewModelProvider.notifier)
        .add(type, category);
    if (!mounted) return;

    setState(() => _working = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  Future<void> _reactivate(ProductType type, IList<Category> categories) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _working = true);
    final error = await ref
        .read(catalogViewModelProvider.notifier)
        .reactivateType(type);
    if (!mounted) return;

    setState(() => _working = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _add(type.reactivated(), categories);
  }

  Future<void> _create(IList<Category> categories) async {
    final created = await NewProductTypeDialog.show(
      context,
      ref,
      initialName: _controller.text.trim(),
      confirmLabel: 'Criar e adicionar',
    );
    if (!mounted || created == null) return;

    // The category the type was just created with is already in the options —
    // the CatalogViewModel puts it in the state before the dialog closes.
    await _add(
      created,
      ref.read(catalogViewModelProvider).value?.categories ?? categories,
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(catalogViewModelProvider);
    final typed = _controller.text.trim();

    return Padding(
      // What lifts the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_working,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Flexible(
              child: switch (options) {
                AsyncLoading() when !options.hasValue => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Buscando...'),
                ),
                AsyncError() when !options.hasValue => _RetryMessage(
                  onRetry: () =>
                      ref.read(catalogViewModelProvider.notifier).refresh(),
                ),
                _ => _results(options.value!, typed),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(CatalogOptions options, String typed) {
    final matches = _matching(options.types, typed);
    final onTheList = _onTheList;

    if (matches.isEmpty && options.types.isEmpty && typed.isEmpty) {
      return const MessageView('Nenhum tipo cadastrado ainda.');
    }

    return ListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final group in groupTypesByCategory(
          matches,
          options.categories,
        ))
          ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                group.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final type in group.types)
              _typeTile(type, options, onTheList.contains(type.id)),
          ],
        // Nothing matched — and the search is what names the new type.
        if (typed.isNotEmpty && !_hasExactMatch(matches, typed))
          ListTile(
            key: const ValueKey('create-type'),
            leading: const Icon(Icons.add),
            title: Text('Criar "$typed"'),
            onTap: _working ? null : () => _create(options.categories),
          ),
      ],
    );
  }

  Widget _typeTile(ProductType type, CatalogOptions options, bool onList) {
    if (onList) {
      return ListTile(
        enabled: false,
        title: Text(type.name),
        subtitle: const Text('(já está na lista)'),
        trailing: const Icon(Icons.remove),
      );
    }
    if (!type.active) {
      // Decision B3: never a second type with the same name — the history the
      // soft delete preserves would be split in two.
      return ListTile(
        title: Text(type.name),
        subtitle: const Text('(desativado)'),
        trailing: TextButton(
          onPressed: _working
              ? null
              : () => _reactivate(type, options.categories),
          child: const Text('Reativar'),
        ),
      );
    }
    return ListTile(
      title: Text(type.name),
      onTap: _working ? null : () => _add(type, options.categories),
    );
  }

  /// The search compares NORMALIZED on both sides: whoever types "acem moido"
  /// finds "Acém moído" and does **not** create a second type. Whoever starts
  /// with the text comes before whoever merely contains it.
  IList<ProductType> _matching(IList<ProductType> types, String typed) {
    if (typed.isEmpty) {
      // Empty search: the most bought ones first, and — with no purchases,
      // which is today's state — everybody ties at 0 and it falls back to
      // alphabetical, which is the wanted result in the first weeks.
      return (types.where((type) => type.active).toList()..sort((a, b) {
            final byCount = _countOf(b).compareTo(_countOf(a));
            return byCount != 0 ? byCount : _byName(a, b);
          }))
          .toIList();
    }

    final needle = normalizeName(typed);
    final matches = types
        .where((type) => normalizeName(type.name).contains(needle))
        .toList();

    matches.sort((a, b) {
      final aStarts = normalizeName(a.name).startsWith(needle);
      final bStarts = normalizeName(b.name).startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return _byName(a, b);
    });
    return matches.toIList();
  }

  int _countOf(ProductType type) =>
      type.id == null ? 0 : _counts[type.id!] ?? 0;

  static int _byName(ProductType a, ProductType b) =>
      normalizeName(a.name).compareTo(normalizeName(b.name));

  static bool _hasExactMatch(IList<ProductType> matches, String typed) =>
      findNameConflict(matches, typed) != null;

}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Não foi possível carregar os tipos.'),
        const SizedBox(height: 8),
        FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
      ],
    ),
  );
}
