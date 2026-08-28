import 'base_unit.dart';

/// How much a single leaf holds: how many pieces, and how much each piece has.
///
/// **Everything here is an integer in the smallest unit** (grams, millilitres,
/// units) — decision B5. `1 × 0,35 L` and `1 × 350 ml` are therefore the SAME
/// packaging, and [hasSameContentAs] is what says so; the unique index on
/// `product (product_registration_id, total_content)` is the net underneath.
final class Packaging {
  factory Packaging({
    required int pieceCount,
    required int pieceSize,
    required MeasureUnit pieceSizeUnit,
  }) {
    if (pieceCount <= 0) throw const InvalidPieceCount();
    if (pieceSize <= 0) throw const InvalidAmount();
    return Packaging._(
      pieceCount: pieceCount,
      pieceSize: pieceSize,
      pieceSizeUnit: pieceSizeUnit,
      // CALCULATED, never typed and never computed in SQL (decision 7).
      totalContent: pieceCount * pieceSize,
    );
  }

  /// What the screen actually calls: the person types "6" and "350", and the
  /// conversion happens here, before anything is stored.
  factory Packaging.typed({
    required String pieceCount,
    required String pieceSize,
    required MeasureUnit pieceSizeUnit,
  }) => Packaging(
    pieceCount: MeasureUnit.unit.parseAmount(pieceCount),
    pieceSize: pieceSizeUnit.parseAmount(pieceSize),
    pieceSizeUnit: pieceSizeUnit,
  );

  const Packaging._({
    required this.pieceCount,
    required this.pieceSize,
    required this.pieceSizeUnit,
    required this.totalContent,
  });

  factory Packaging.fromJson(Map<String, dynamic> json) => Packaging(
    pieceCount: json['piece_count'] as int,
    pieceSize: json['piece_size'] as int,
    pieceSizeUnit: MeasureUnit.fromJson(json['piece_size_unit'] as String),
  );

  /// How many pieces the package holds: the 6 of "6 × 350 ml".
  final int pieceCount;

  /// The measure of ONE piece, in the smallest unit of its base.
  final int pieceSize;

  /// The unit that was TYPED. Kept only so the screen can show "0,35 L" back
  /// to whoever typed "0,35 L" instead of turning it into "350 ml".
  final MeasureUnit pieceSizeUnit;

  /// pieceCount × pieceSize, same smallest unit. Calculated, never typed.
  final int totalContent;

  BaseUnit get baseUnit => pieceSizeUnit.baseUnit;

  Map<String, dynamic> toJson() => {
    'piece_count': pieceCount,
    'piece_size': pieceSize,
    'piece_size_unit': pieceSizeUnit.toJson(),
    'total_content': totalContent,
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
  String get label => pieceCount == 1
      ? '$_amountLabel ${pieceSizeUnit.label}'
      : '$pieceCount × $_amountLabel ${pieceSizeUnit.label}';

  /// The same conversion screen 1 and the item dialog need, so it lives in
  /// the unit rather than being copied a third time here.
  String get _amountLabel => pieceSizeUnit.format(pieceSize);

  Packaging copyWith({
    int? pieceCount,
    int? pieceSize,
    MeasureUnit? pieceSizeUnit,
  }) => Packaging(
    pieceCount: pieceCount ?? this.pieceCount,
    pieceSize: pieceSize ?? this.pieceSize,
    pieceSizeUnit: pieceSizeUnit ?? this.pieceSizeUnit,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Packaging &&
          other.pieceCount == pieceCount &&
          other.pieceSize == pieceSize &&
          other.pieceSizeUnit == pieceSizeUnit &&
          other.totalContent == totalContent);

  @override
  int get hashCode =>
      Object.hash(pieceCount, pieceSize, pieceSizeUnit, totalContent);

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
