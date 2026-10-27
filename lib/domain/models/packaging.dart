import 'base_unit.dart';

/// How much a single leaf holds: how many pieces, and how much each piece has.
///
/// **Everything here is an integer in the base unit** (grams, millilitres,
/// units, centimetres) — decision B5. Two packagings holding the same amount
/// are therefore the SAME packaging, and [hasSameContentAs] is what says so;
/// the unique index on `product (product_registration_id, total_content)` is
/// the net underneath.
final class Packaging {
  factory Packaging({
    required int pieceCount,
    required int pieceSize,
    required BaseUnit baseUnit,
  }) {
    if (pieceCount <= 0) throw const InvalidPieceCount();
    if (pieceSize <= 0) throw const InvalidAmount();
    return Packaging._(
      pieceCount: pieceCount,
      pieceSize: pieceSize,
      baseUnit: baseUnit,
      // CALCULATED, never typed and never computed in SQL (decision 7).
      totalContent: pieceCount * pieceSize,
    );
  }

  /// What the screen actually calls: the person types "6" and "350", and the
  /// conversion happens here, before anything is stored.
  factory Packaging.typed({
    required String pieceCount,
    required String pieceSize,
    required BaseUnit baseUnit,
  }) => Packaging(
    pieceCount: BaseUnit.unit.parseAmount(pieceCount),
    pieceSize: baseUnit.parseAmount(pieceSize),
    baseUnit: baseUnit,
  );

  const Packaging._({
    required this.pieceCount,
    required this.pieceSize,
    required this.baseUnit,
    required this.totalContent,
  });

  factory Packaging.fromJson(Map<String, dynamic> json) => Packaging(
    pieceCount: json[pieceCountKey] as int,
    pieceSize: json[pieceSizeKey] as int,
    baseUnit: BaseUnit.fromJson(json[pieceSizeUnitKey] as String),
  );

  static const pieceCountKey = 'piece_count';
  static const pieceSizeKey = 'piece_size';
  static const pieceSizeUnitKey = 'piece_size_unit';
  static const totalContentKey = 'total_content';

  /// Reads the four packaging fields of a leaf: all four or none. `null` is a
  /// leaf sold by weight. A field is empty when it is `null`, `0` or `''`
  /// (what PocketBase returns for a `number`/`text` without value).
  /// Throws [ArgumentError] for half a packaging or a non-positive total.
  static Packaging? fromLeafJson(Map<String, dynamic> json) {
    bool empty(String key) {
      final value = json[key];
      return value == null || value == 0 || value == '';
    }

    final keys = [
      pieceCountKey,
      pieceSizeKey,
      pieceSizeUnitKey,
      totalContentKey,
    ];
    final emptyCount = keys.where(empty).length;
    if (emptyCount == keys.length) return null;
    if (emptyCount != 0) {
      throw ArgumentError.value(
        json,
        'packaging',
        'half a packaging: all four fields or none',
      );
    }
    final total = json[totalContentKey] as num;
    if (total <= 0) {
      throw ArgumentError.value(
        total,
        totalContentKey,
        'a packaging holds more than zero',
      );
    }
    return Packaging.fromJson(json);
  }

  /// How many pieces the package holds: the 6 of "6 × 350 ml".
  final int pieceCount;

  /// The measure of ONE piece, in the base unit.
  final int pieceSize;

  /// The magnitude of the packaging, always the one of the TYPE above it. It
  /// replaces `pieceSizeUnit`, which existed only to remember whether someone
  /// had written "0,35 L" or "350 ml" — a question the screen no longer asks.
  final BaseUnit baseUnit;

  /// pieceCount × pieceSize, same base unit. Calculated, never typed.
  final int totalContent;

  Map<String, dynamic> toJson() => {
    pieceCountKey: pieceCount,
    pieceSizeKey: pieceSize,
    pieceSizeUnitKey: baseUnit.toJson(),
    totalContentKey: totalContent,
  };

  /// The duplicate guard for packaging, and the reason everything is an
  /// integer: two packagings are the same when they hold the same amount,
  /// however it was written down.
  bool hasSameContentAs(Packaging other) =>
      baseUnit == other.baseUnit && totalContent == other.totalContent;

  /// What the screen reads, and it is the name this packaging carries on
  /// EVERY screen: "350 ml" when there is a single piece, "12 × 350 ml" when
  /// there are twelve. The single-piece case drops the "1 ×" because that is
  /// the name on the shelf, and the shelf name is what gets searched for when
  /// a purchase is registered — no "fardo" or "pacote" label needed.
  /// The large unit steps in through the same ruler as every other amount in
  /// the app: "12 × 1 L", never "12 × 1000 ml".
  String get label => pieceCount == 1
      ? baseUnit.formatQuantity(pieceSize)
      : '$pieceCount × ${baseUnit.formatQuantity(pieceSize)}';

  Packaging copyWith({int? pieceCount, int? pieceSize, BaseUnit? baseUnit}) =>
      Packaging(
        pieceCount: pieceCount ?? this.pieceCount,
        pieceSize: pieceSize ?? this.pieceSize,
        baseUnit: baseUnit ?? this.baseUnit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Packaging &&
          other.pieceCount == pieceCount &&
          other.pieceSize == pieceSize &&
          other.baseUnit == baseUnit &&
          other.totalContent == totalContent);

  @override
  int get hashCode =>
      Object.hash(pieceCount, pieceSize, baseUnit, totalContent);

  @override
  String toString() => 'Packaging($label = $totalContent)';
}

/// Zero or fewer pieces in a package. pt-BR: it is read on screen.
final class InvalidPieceCount implements Exception {
  const InvalidPieceCount();

  String get message => 'A embalagem precisa ter pelo menos uma peça.';

  @override
  String toString() => 'InvalidPieceCount: $message';
}
