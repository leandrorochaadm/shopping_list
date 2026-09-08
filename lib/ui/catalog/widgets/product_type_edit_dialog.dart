import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/catalog_maintenance.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product_type.dart';
import '../view_model/catalog_maintenance_view_model.dart';
import '../view_model/catalog_view_model.dart';
import 'catalog_entry_edit_dialog.dart';

/// Editing a product type: its name, the category it is filed under, and —
/// while it still can be — its base unit.
///
/// It is its own dialog rather than the shared one-field shell because a type
/// carries three things the others do not have, and two of them are guarded:
/// the destination category has to be active, and the base unit is locked as
/// soon as the type has a product or a purchase.
class ProductTypeEditDialog extends ConsumerStatefulWidget {
  const ProductTypeEditDialog({
    required this.type,
    required this.categories,
    required this.purchaseCount,
    super.key,
  });

  /// Opens it, having first asked how many purchases this type already has —
  /// the other half of [canChangeBaseUnit], and a read the dialog cannot make
  /// while it is building.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required ProductType type,
    required IList<Category> categories,
  }) async {
    final counts = await ref
        .read(catalogViewModelProvider.notifier)
        .purchaseCountsByType();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => ProductTypeEditDialog(
        type: type,
        categories: categories,
        purchaseCount: counts[type.id!] ?? 0,
      ),
    );
  }

  final ProductType type;
  final IList<Category> categories;
  final int purchaseCount;

  @override
  ConsumerState<ProductTypeEditDialog> createState() =>
      _ProductTypeEditDialogState();
}

class _ProductTypeEditDialogState extends ConsumerState<ProductTypeEditDialog> {
  late final _nameController = TextEditingController(text: widget.type.name);
  late String? _categoryId = widget.type.categoryId;
  late BaseUnit _baseUnit = widget.type.baseUnit;

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _baseUnitEditable => canChangeBaseUnit(
    productCount: _productCount,
    purchaseCount: widget.purchaseCount,
  );

  /// Counted IN MEMORY over what the screen already loaded — a round trip to
  /// count what is in hand would be a round trip for nothing.
  int get _productCount =>
      ref
          .read(catalogMaintenanceViewModelProvider)
          .value
          ?.productCountOfType(widget.type.id!) ??
      0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar o tipo'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('field-type-name'),
            controller: _nameController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nome do tipo',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('field-type-category'),
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              // Only the active ones: filing a type under a category nobody
              // sees is filing it nowhere.
              for (final category in widget.categories.where((c) => c.active))
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: _saving
                ? null
                : (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BaseUnit>(
            key: const ValueKey('field-base-unit'),
            initialValue: _baseUnit,
            decoration: InputDecoration(
              labelText: 'Unidade base',
              helperText: _baseUnitEditable
                  ? null
                  : const BaseUnitLocked().message,
              helperMaxLines: 3,
            ),
            items: [
              for (final unit in BaseUnit.values)
                DropdownMenuItem(value: unit, child: Text(unit.magnitudeLabel)),
            ],
            onChanged: _saving || !_baseUnitEditable
                ? null
                : (unit) => setState(() => _baseUnit = unit ?? _baseUnit),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              CatalogEntryEditDialog.footnote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('toggle-active'),
        onPressed: _saving ? null : _toggleActive,
        child: Text(widget.type.active ? 'Desativar' : 'Reativar'),
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('save-type'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final notifier = ref.read(catalogMaintenanceViewModelProvider.notifier);
    final id = widget.type.id!;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Three writes, and each of them is one rule the ViewModel makes hold.
    // Stopping at the first refusal is what keeps a rejected rename from
    // being followed by a reclassification nobody asked to keep.
    var error = await notifier.renameNamed(
      CatalogKind.productType,
      id,
      _nameController.text,
    );
    if (error == null &&
        _categoryId != null &&
        _categoryId != widget.type.categoryId) {
      error = await notifier.reclassifyType(id, _categoryId!);
    }
    if (error == null && _baseUnit != widget.type.baseUnit) {
      error = await notifier.changeBaseUnit(
        id,
        _baseUnit,
        purchaseCount: widget.purchaseCount,
      );
    }
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) navigator.pop();
  }

  /// Deactivating a type that is on the list is TWO steps on purpose: the
  /// screen asks the number, shows what `TypeInUseOnList` derives from it,
  /// and only the confirmation removes anything. One method that deactivated
  /// and removed without asking would take from the View the only decision
  /// that is the View's.
  Future<void> _toggleActive() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(catalogMaintenanceViewModelProvider.notifier);
    final id = widget.type.id!;

    setState(() => _saving = true);

    if (widget.type.active) {
      final count = await notifier.countListItemsOfType(id);
      if (!mounted) return;

      if (count == null) {
        // A count that did not load is NOT a zero: treating it as one would
        // remove items nobody ever saw.
        setState(() {
          _saving = false;
          _error = 'Não foi possível conferir a lista. Tente de novo.';
        });
        return;
      }

      if (count > 0) {
        final confirmed = await _confirmRemoval(count);
        if (!mounted) return;
        if (!confirmed) {
          setState(() => _saving = false);
          return;
        }

        final error = await notifier.deactivateTypeAndRemoveItems(id);
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = error;
        });
        if (error == null) navigator.pop();
        return;
      }
    }

    final error = await notifier.setActive(
      CatalogKind.productType,
      id,
      !widget.type.active,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  Future<bool> _confirmRemoval(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar o tipo?'),
        content: Text(
          TypeInUseOnList(name: widget.type.name, itemCount: count).message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-deactivate'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desativar mesmo assim'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
