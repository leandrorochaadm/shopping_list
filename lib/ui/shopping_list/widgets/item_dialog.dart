import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../catalog/view_model/catalog_view_model.dart';
import '../../core/unit_specs.dart';
import '../view_model/shopping_list_view_model.dart';

/// The item dialog of H6: quantity, preferred brand, preferred packaging,
/// "não encontrei" and remove.
///
/// **Two doors since H17**, and `wireframes §Tela 6` is what demands it — "o
/// **mesmo** diálogo de item da Tela 1":
///
///   * [ItemDialog.editing] — screen 1, and screen 6 on a type that is already
///     on the list. It EDITS the existing line, never creating a second one.
///   * [ItemDialog.creating] — screen 6 on a type that is not on the list yet.
///     There is no item to edit, so there is nothing to remove and nothing to
///     mark as not found: "marcar como não encontrado o que ninguém pediu não
///     quer dizer nada".
///
/// It has an exit of its own (`R11`): in an installed PWA there is no browser
/// Back button.
class ItemDialog extends ConsumerStatefulWidget {
  const ItemDialog._({
    this.item,
    required this.type,
    required this.category,
    this.prefilledQuantity,
    super.key,
  });

  /// Screen 1, and the "já está na lista" path of screen 6.
  ItemDialog.editing(ShoppingListItem item, {int? prefilledQuantity, Key? key})
    : this._(
        item: item,
        type: item.type,
        category: item.category,
        prefilledQuantity: prefilledQuantity,
        key: key,
      );

  /// Screen 6 on a type that is NOT on the list yet.
  const ItemDialog.creating({
    required ProductType type,
    required Category category,
    int? prefilledQuantity,
    Key? key,
  }) : this._(
         type: type,
         category: category,
         prefilledQuantity: prefilledQuantity,
         key: key,
       );

  /// Null in the creating mode — and it is what every branch below asks.
  final ShoppingListItem? item;

  /// Always present: in the editing mode it is the item's own, in the creating
  /// mode it is what screen 6 handed over. Reading it instead of
  /// `item!.type` is what lets the two modes share every widget below.
  final ProductType type;

  /// The same, and it is what `add` needs — the line carries the whole
  /// category (D4).
  final Category category;

  /// What screen 6 says is missing. **It wins over the stored quantity**: the
  /// dialog is being opened FROM that number.
  ///
  /// Null in the bottom band of screen 6 — nothing is missing there, and a
  /// prefilled `0` would make saving throw `InvalidQuantity`.
  final int? prefilledQuantity;

  /// Screen 1's door, unchanged in signature so its callers do not move.
  static Future<void> show(BuildContext context, ShoppingListItem item) =>
      showDialog<void>(
        context: context,
        builder: (context) => ItemDialog.editing(item),
      );

  /// Screen 6's door: it hands over the type, the category and what is
  /// missing, and this decides which of the two modes it is.
  ///
  /// [existing] comes from `findOpenItemOfType`, which is where the "nunca
  /// criando um segundo" of the wireframe is actually decided.
  static Future<void> showForType(
    BuildContext context, {
    required ProductType type,
    required Category category,
    int? missing,
    ShoppingListItem? existing,
  }) => showDialog<void>(
    context: context,
    builder: (context) => existing == null
        ? ItemDialog.creating(
            type: type,
            category: category,
            prefilledQuantity: missing,
          )
        : ItemDialog.editing(existing, prefilledQuantity: missing),
  );

  @override
  ConsumerState<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<ItemDialog> {
  late final TextEditingController _quantity = TextEditingController(
    // Filled with what is already stored, in the unit the field is typed in:
    // the whole number, never the large unit. Screen 6's prefill wins over
    // it — the dialog was opened from that number.
    text: switch (widget.prefilledQuantity ?? widget.item?.quantity) {
      final int amount => specOf(widget.type.baseUnit).format(amount),
      null => '',
    },
  );

  String? _brandId;
  String? _productId;
  late bool _notFound = widget.item?.notFound ?? false;

  IList<TypeLeaf> _leaves = const IList.empty();
  bool _loadingLeaves = true;
  bool _saving = false;
  String? _quantityError;

  /// The one branch the whole dialog turns on. In the creating mode there is
  /// no line yet: nothing to remove, nothing to mark as not found, and the
  /// save is an `add` instead of a `save`.
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _brandId = widget.item?.preferredBrand?.id;
    _productId = widget.item?.preferredProduct?.id;
    _loadLeaves();
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    final typeId = widget.type.id;
    if (typeId == null) {
      setState(() => _loadingLeaves = false);
      return;
    }

    // Through the ViewModel, never the repository (rule 4). A failure comes
    // back as an empty list — a list of packagings that did not load must not
    // stop the quantity from being adjusted, and the two dropdowns simply keep
    // "Qualquer uma".
    final leaves = await ref
        .read(catalogViewModelProvider.notifier)
        .leavesOfType(typeId);
    if (!mounted) return;
    setState(() {
      _leaves = leaves;
      _loadingLeaves = false;
    });
  }

  /// The brands that exist FOR THIS TYPE, from the leaves.
  IList<Brand> get _brands {
    final brands = ref.read(catalogViewModelProvider).value?.brands;
    if (brands == null) return const IList.empty();

    final ids = {for (final leaf in _leaves) ?leaf.registration.brandId};
    return brands.where((brand) => ids.contains(brand.id)).toIList();
  }

  /// The packagings of the type, filtered by the chosen brand when there is
  /// one — offering the Italac 1 L under "Coca-Cola" helps nobody.
  IList<Product> get _products => _leaves
      .where(
        (leaf) =>
            leaf.product.packaging != null &&
            (_brandId == null || leaf.registration.brandId == _brandId),
      )
      .map((leaf) => leaf.product)
      .toIList();

  Future<void> _save() async {
    final typed = _quantity.text.trim();

    // The EMPTY field stays null, and that is an answer: it is the "sai na
    // primeira compra do tipo" of the dialog. Only a filled one is read, and
    // the mask leaves nothing malformed to refuse — what is left is a field
    // holding zero.
    int? quantity;
    if (typed.isNotEmpty) {
      final parsed = specOf(widget.type.baseUnit).parse(typed);
      if (parsed <= 0) {
        // Under the field, never a SnackBar: it is an answer about what was
        // just typed, and it belongs next to what was typed.
        setState(() => _quantityError = 'Informe uma quantidade válida.');
        return;
      }
      quantity = parsed;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _quantityError = null;
    });

    final notifier = ref.read(shoppingListViewModelProvider.notifier);
    final item = widget.item;
    final error = item == null
        // The creating mode of screen 6. **The two dropdowns above are read
        // and DISCARDED here** (decision E-k): `add` builds the item with no
        // preferences, and the way back is two optional named parameters on
        // it. It is a field that accepts and does not store, and it is written
        // down rather than hidden — hiding the dropdowns would diverge from
        // "o mesmo diálogo de item da Tela 1" that the wireframe demands.
        ? await notifier.add(widget.type, widget.category, quantity: quantity)
        : await notifier.save(
            item.copyWith(
              quantity: quantity,
              clearQuantity: quantity == null,
              preferredBrand: _brandId == null
                  ? null
                  : _brands.where((b) => b.id == _brandId).firstOrNull,
              clearBrand: _brandId == null,
              preferredProduct: _productId == null
                  ? null
                  : _products.where((p) => p.id == _productId).firstOrNull,
              clearProduct: _productId == null,
              notFound: _notFound,
            ),
          );
    if (!mounted) return;

    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  Future<void> _remove() async {
    // Only reachable in the editing mode: the button is not built otherwise.
    final item = widget.item!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da lista?'),
        content: Text('${item.label} sai da lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final error = await ref
        .read(shoppingListViewModelProvider.notifier)
        .remove(item);
    if (!mounted) return;

    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  /// Under the field, and it says the two sides of one rule.
  ///
  /// Normally it explains what an empty field means. On the item that is on
  /// the list WITH NO QUANTITY and was opened from screen 6, it explains what
  /// confirming changes: the line stops leaving on the first purchase of the
  /// type and starts being written off by amount. **The screen does not change
  /// the rule in silence** (decision of 26/08/2026) — and stacking both
  /// sentences would be noise, since the second one is what ends the first.
  String get _quantityHelper {
    final prefill = widget.prefilledQuantity;
    if (_isEditing && widget.item!.quantity == null && prefill != null) {
      return 'este item está na lista sem quantidade — confirmar passa a '
          'pedir ${widget.type.baseUnit.formatQuantity(prefill)}';
    }
    return 'Vazio: sai na primeira compra do tipo.';
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final brands = _brands;

    return AlertDialog(
      title: Text(widget.type.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField.unit(
              key: const ValueKey('field-quantity'),
              controller: _quantity,
              enabled: !_saving,
              // The spec of the type's BASE unit, never the packaging: what
              // sums is the type, and six litres typed here are six litres
              // even with a 350 ml packaging preferred. The suffix comes with
              // it, and it is the READING unit now — 'L', not 'ml'.
              spec: specOf(widget.type.baseUnit),
              errorText: _quantityError,
              decoration: InputDecoration(
                labelText: 'Quantidade',
                errorMaxLines: 3,
                helperText: _quantityHelper,
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const ValueKey('field-brand'),
              initialValue: _brandId,
              decoration: const InputDecoration(labelText: 'Marca preferida'),
              items: [
                const DropdownMenuItem(child: Text('Qualquer uma')),
                for (final brand in brands)
                  DropdownMenuItem(value: brand.id, child: Text(brand.name)),
              ],
              onChanged: _saving || _loadingLeaves
                  ? null
                  : (id) => setState(() {
                      _brandId = id;
                      // The packaging of another brand stops making sense.
                      _productId = null;
                    }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const ValueKey('field-packaging'),
              initialValue: products.any((p) => p.id == _productId)
                  ? _productId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Embalagem preferida',
              ),
              items: [
                const DropdownMenuItem(child: Text('Qualquer uma')),
                for (final product in products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.packaging!.label),
                  ),
              ],
              onChanged: _saving || _loadingLeaves
                  ? null
                  : (id) => setState(() => _productId = id),
            ),
            if (_loadingLeaves)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            // Both only exist on a line that EXISTS: there is nothing to mark
            // as not found and nothing to remove on a type nobody has asked
            // for yet.
            if (_isEditing) ...[
              SwitchListTile(
                key: const ValueKey('field-not-found'),
                value: _notFound,
                title: const Text('Não encontrei'),
                contentPadding: EdgeInsets.zero,
                // The ONLY way to the `[!]`: the checkbox on the line never
                // passes through it.
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _notFound = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover da lista'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }

  /// Spelled out next to the field: "kg" reads as an abbreviation of something
  /// else when it stands alone beside a number.
}
