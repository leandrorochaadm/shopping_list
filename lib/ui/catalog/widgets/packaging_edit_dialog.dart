import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../core/unit_specs.dart';
import '../view_model/catalog_maintenance_view_model.dart';
import 'catalog_entry_edit_dialog.dart';

/// The "350 ml digitado como 35 ml" of the wireframe: one leaf's packaging,
/// corrected.
///
/// The collision guard is CONTENT, not name — `Product.hasSameContentAs`, so
/// `2 × 500` and `1 × 1000` are the same shelf — and it runs in the ViewModel
/// before any I/O.
class PackagingEditDialog extends ConsumerStatefulWidget {
  const PackagingEditDialog({
    required this.leaf,
    required this.baseUnit,
    super.key,
  });

  static Future<void> show(
    BuildContext context, {
    required Product leaf,
    required BaseUnit baseUnit,
  }) => showDialog<void>(
    context: context,
    builder: (context) => PackagingEditDialog(leaf: leaf, baseUnit: baseUnit),
  );

  final Product leaf;

  /// The base unit of the type this leaf hangs from, and there is nothing to
  /// choose: it is the unit the field is typed in. Typing millilitres under a
  /// type measured in grams would make that type's total add volume to
  /// weight, which is what every report is built on.
  final BaseUnit baseUnit;

  @override
  ConsumerState<PackagingEditDialog> createState() =>
      _PackagingEditDialogState();
}

class _PackagingEditDialogState extends ConsumerState<PackagingEditDialog> {
  late final _countController = TextEditingController(
    text: _countSpec.format(widget.leaf.packaging?.pieceCount ?? 1),
  );
  late final _sizeController = TextEditingController(text: _initialSize);

  String? _error;
  bool _saving = false;

  /// The mask of the FIRST field, and the two it can be are not the same
  /// thing: "Quantas unidades?" is the Count magnitude of the type and reads
  /// `un`; "Quantas peças?" counts pieces, and a piece is not a unit of
  /// measurement.
  UnitSpec get _countSpec => _countsOnly ? specOf(widget.baseUnit) : countSpec;

  /// What the size field opens written with. `''` and not `format(0)`: a leaf
  /// with no packaging opens BLANK, and zero is a number the field would then
  /// be showing as an answer.
  String get _initialSize {
    final packaging = widget.leaf.packaging;
    if (packaging == null) return '';
    return specOf(widget.baseUnit).format(packaging.pieceSize);
  }

  /// A type measured in units has no size field: the piece IS the unit.
  bool get _countsOnly => widget.baseUnit == BaseUnit.unit;

  @override
  void dispose() {
    _countController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Corrigir a embalagem'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField.unit(
            key: const ValueKey('field-piece-count'),
            controller: _countController,
            enabled: !_saving,
            spec: _countSpec,
            decoration: InputDecoration(
              labelText: _countsOnly ? 'Quantas unidades?' : 'Quantas peças?',
            ),
          ),
          if (!_countsOnly) ...[
            const SizedBox(height: 12),
            AppTextField.unit(
              key: const ValueKey('field-piece-size'),
              controller: _sizeController,
              enabled: !_saving,
              spec: specOf(widget.baseUnit),
              decoration: const InputDecoration(labelText: 'Quanto tem cada?'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
        child: Text(widget.leaf.active ? 'Desativar' : 'Reativar'),
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('save-packaging'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );

  Future<void> _save() async {
    final navigator = Navigator.of(context);

    final Packaging packaging;
    try {
      // The text is read by the MASK, which is the only thing that could have
      // written it; what refuses zero and less is still the domain, in the
      // constructor below. `AmountMustBeWhole` is gone with the comma the
      // user can no longer type.
      packaging = Packaging(
        pieceCount: _countSpec.parse(_countController.text),
        pieceSize: _countsOnly
            ? 1
            : specOf(widget.baseUnit).parse(_sizeController.text),
        baseUnit: widget.baseUnit,
      );
    } on InvalidPieceCount catch (e) {
      setState(() => _error = e.message);
      return;
    } on InvalidAmount catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(catalogMaintenanceViewModelProvider.notifier)
        .correctPackaging(widget.leaf.id!, packaging);
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
        .setActive(CatalogKind.packaging, widget.leaf.id!, !widget.leaf.active);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }
}
