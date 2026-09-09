import 'package:tekton_core/tekton_core.dart';

import '../../domain/models/base_unit.dart';

/// The mask preset a typable field uses for a given [BaseUnit].
///
/// [BaseUnit] is picked at run time — the product type is what names the
/// magnitude — so the pairing cannot live in a `const` at the call site. And it
/// cannot live in `domain/` either: `UnitSpec` comes from `tekton_core`, which
/// imports `flutter/services.dart`, and rule 1 keeps `domain/` free of Flutter.
///
/// The user keeps typing the STORED unit (gram, millilitre, centimetre, piece);
/// what changes is that the field now READS it in the large one — 350 grams
/// typed shows up as `0,350` with a `kg` suffix.
UnitSpec specOf(BaseUnit unit) => switch (unit) {
      BaseUnit.gram => UnitSpec.weight,
      BaseUnit.milliliter => UnitSpec.volume,
      BaseUnit.centimeter => UnitSpec.length,
      BaseUnit.unit => unitCountSpec,
    };

/// The Count magnitude of a product type: whole numbers, read as `un`.
///
/// It is what `suffixText: baseUnit.label` used to draw on a field of a type
/// sold by the piece. Not to be confused with [countSpec].
const UnitSpec unitCountSpec = UnitSpec(decimalDigits: 0, suffix: 'un');

/// How many PIECES a packaging holds — "Quantas peças?".
///
/// Whole numbers with NO suffix: it counts pieces, and a piece is not a unit of
/// measurement. This is the one field it serves; everything else that counts
/// goes through `specOf(BaseUnit.unit)`, which carries the `un`.
const UnitSpec countSpec = UnitSpec(decimalDigits: 0);
