import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/barcode.dart';
import '../../../domain/models/base_unit.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../barcode/widgets/barcode_reader_sheet.dart';
import '../../core/unit_specs.dart';

/// One line of the packaging list WHILE it is being typed.
///
/// It is not an entity and it never leaves the screen: [Packaging] refuses to
/// exist in an invalid state, and a line being typed is invalid most of the
/// time — "35" on the way to "350". So the draft holds the raw text and hands
/// over a [Packaging] only once it parses.
final class PackagingDraft {
  const PackagingDraft({
    required this.id,
    this.pieceCount = '1',
    this.pieceSize = '',
    this.unit,
    this.barcodes = const IList.empty(),
  });

  /// Stable across rebuilds so Flutter does not confuse two rows when one in
  /// the middle is removed — the field of the row below would keep the text
  /// of the row that went away.
  final int id;

  final String pieceCount;
  final String pieceSize;
  final BaseUnit? unit;

  /// The codes printed on this packaging, already accepted by the card.
  final IList<Barcode> barcodes;

  /// The parsed line, or null while it is incomplete or invalid.
  ///
  /// The text is read by the MASK, which is the only thing that could have
  /// written it; what refuses a zero or a blank is still the domain, in the
  /// [Packaging] constructor.
  Packaging? get packaging {
    final unit = this.unit;
    if (unit == null) return null;
    try {
      return Packaging(
        pieceCount: (unit == BaseUnit.unit ? specOf(unit) : countSpec).parse(
          pieceCount,
        ),
        // A type counted by unit has no measure of its own: the piece IS the
        // unit, so the count is the whole amount.
        pieceSize: unit == BaseUnit.unit ? 1 : specOf(unit).parse(pieceSize),
        baseUnit: unit,
      );
    } on Object {
      // Invalid is the normal state of a line halfway typed. The card says
      // what is still missing and the save stays blocked; it does not shout
      // at every keystroke.
      return null;
    }
  }

  PackagingDraft copyWith({
    String? pieceCount,
    String? pieceSize,
    BaseUnit? unit,
    IList<Barcode>? barcodes,
  }) => PackagingDraft(
    id: id,
    pieceCount: pieceCount ?? this.pieceCount,
    pieceSize: pieceSize ?? this.pieceSize,
    unit: unit ?? this.unit,
    barcodes: barcodes ?? this.barcodes,
  );

  /// Changing the TYPE changes the magnitude of the line, so the unit has to
  /// be replaced — and `copyWith(unit: null)` cannot do it, because null there
  /// means "keep what you had".
  PackagingDraft withUnit(BaseUnit? unit) => PackagingDraft(
    id: id,
    pieceCount: pieceCount,
    pieceSize: pieceSize,
    unit: unit,
    barcodes: barcodes,
  );

  /// Lets the refusals of [packagingCodesWith] through: the rule is the
  /// domain's, the draft only keeps the answer.
  PackagingDraft withBarcode(String raw) =>
      copyWith(barcodes: packagingCodesWith(barcodes, raw));

  PackagingDraft withoutBarcode(Barcode code) =>
      copyWith(barcodes: barcodes.remove(code));
}

/// One packaging being typed, as a card: the two fields on top and what it
/// will be CALLED right below them.
///
/// It was a single row until the layout review of 08/09/2026: count, `×`,
/// measure, name, radio and remove is six controls on a 390 pt phone, and the
/// two fields ended up narrower than the words above them. The card gives
/// each thing a line, and the naked radio — "which one am I buying" — left
/// the screen with it: this is the REGISTRATION, and the purchase gets the
/// packaging registered last.
///
/// There is no measure to choose: the type already answered that, and the
/// field simply writes the type's unit as a suffix. Letting the line pick
/// "ml" under a type measured in grams would make that type's total add
/// volume to weight, and that total is what every report is built on.
class PackagingRow extends StatefulWidget {
  const PackagingRow({
    required this.draft,
    required this.baseUnit,
    required this.onChanged,
    required this.onRemoved,
    this.enabled = true,
    this.duplicate = false,
    super.key,
  });

  final PackagingDraft draft;
  final BaseUnit baseUnit;

  final ValueChanged<PackagingDraft> onChanged;
  final VoidCallback onRemoved;
  final bool enabled;

  /// Two identical lines are refused on the spot, and identical is BY CONTENT:
  /// `2 × 500` matches `1 × 1000` because the comparison happens on the total.
  final bool duplicate;

  @override
  State<PackagingRow> createState() => _PackagingRowState();
}

class _PackagingRowState extends State<PackagingRow> {
  final _barcodeText = TextEditingController();

  /// The sentence of the last refusal of this card; it goes away on typing
  /// and on the next accepted code.
  String? _barcodeError;

  PackagingDraft get draft => widget.draft;
  BaseUnit get baseUnit => widget.baseUnit;
  bool get enabled => widget.enabled;
  bool get duplicate => widget.duplicate;

  /// A type measured in units has no measure field: the piece is the unit.
  bool get _countsOnly => baseUnit == BaseUnit.unit;

  @override
  void dispose() {
    _barcodeText.dispose();
    super.dispose();
  }

  void _include(String raw, {required bool typed}) {
    try {
      widget.onChanged(widget.draft.withBarcode(raw));
      if (typed) _barcodeText.clear();
      setState(() => _barcodeError = null);
    } on InStoreBarcode catch (e) {
      setState(() => _barcodeError = e.message);
    } on InvalidBarcode catch (e) {
      setState(() => _barcodeError = e.message);
    } on BarcodeAlreadyOnPackaging catch (e) {
      setState(() => _barcodeError = e.message);
    }
  }

  void _includeTyped() => _include(_barcodeText.text, typed: true);

  Future<void> _scan() async {
    final raw = await BarcodeReaderSheet.show(context);
    // Read AFTER the await: the card may have been rebuilt meanwhile.
    if (!mounted || raw == null) return;
    _include(raw, typed: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final packaging = draft.packaging;
    final onChanged = widget.onChanged;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // The `×` sits on the BASELINE of what is typed, and no longer
              // on a padding measured by hand against the old field height:
              // the filled box and the always-floating label of
              // `AppTextField` moved that height. `InputDecorator` publishes
              // the baseline of the typed text, so the `×` follows the field
              // whatever it grows into — a label, an error line, another
              // density.
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: AppTextField.unit(
                    key: ValueKey('count-${draft.id}'),
                    initialValue: draft.pieceCount,
                    enabled: enabled,
                    // "Quantas unidades?" is the Count magnitude of the type
                    // and reads `un`; "Quantas peças?" counts pieces, and a
                    // piece is not a unit of measurement.
                    spec: _countsOnly ? specOf(baseUnit) : countSpec,
                    // Two fields side by side on a 390 pt phone: there is no
                    // room for a 24 pt button in either of them.
                    showClearButton: false,
                    decoration: InputDecoration(
                      labelText: _countsOnly
                          ? 'Quantas unidades?'
                          : 'Quantas peças?',
                    ),
                    // `?? ''`, and it is not decoration: `copyWith` reads null
                    // as "keep what you had", so a cleared field would come
                    // back with the value it had just lost.
                    onChanged: (value) =>
                        onChanged(draft.copyWith(pieceCount: value ?? '')),
                  ),
                ),
                if (!_countsOnly) ...[
                  const Padding(
                    // The 8 is spacing between siblings, not a measure of the
                    // field: it stays.
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×'),
                  ),
                  Expanded(
                    child: AppTextField.unit(
                      key: ValueKey('size-${draft.id}'),
                      initialValue: draft.pieceSize,
                      enabled: enabled,
                      spec: specOf(baseUnit),
                      showClearButton: false,
                      decoration: const InputDecoration(
                        labelText: 'Quanto tem cada?',
                      ),
                      onChanged: (value) =>
                          onChanged(draft.copyWith(pieceSize: value ?? '')),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                // The name is never a blank space: half typed, the line says
                // WHAT is missing instead of showing nothing and looking
                // broken.
                Expanded(
                  child: Text(
                    _caption(packaging),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: duplicate
                          ? scheme.error
                          : packaging == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover'),
                  onPressed: enabled ? widget.onRemoved : null,
                ),
              ],
            ),
            Text(
              'Código de barras (opcional)',
              style: theme.textTheme.bodyMedium,
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: ValueKey('barcode-${draft.id}'),
                    controller: _barcodeText,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Código de barras',
                    ),
                    onChanged: (_) {
                      if (_barcodeError != null) {
                        setState(() => _barcodeError = null);
                      }
                    },
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) _includeTyped();
                    },
                  ),
                ),
                IconButton(
                  key: ValueKey('barcode-scan-${draft.id}'),
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Ler código',
                  onPressed: enabled ? _scan : null,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _barcodeText,
                  builder: (context, value, _) => IconButton(
                    key: ValueKey('barcode-add-${draft.id}'),
                    icon: const Icon(Icons.add),
                    tooltip: 'Incluir código',
                    onPressed: enabled && value.text.trim().isNotEmpty
                        ? _includeTyped
                        : null,
                  ),
                ),
              ],
            ),
            if (_barcodeError case final error?)
              Text(
                error,
                key: ValueKey('barcode-error-${draft.id}'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            if (draft.barcodes.isEmpty)
              const Text('Nenhum código.')
            else
              for (final code in draft.barcodes)
                Row(
                  children: [
                    Expanded(child: Text('• ${code.label}')),
                    IconButton(
                      key: ValueKey('barcode-remove-${draft.id}-${code.code}'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Remover código',
                      onPressed: enabled
                          ? () => widget.onChanged(
                              widget.draft.withoutBarcode(code),
                            )
                          : null,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  /// What sits under the fields: the shelf name once the line parses, and
  /// WHICH field is still missing while it does not.
  ///
  /// Both fields take digits only, so a line that refuses to parse is either
  /// empty or a zero — there is no third case to word.
  String _caption(Packaging? packaging) {
    if (duplicate) return 'Essa embalagem já está na lista';
    if (packaging != null) return 'Vai se chamar: ${packaging.label}';

    if (_countsOnly) {
      return draft.pieceCount.trim().isEmpty
          ? 'Falta dizer quantas unidades'
          : 'A quantidade tem de ser maior que zero';
    }
    // The measure first: it is the one that opens empty, and saying "falta a
    // quantidade de peças" while the person is looking at an empty measure
    // field points at the wrong place.
    if (draft.pieceSize.trim().isEmpty) {
      return 'Falta dizer quanto tem cada peça';
    }
    if (draft.pieceCount.trim().isEmpty) return 'Falta dizer quantas peças';
    return 'Use números maiores que zero';
  }
}
