import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/packaging.dart';

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
  });

  /// Stable across rebuilds so Flutter does not confuse two rows when one in
  /// the middle is removed — the field of the row below would keep the text
  /// of the row that went away.
  final int id;

  final String pieceCount;
  final String pieceSize;
  final BaseUnit? unit;

  /// The parsed line, or null while it is incomplete or invalid. The parsing
  /// is the domain's: nothing here reimplements the integer reading.
  Packaging? get packaging {
    final unit = this.unit;
    if (unit == null) return null;
    try {
      return Packaging.typed(
        pieceCount: pieceCount,
        // A type counted by unit has no measure of its own: the piece IS the
        // unit, so the count is the whole amount.
        pieceSize: unit == BaseUnit.unit ? '1' : pieceSize,
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
  }) => PackagingDraft(
    id: id,
    pieceCount: pieceCount ?? this.pieceCount,
    pieceSize: pieceSize ?? this.pieceSize,
    unit: unit ?? this.unit,
  );

  /// Changing the TYPE changes the magnitude of the line, so the unit has to
  /// be replaced — and `copyWith(unit: null)` cannot do it, because null there
  /// means "keep what you had".
  PackagingDraft withUnit(BaseUnit? unit) => PackagingDraft(
    id: id,
    pieceCount: pieceCount,
    pieceSize: pieceSize,
    unit: unit,
  );
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
class PackagingRow extends StatelessWidget {
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

  /// A type measured in units has no measure field: the piece is the unit.
  bool get _countsOnly => baseUnit == BaseUnit.unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final packaging = draft.packaging;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('count-${draft.id}'),
                    initialValue: draft.pieceCount,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _countsOnly
                          ? 'Quantas unidades?'
                          : 'Quantas peças?',
                      suffixText: _countsOnly ? baseUnit.label : null,
                    ),
                    onChanged: (value) =>
                        onChanged(draft.copyWith(pieceCount: value)),
                  ),
                ),
                if (!_countsOnly) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 20, left: 8, right: 8),
                    child: Text('×'),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('size-${draft.id}'),
                      initialValue: draft.pieceSize,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Quanto tem cada?',
                        suffixText: baseUnit.label,
                      ),
                      onChanged: (value) =>
                          onChanged(draft.copyWith(pieceSize: value)),
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
                  onPressed: enabled ? onRemoved : null,
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
