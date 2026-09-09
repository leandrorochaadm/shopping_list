import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/brand.dart';
import '../../../domain/models/catalog_maintenance.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../view_model/catalog_maintenance_view_model.dart';
import 'catalog_entry_edit_dialog.dart';

/// Editing a product registration — description, brand and TYPE.
///
/// Its duplicate guard is not a name: it is the triple identity of
/// `hasSameIdentityAs`, ignoring the row being edited. And the type only
/// moves inside [typesCompatibleWith]: the screen does not even list the
/// incompatible ones, because moving a product measured in litres under a
/// type measured in kilos would make that type's total add volume to weight.
class RegistrationEditDialog extends ConsumerStatefulWidget {
  const RegistrationEditDialog({
    required this.registration,
    required this.types,
    required this.brands,
    super.key,
  });

  /// Returns the registration's id when `[ Abrir e acrescentar embalagem ]`
  /// was tapped, and null on any other closing.
  ///
  /// The trip to screen 4 is NOT made from inside this dialog: only whoever
  /// awaits it can redraw the list when it comes back, and `show` completes
  /// when the dialog closes, not when screen 4 returns.
  static Future<String?> show(
    BuildContext context, {
    required ProductRegistration registration,
    required IList<ProductType> types,
    required IList<Brand> brands,
  }) => showDialog<String>(
    context: context,
    builder: (context) => RegistrationEditDialog(
      registration: registration,
      types: types,
      brands: brands,
    ),
  );

  final ProductRegistration registration;
  final IList<ProductType> types;
  final IList<Brand> brands;

  @override
  ConsumerState<RegistrationEditDialog> createState() =>
      _RegistrationEditDialogState();
}

class _RegistrationEditDialogState
    extends ConsumerState<RegistrationEditDialog> {
  late final _descriptionController = TextEditingController(
    text: widget.registration.description,
  );
  late String? _brandId = widget.registration.brandId;
  late String _typeId = widget.registration.productTypeId;

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  ProductType? get _currentType =>
      widget.types.where((t) => t.id == _typeId).firstOrNull;

  /// Only the types of the SAME base unit, plus the one it is filed under —
  /// a type that was deactivated after the fact still has to be shown, or the
  /// dropdown would open on nothing.
  IList<ProductType> get _offeredTypes {
    final current = _currentType;
    if (current == null) return widget.types;

    final compatible = typesCompatibleWith(widget.types, current.baseUnit);
    return compatible.any((t) => t.id == current.id)
        ? compatible
        : compatible.add(current);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar o cadastro'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('field-description'),
            controller: _descriptionController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Descrição',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const ValueKey('field-brand'),
            initialValue: _brandId,
            decoration: const InputDecoration(labelText: 'Marca'),
            items: [
              // Null is a real answer: a registration may have no brand.
              const DropdownMenuItem(value: null, child: Text('Sem marca')),
              for (final brand in widget.brands.where(
                (b) => b.active || b.id == _brandId,
              ))
                DropdownMenuItem(value: brand.id, child: Text(brand.name)),
            ],
            onChanged: _saving ? null : (id) => setState(() => _brandId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('field-type'),
            initialValue: _typeId,
            decoration: InputDecoration(
              labelText: 'Tipo do produto',
              helperText: _typeHelper,
              helperMaxLines: 3,
            ),
            items: [
              for (final type in _offeredTypes)
                DropdownMenuItem(value: type.id, child: Text(type.name)),
            ],
            onChanged: _saving
                ? null
                : (id) => setState(() => _typeId = id ?? _typeId),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('add-packaging'),
              onPressed: _saving ? null : _openPackagings,
              child: const Text('Abrir e acrescentar embalagem'),
            ),
          ),
          Text(
            CatalogEntryEditDialog.footnote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('toggle-active'),
        onPressed: _saving ? null : _toggleActive,
        child: Text(widget.registration.active ? 'Desativar' : 'Reativar'),
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('save-registration'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );

  /// Why the list of types is short — the sentence of `IncompatibleBaseUnit`,
  /// shortened to what a helper line can hold.
  String? get _typeHelper {
    final unit = _currentType?.baseUnit;
    if (unit == null) return null;
    return 'Só tipos medidos na mesma unidade: a medida tem de bater.';
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(catalogMaintenanceViewModelProvider.notifier)
        .editRegistration(
          widget.registration.id!,
          description: _descriptionController.text,
          brandId: _brandId,
          clearBrand: _brandId == null,
          typeId: _typeId,
        );
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) navigator.pop();
  }

  Future<void> _toggleActive() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    final error = await ref
        .read(catalogMaintenanceViewModelProvider.notifier)
        .setActive(
          CatalogKind.registration,
          widget.registration.id!,
          !widget.registration.active,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  /// The DOOR, not the mechanism: screen 4 opens with this registration
  /// loaded and its packagings listed, and it is screen 4 that adds them —
  /// `CatalogViewModel.addPackagings` was written in H2 and nothing of it is
  /// rewritten here.
  ///
  /// It hands the id back and stops there: the SCREEN pushes screen 4, which
  /// is what lets it reload the list when the trip ends.
  void _openPackagings() {
    Navigator.of(context).pop(widget.registration.id);
  }
}
