/// The unit a product type is added up in — and, with it, which measures the
/// packaging screen may offer.
///
/// It lives on the type because the type is the level that SUMS: everything
/// below it is converted into this before anything is added.
enum BaseUnit {
  kilogram,
  liter,
  unit;

  static BaseUnit fromJson(String value) =>
      BaseUnit.values.firstWhere((unit) => unit.name == value.toLowerCase());

  String toJson() => name;

  /// The measures the screen offers for this base — and no others. Weight
  /// never offers millilitres, volume never offers grams, and a type counted
  /// by unit offers only the count itself. Showing all five at once is how a
  /// "350 g" of soft drink gets typed.
  List<MeasureUnit> get measures => switch (this) {
    BaseUnit.kilogram => const [MeasureUnit.gram, MeasureUnit.kilogram],
    BaseUnit.liter => const [MeasureUnit.milliliter, MeasureUnit.liter],
    BaseUnit.unit => const [MeasureUnit.unit],
  };

  /// How the amount is written on screen — the smallest unit is what is
  /// STORED, this is what is read.
  String get label => switch (this) {
    BaseUnit.kilogram => 'kg',
    BaseUnit.liter => 'L',
    BaseUnit.unit => 'un',
  };

  /// The measure a list quantity is TYPED in: kilo, litre or unit. Never the
  /// smallest one — nobody asks for "6000 gramas de acém".
  MeasureUnit get typedMeasure => switch (this) {
    BaseUnit.kilogram => MeasureUnit.kilogram,
    BaseUnit.liter => MeasureUnit.liter,
    BaseUnit.unit => MeasureUnit.unit,
  };

  /// How many smallest units one base unit is worth: 1 kg = 1000 g.
  int get smallestUnits => typedMeasure.smallestUnits;

  /// What the list line shows: '6 kg', '2,5 L', '3 un'.
  String formatQuantity(int amountInSmallestUnits) =>
      '${typedMeasure.format(amountInSmallestUnits)} $label';
}

/// A measure someone can type. Every amount is stored as an INTEGER in the
/// smallest unit of its base (grams, millilitres, units) — decision B5 — so
/// nothing in the app or in the database ever holds a fractional quantity.
enum MeasureUnit {
  gram(BaseUnit.kilogram, 1, 'g'),
  kilogram(BaseUnit.kilogram, 1000, 'kg'),
  milliliter(BaseUnit.liter, 1, 'ml'),
  liter(BaseUnit.liter, 1000, 'L'),
  unit(BaseUnit.unit, 1, 'un');

  const MeasureUnit(this.baseUnit, this.smallestUnits, this.label);

  final BaseUnit baseUnit;

  /// How many smallest units fit in one of these: 1 kg = 1000 g.
  final int smallestUnits;

  /// pt-BR, because it is read on screen.
  final String label;

  static MeasureUnit fromJson(String value) =>
      MeasureUnit.values.firstWhere((unit) => unit.name == value.toLowerCase());

  String toJson() => name;

  /// Reads what was typed — '0,35', '1.5', '350' — and returns the amount in
  /// SMALLEST UNITS, as an integer.
  ///
  /// The parsing is done digit by digit and never goes through a double:
  /// `0.35 * 1000` in binary floating point is 349.99999999999994, and one
  /// truncation later a 350 ml bottle becomes a 349 ml one. That is the whole
  /// reason decision 24 and B5 exist.
  int parseAmount(String typed) {
    final cleaned = typed.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) throw const InvalidAmount();

    final parts = cleaned.split('.');
    if (parts.length > 2) throw const InvalidAmount();

    final whole = parts.first;
    final fraction = parts.length == 2 ? parts[1] : '';
    if (whole.isEmpty && fraction.isEmpty) throw const InvalidAmount();
    if (!_isDigits(whole) || !_isDigits(fraction)) throw const InvalidAmount();

    final places = decimalPlaces;
    if (fraction.length > places) throw AmountTooPrecise(places);

    final scaled = fraction.padRight(places, '0');
    final amount =
        int.parse(whole.isEmpty ? '0' : whole) * smallestUnits +
        int.parse(scaled.isEmpty ? '0' : scaled);

    if (amount <= 0) throw const InvalidAmount();
    return amount;
  }

  /// How many decimal places this unit can express without losing anything:
  /// 3 in the kilogram and the litre, 0 in the gram, the millilitre and the
  /// unit.
  int get decimalPlaces => smallestUnits.toString().length - 1;

  /// The integer in smallest units written the way it is read: 350 -> '350'
  /// in millilitres, 2500 -> '2,5' in litres. A comma, because it is read on
  /// screen.
  String format(int amountInSmallestUnits) {
    if (decimalPlaces == 0) return '$amountInSmallestUnits';

    final whole = amountInSmallestUnits ~/ smallestUnits;
    final fraction = (amountInSmallestUnits % smallestUnits)
        .toString()
        .padLeft(decimalPlaces, '0')
        .replaceAll(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole,$fraction';
  }

  static bool _isDigits(String value) =>
      value.isEmpty || RegExp(r'^\d+$').hasMatch(value);
}

/// The typed amount is not a number. pt-BR: it is read on screen.
final class InvalidAmount implements Exception {
  const InvalidAmount();

  String get message => 'Informe uma quantidade válida.';

  @override
  String toString() => 'InvalidAmount: $message';
}

/// The typed amount has more decimal places than the unit can hold — '0,3505'
/// of a litre is half a millilitre, and there is no such thing here.
///
/// **The sentence DERIVES from the number** (rule 6), and it has to: a type
/// measured by unit holds zero decimal places, and a fixed "no máximo três
/// casas decimais" would offer three that do not exist.
final class AmountTooPrecise implements Exception {
  const AmountTooPrecise(this.decimalPlaces);

  /// How many places the unit that refused the amount can hold.
  final int decimalPlaces;

  String get message => decimalPlaces == 0
      ? 'Use um número inteiro.'
      : 'Use no máximo $decimalPlaces casas decimais.';

  @override
  String toString() => 'AmountTooPrecise: $message';
}
