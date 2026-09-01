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
  final MeasureUnit? unit;

  /// The parsed line, or null while it is incomplete or invalid. The parsing
  /// is the domain's: nothing here reimplements the decimal reading, which is
  /// the one place a 350 ml bottle could quietly become a 349 ml one.
  Packaging? get packaging {
    final unit = this.unit;
    if (unit == null) return null;
    try {
      return Packaging.typed(
        pieceCount: pieceCount,
        // A type counted by unit has no measure of its own: the piece IS the
        // unit, so the count is the whole amount.
        pieceSize: unit == MeasureUnit.unit ? '1' : pieceSize,
        pieceSizeUnit: unit,
      );
    } on Object {
      // Invalid is the normal state of a line halfway typed. The screen shows
      // nothing in the "Fica como" column and refuses the save; it does not
      // shout at every keystroke.
      return null;
    }
  }

  PackagingDraft copyWith({
    String? pieceCount,
    String? pieceSize,
    MeasureUnit? unit,
  }) => PackagingDraft(
    id: id,
    pieceCount: pieceCount ?? this.pieceCount,
    pieceSize: pieceSize ?? this.pieceSize,
    unit: unit ?? this.unit,
  );

  /// Changing the TYPE changes which unit family is legal, so the unit has to
  /// be dropped — and `copyWith(unit: null)` cannot do it, because null there
  /// means "keep what you had". A type with a single measure (a type counted
  /// by unit) gets that measure instead of nothing: there is no dropdown for
  /// it to be chosen in.
  PackagingDraft withUnit(MeasureUnit? unit) => PackagingDraft(
    id: id,
    pieceCount: pieceCount,
    pieceSize: pieceSize,
    unit: unit,
  );
}

/// `peças × cada unidade`, with what it will be CALLED next to it.
///
/// The measure dropdown offers only the family of the chosen type — `g / kg`
/// for weight, `ml / L` for volume. Never all four at once: typing "350 ml"
/// under a type measured in kilos would make that type's total add volume to
/// weight, and that total is what every report is built on.
class PackagingRow extends StatelessWidget {
  const PackagingRow({
    required this.draft,
    required this.measures,
    required this.onChanged,
    required this.onRemoved,
    this.enabled = true,
    this.duplicate = false,
    super.key,
  });

  final PackagingDraft draft;
  final List<MeasureUnit> measures;

  final ValueChanged<PackagingDraft> onChanged;
  final VoidCallback onRemoved;
  final bool enabled;

  /// Two identical lines are refused on the spot, and identical is BY CONTENT:
  /// `1 × 0,35 L` matches `1 × 350 ml` because the comparison happens after
  /// the conversion.
  final bool duplicate;

  /// A type measured in units has no measure field: the piece is the unit.
  bool get _countsOnly =>
      measures.length == 1 && measures.first == MeasureUnit.unit;

  @override
  Widget build(BuildContext context) {
    final packaging = draft.packaging;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: TextFormField(
              key: ValueKey('count-${draft.id}'),
              initialValue: draft.pieceCount,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _countsOnly ? 'Quantidade' : 'Peças',
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'Quantidade em '
                      '${(draft.unit ?? measures.firstOrNull)?.label ?? ''}',
                ),
                onChanged: (value) =>
                    onChanged(draft.copyWith(pieceSize: value)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: DropdownButtonFormField<MeasureUnit>(
                key: ValueKey('unit-${draft.id}'),
                initialValue: draft.unit,
                decoration: const InputDecoration(labelText: 'Un.'),
                items: [
                  for (final measure in measures)
                    DropdownMenuItem(
                      value: measure,
                      child: Text(measure.label),
                    ),
                ],
                onChanged: enabled
                    ? (unit) => onChanged(draft.copyWith(unit: unit))
                    : null,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                duplicate
                    ? 'Essa embalagem já está na lista'
                    : packaging?.label ?? '',
                style: TextStyle(
                  color: duplicate
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Which packaging is being bought right now. It starts on the FIRST
          // line and is never empty: stopping the purchase to ask "which one?"
          // would cost more than getting it wrong and switching in the
          // selector. The RadioGroup that owns it is on the screen.
          Radio<int>(value: draft.id, enabled: enabled),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remover embalagem',
            onPressed: enabled ? onRemoved : null,
          ),
        ],
      ),
    );
  }
}
