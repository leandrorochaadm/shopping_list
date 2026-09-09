import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product_type.dart';
import '../view_model/catalog_view_model.dart';
import 'new_category_dialog.dart';

/// The mini registration: name, category and base unit, and it stops there.
///
/// Not a product registration — no brand, no description, no packaging. The
/// type is what the shopping list needs in order to group (requirement 11)
/// and to write an item off when the purchase arrives; the product itself is
/// born on screen 4 at the first purchase.
///
/// It is reused verbatim by the `[+Novo]` of `#1a` (H4). Writing it twice is
/// the mistake to avoid.
class NewProductTypeDialog extends ConsumerStatefulWidget {
  const NewProductTypeDialog({
    this.initialName = '',
    this.confirmLabel = 'Criar',
    super.key,
  });

  /// What was already typed in the `#1a` search. Without it, whoever typed
  /// "achocolatado" and tapped `[ + Criar "achocolatado" ]` types it all over
  /// again — in the most used path of the app.
  final String initialName;

  /// The wireframe of `#1a` calls this button `[ Criar e adicionar ]`, because
  /// there it does both things: it creates the type and puts the item on the
  /// list, closing the panel. On screen 4 it only creates, and stays `[ Criar ]`.
  final String confirmLabel;

  /// Opens it and returns the type that was created, or null when dismissed.
  static Future<ProductType?> show(
    BuildContext context,
    WidgetRef ref, {
    String initialName = '',
    String confirmLabel = 'Criar',
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NewProductTypeDialog(
        initialName: initialName,
        confirmLabel: confirmLabel,
      ),
    );
    if (name == null) return null;

    return findNameConflict(
      ref.read(catalogViewModelProvider).value?.types ?? const <ProductType>[],
      name,
    );
  }

  @override
  ConsumerState<NewProductTypeDialog> createState() =>
      _NewProductTypeDialogState();
}

class _NewProductTypeDialogState extends ConsumerState<NewProductTypeDialog> {
  // The button is already governed by the field's content, so a name coming
  // from the search makes it born enabled — which is the right behaviour.
  late final _controller = TextEditingController(text: widget.initialName);
  String? _categoryId;
  BaseUnit? _baseUnit;
  String? _error;
  bool _saving = false;

  /// The deactivated type the last refusal was about, and the `[ Reativar ]`
  /// beside the error. This dialog does not use `SingleFieldDialog` — it has
  /// three fields — so the same button of the other three doors is written by
  /// hand here, next to the message that raised it (decision of 29/08/2026).
  ProductType? _reactivable;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final categoryId = _categoryId;
    final baseUnit = _baseUnit;
    // The button is disabled without both, so this is the compiler's ask, not
    // a second validation.
    if (categoryId == null || baseUnit == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _reactivable = null;
    });
    final error = await ref
        .read(catalogViewModelProvider.notifier)
        .createType(
          name: _controller.text,
          categoryId: categoryId,
          baseUnit: baseUnit,
        );
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
      _reactivable = error == null ? null : _findReactivable();
    });
    if (error == null) navigator.pop(_controller.text);
  }

  /// The type already using the typed name, when it is DEACTIVATED — null
  /// when the conflict was with an active one, because then there is no way
  /// out to offer.
  ProductType? _findReactivable() {
    final conflict = findNameConflict(
      ref.read(catalogViewModelProvider).value?.types ?? const <ProductType>[],
      _controller.text,
    );
    return conflict == null || conflict.active ? null : conflict;
  }

  Future<void> _reactivate() async {
    final entry = _reactivable;
    if (entry == null) return;
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(catalogViewModelProvider.notifier)
        .reactivateType(entry);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
    // Closes handing back the NAME, exactly as a successful create does: the
    // caller finds the row in the list the ViewModel has just updated.
    if (error == null) navigator.pop(entry.name);
  }

  Future<void> _newCategory() async {
    final created = await NewCategoryDialog.show(context, ref);
    if (!mounted || created == null) return;
    setState(() => _categoryId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(catalogViewModelProvider).value?.categories ??
        const <Category>[];
    final ready =
        _controller.text.trim().isNotEmpty &&
        _categoryId != null &&
        _baseUnit != null;

    return AlertDialog(
      title: const Text('Novo tipo de produto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              errorText: _error,
              decoration: const InputDecoration(
                labelText: 'Nome do tipo',
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {
                if (_reactivable != null) _reactivable = null;
              }),
            ),
            if (_reactivable != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('reactivate'),
                  onPressed: _saving ? null : _reactivate,
                  child: const Text('Reativar'),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('field-type-category'),
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.active
                                ? category.name
                                : '${category.name} (desativada)',
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (id) => setState(() => _categoryId = id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova categoria',
                  // It works WHILE the lists are still loading: creating does
                  // not depend on the list.
                  onPressed: _saving ? null : _newCategory,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Unidade base'),
            // No default guessed, and the button stays disabled until one is
            // chosen: the base unit decides which magnitude the type is added
            // up in — weight, volume, count or length — and changing it later
            // is the one path with no way back in the catalog
            // (requirement 16).
            RadioGroup<BaseUnit>(
              groupValue: _baseUnit,
              onChanged: (value) => setState(() => _baseUnit = value),
              child: Column(
                children: [
                  for (final unit in BaseUnit.values)
                    RadioListTile<BaseUnit>(
                      value: unit,
                      title: Text(unit.magnitudeLabel),
                      contentPadding: EdgeInsets.zero,
                      enabled: !_saving,
                    ),
                ],
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
          onPressed: ready && !_saving ? _submit : null,
          child: Text(_saving ? 'Salvando...' : widget.confirmLabel),
        ),
      ],
    );
  }

  /// pt-BR, and spelled out: "kg" next to "litro" reads as an abbreviation of
  /// something else on a three-option list.
}
