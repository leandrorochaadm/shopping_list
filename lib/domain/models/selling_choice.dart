import 'base_unit.dart';
import 'product_registration.dart';

/// As três palavras do campo "Vendido" — e o único lugar onde o par
/// (`SellingMode`, `BaseUnit`) vira UMA escolha.
///
/// The database has two selling modes, not three: `Peso` and `Volume` are the
/// SAME `by_weight`, told apart by the base unit of the type. The type is what
/// owns the grandeza (decision B4), so the screen never lets the two disagree:
/// a type measured in litres offers `Volume`, never `Peso`.
enum SellingChoice {
  weight,
  unit,
  volume;

  /// pt-BR: it is read on screen. Same vocabulary as
  /// `ProductOption.quantityLabel`, which already writes `Peso (kg)` and
  /// `Volume (L)` on screen 3.
  String get label => switch (this) {
    SellingChoice.weight => 'Peso',
    SellingChoice.unit => 'Unidade',
    SellingChoice.volume => 'Volume',
  };

  /// What is SAVED. `Peso` and `Volume` are both the loose product.
  SellingMode get mode =>
      this == SellingChoice.unit ? SellingMode.byPiece : SellingMode.byWeight;

  /// The loose choice of a base unit, or null where there is none: a type
  /// counted by unit has no bulk, and neither has a screen with no type yet.
  static SellingChoice? bulkOf(BaseUnit? baseUnit) => switch (baseUnit) {
    BaseUnit.kilogram => SellingChoice.weight,
    BaseUnit.liter => SellingChoice.volume,
    BaseUnit.unit || null => null,
  };

  /// Whether this choice can be taken under [baseUnit]. `Unidade` always can —
  /// a closed packaging exists in any grandeza.
  bool isAvailableFor(BaseUnit? baseUnit) =>
      this == SellingChoice.unit || this == bulkOf(baseUnit);

  /// The word the LOOSE product goes by under [baseUnit] — the only place
  /// the fallback lives, and it is `Unidade`, never `Peso`. A type counted by
  /// unit offers no bulk choice on SCREEN (H-b), but the domain still holds
  /// the state and old rows may too: calling that one "peso" is the very
  /// mistake this change exists to fix.
  static String looseNameOf(BaseUnit? baseUnit) =>
      (bulkOf(baseUnit) ?? SellingChoice.unit).label;

  /// The choice a saved mode becomes on screen — and the normalization that
  /// keeps the two from disagreeing: a mode of `by_weight` under a type with
  /// no bulk falls back to `Unidade`.
  static SellingChoice of(SellingMode mode, BaseUnit? baseUnit) =>
      mode == SellingMode.byPiece
      ? SellingChoice.unit
      : bulkOf(baseUnit) ?? SellingChoice.unit;
}
