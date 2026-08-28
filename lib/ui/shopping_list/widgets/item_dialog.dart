import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../catalog/view_model/catalog_view_model.dart';
import '../view_model/shopping_list_view_model.dart';

/// The item dialog of H6: quantity, preferred brand, preferred packaging,
/// "não encontrei" and remove.
///
/// It has an exit of its own (`R11`): in an installed PWA there is no browser
/// Back button.
class ItemDialog extends ConsumerStatefulWidget {
  const ItemDialog({required this.item, super.key});

  final ShoppingListItem item;

  static Future<void> show(BuildContext context, ShoppingListItem item) =>
      showDialog<void>(
        context: context,
        builder: (context) => ItemDialog(item: item),
      );

  @override
  ConsumerState<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<ItemDialog> {
  late final TextEditingController _quantity = TextEditingController(
    // Filled with what is already stored, written the way it is read: 6000 in
    // litres comes back as "6", not as "6000".
    text: widget.item.quantity == null
        ? ''
        : widget.item.type.baseUnit.typedMeasure.format(
            widget.item.quantity!,
          ),
  );

  String? _brandId;
  String? _productId;
  late bool _notFound = widget.item.notFound;

  IList<TypeLeaf> _leaves = const IList.empty();
  bool _loadingLeaves = true;
  bool _saving = false;
  String? _quantityError;

  @override
  void initState() {
    super.initState();
    _brandId = widget.item.preferredBrand?.id;
    _productId = widget.item.preferredProduct?.id;
    _loadLeaves();
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    final typeId = widget.item.type.id;
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
    final measure = widget.item.type.baseUnit.typedMeasure;
    final typed = _quantity.text.trim();

    int? quantity;
    if (typed.isNotEmpty) {
      try {
        quantity = measure.parseAmount(typed);
      } on InvalidAmount catch (e) {
        setState(() => _quantityError = e.message);
        return;
      } on AmountTooPrecise catch (e) {
        // Under the field, never a SnackBar: it is an answer about what was
        // just typed, and it belongs next to what was typed.
        setState(() => _quantityError = e.message);
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _quantityError = null;
    });

    final error = await ref
        .read(shoppingListViewModelProvider.notifier)
        .save(
          widget.item.copyWith(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da lista?'),
        content: Text('${widget.item.label} sai da lista.'),
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
        .remove(widget.item);
    if (!mounted) return;

    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final brands = _brands;

    return AlertDialog(
      title: Text(widget.item.type.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('field-quantity'),
              controller: _quantity,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantidade',
                // The BASE unit of the type, never the packaging: what sums is
                // the type, and "6" here is six litres even with a 350 ml
                // packaging preferred.
                suffixText: _measureLabel(widget.item.type.baseUnit),
                errorText: _quantityError,
                errorMaxLines: 3,
                helperText: 'Vazio: sai na primeira compra do tipo.',
                helperMaxLines: 2,
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
  static String _measureLabel(BaseUnit unit) => switch (unit) {
    BaseUnit.kilogram => 'quilos',
    BaseUnit.liter => 'litros',
    BaseUnit.unit => 'unidades',
  };
}
