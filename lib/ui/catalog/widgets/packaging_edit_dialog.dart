import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../view_model/catalog_maintenance_view_model.dart';
import 'catalog_entry_edit_dialog.dart';

/// The "350 ml digitado como 35 ml" of the wireframe: one leaf's packaging,
/// corrected.
///
/// The collision guard is CONTENT, not name — `Product.hasSameContentAs`, so
/// `1 × 0,35 L` and `1 × 350 ml` are the same shelf — and it runs in the
/// ViewModel before any I/O.
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
    builder: (context) =>
        PackagingEditDialog(leaf: leaf, baseUnit: baseUnit),
  );

  final Product leaf;

  /// The base unit of the type this leaf hangs from — it decides which
  /// measures the dropdown may offer, and no others. Typing "350 ml" under a
  /// type measured in kilos would make that type's total add volume to
  /// weight, which is what every report is built on.
  final BaseUnit baseUnit;

  @override
  ConsumerState<PackagingEditDialog> createState() =>
      _PackagingEditDialogState();
}

class _PackagingEditDialogState extends ConsumerState<PackagingEditDialog> {
  late final _countController = TextEditingController(
    text: '${widget.leaf.packaging?.pieceCount ?? 1}',
  );
  late final _sizeController = TextEditingController(text: _initialSize);
  late MeasureUnit _unit =
      widget.leaf.packaging?.pieceSizeUnit ?? widget.baseUnit.measures.first;

  String? _error;
  bool _saving = false;

  /// What the field opens written with: the measure in the unit it was TYPED
  /// in, so whoever wrote "0,35 L" reads "0,35 L" back and not "350".
  String get _initialSize {
    final packaging = widget.leaf.packaging;
    if (packaging == null) return '';
    return packaging.pieceSizeUnit.format(packaging.pieceSize);
  }

  /// A type measured in units has no measure field: the piece IS the unit.
  bool get _countsOnly =>
      widget.baseUnit.measures.length == 1 &&
      widget.baseUnit.measures.first == MeasureUnit.unit;

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
          TextField(
            key: const ValueKey('field-piece-count'),
            controller: _countController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _countsOnly ? 'Quantidade' : 'Peças',
            ),
          ),
          if (!_countsOnly) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-piece-size'),
              controller: _sizeController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(labelText: 'Cada peça'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MeasureUnit>(
              key: const ValueKey('field-piece-unit'),
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unidade'),
              items: [
                for (final measure in widget.baseUnit.measures)
                  DropdownMenuItem(
                    value: measure,
                    child: Text(measure.label),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (unit) => setState(() => _unit = unit ?? _unit),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
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
      // The parsing is the DOMAIN's, digit by digit: nothing here re-reads a
      // decimal, which is the one place a 350 ml bottle quietly becomes a
      // 349 ml one.
      packaging = Packaging.typed(
        pieceCount: _countController.text,
        pieceSize: _countsOnly ? '1' : _sizeController.text,
        pieceSizeUnit: _countsOnly ? MeasureUnit.unit : _unit,
      );
    } on InvalidPieceCount catch (e) {
      setState(() => _error = e.message);
      return;
    } on InvalidAmount catch (e) {
      setState(() => _error = e.message);
      return;
    } on AmountTooPrecise catch (e) {
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
