/// The magnitude a product type is added up in — and the WHOLE unit every
/// amount is typed and stored in.
///
/// It lives on the type because the type is the level that SUMS: everything
/// below it is converted into this before anything is added.
///
/// Each magnitude has ONE storage measure, always the small one: gram,
/// millilitre, unit and centimetre. Nobody picks between 'g' and 'kg' on
/// screen; the type already answered that when it was created.
enum BaseUnit {
  gram('g', 'Peso', 'grama', 1000, 'kg', 'quilo', 'o kg'),
  milliliter('ml', 'Volume', 'mililitro', 1000, 'L', 'litro', 'o litro'),
  unit('un', 'Contagem', 'unidade', 1, 'un', 'unidade', 'a unidade'),
  centimeter('cm', 'Tamanho', 'centímetro', 100, 'm', 'metro', 'o metro');

  const BaseUnit(
    this.label,
    this.magnitude,
    this.magnitudeNoun,
    this.unitsPerLargeUnit,
    this._largeLabel,
    this.pricingNoun,
    this.pricingArticle,
  );

  /// The symbol of the STORED unit: 'g', 'ml', 'un', 'cm'. It is the suffix of
  /// every typable field. pt-BR, because it is read on screen.
  final String label;

  /// The name of the magnitude: 'Peso', 'Volume', 'Contagem', 'Tamanho'.
  final String magnitude;

  /// The stored unit spelled out: 'grama', 'mililitro', 'unidade',
  /// 'centímetro'. Only [magnitudeLabel] uses it.
  final String magnitudeNoun;

  /// How many stored units fit in the READING unit — and, by consequence, in
  /// the PRICING one: 1 kg = 1000 g, 1 L = 1000 ml, 1 m = 100 cm, 1 un = 1 un.
  ///
  /// **One role only, and it is not the typing scale.** It is the point where
  /// the display turns from '900 g' into '1 kg', and the same factor makes the
  /// price read 'R$ 32,90 o kg' instead of 'R$ 0,03 a grama'. Since
  /// [parseAmount] stopped scaling what was typed, nobody types in the large
  /// unit — that is what the old name, `smallestUnits`, promised and did not
  /// deliver.
  final int unitsPerLargeUnit;

  /// The symbol of the reading unit: 'kg', 'L', 'un', 'm'. **Private**:
  /// whoever needs it from the outside is always a price or a type magnitude,
  /// and both come in through [priceLabel]. Leaving it public would hand the
  /// screen back the choice between 'kg' and 'g' that this enum exists to
  /// make.
  final String _largeLabel;

  /// The pricing word spelled out: 'custo por quilo'.
  final String pricingNoun;

  /// The end of the footer sentence, WITH its article: 'o kg', 'a unidade'.
  final String pricingArticle;

  static BaseUnit fromJson(String value) =>
      BaseUnit.values.firstWhere((unit) => unit.name == value.toLowerCase());

  String toJson() => name;

  /// How many decimal places the LARGE unit expresses without losing anything:
  /// 3 in the kilo and the litre, 2 in the metre, 0 in the count. Private:
  /// only [_formatAmount] uses it, and nobody outside needs to know it exists.
  int get _largeDecimalPlaces => unitsPerLargeUnit.toString().length - 1;

  /// Has the amount passed the point where it is worth reading in the large
  /// unit? The count never passes — there is no such thing as a "kilo-unit".
  bool usesLargeUnit(int amount) =>
      unitsPerLargeUnit > 1 && amount >= unitsPerLargeUnit;

  /// Reads what was typed and returns the INTEGER in the stored unit.
  ///
  /// Digits only: there is no decimal place in any field of the app any more,
  /// because the typed unit became the small one. '0,35' of a litre became
  /// '350' of a millilitre, and the reason decision 24 and B5 exist — the
  /// `0.35 * 1000 == 349.99999999999994` of floating point — lost its way in.
  int parseAmount(String typed) {
    final cleaned = typed.trim();
    if (cleaned.isEmpty) throw const InvalidAmount();
    if (cleaned.contains(',') || cleaned.contains('.')) {
      throw const AmountMustBeWhole();
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) throw const InvalidAmount();

    // `tryParse`, never `parse`: the RegExp accepts twenty-five digits and
    // `parse` would answer that with a RAW `FormatException`, which none of
    // the five screens catches — they only handle `InvalidAmount` and
    // `AmountMustBeWhole`.
    final amount = int.tryParse(cleaned);
    if (amount == null || amount <= 0) throw const InvalidAmount();
    return amount;
  }

  /// The NUMBER alone, with no unit, at the asked scale: 6000 reads '6' with
  /// [large] true and '6000' with it false. The comma is for reading.
  ///
  /// **Private**, and it is what makes [typedText] hold: public, any widget
  /// could pass `large: true` and `flutter analyze` would stay quiet. Its
  /// three callers — [formatQuantity], [formatQuantityPair] and [typedText] —
  /// are all in here.
  String _formatAmount(int amount, {required bool large}) {
    if (!large || unitsPerLargeUnit == 1) return '$amount';

    final whole = amount ~/ unitsPerLargeUnit;
    final fraction = (amount % unitsPerLargeUnit)
        .toString()
        .padLeft(_largeDecimalPlaces, '0')
        .replaceAll(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole,$fraction';
  }

  /// What the screen reads: '900 g', '6 kg', '1,25 L', '1,1 m'. The large unit
  /// steps in as soon as the amount reaches it.
  String formatQuantity(int amount) {
    final large = usesLargeUnit(amount);
    return '${_formatAmount(amount, large: large)} '
        '${large ? _largeLabel : label}';
  }

  /// The unit a PRICE is quoted in, and it is always the large one:
  /// 'R$ 32,90/kg', never 'R$ 0,03/g'. **The only door to the reading unit** —
  /// the three cost-per-base-unit screens and the type magnitude subtitle come
  /// in through here, because `_largeLabel` is private. The screen has no way
  /// of picking wrong between 'kg' and 'g'.
  String get priceLabel => _largeLabel;

  /// What a TYPABLE field comes filled with: the integer, in the stored unit,
  /// with no unit glued to it. It is the other end of the same rule as
  /// [priceLabel] — no screen has to remember to pass `large: false`, and none
  /// can forget.
  String typedText(int amount) => _formatAmount(amount, large: false);

  /// How the magnitude introduces itself in the type form: 'Peso — grama (g)'.
  /// **The only place this sentence exists.**
  String get magnitudeLabel => '$magnitude — $magnitudeNoun ($label)';

  /// The pair '0,5 de 6 kg' — BOTH ends at the scale of the WHOLE, never each
  /// at its own. Without this, 900 g consumed out of a 6 kg average would come
  /// out as '900 de 6 kg'.
  String formatQuantityPair(int part, int whole) {
    final large = usesLargeUnit(whole);
    return '${_formatAmount(part, large: large)} de '
        '${_formatAmount(whole, large: large)} '
        '${large ? _largeLabel : label}';
  }
}

/// The typed amount is not a number. pt-BR: it is read on screen.
final class InvalidAmount implements Exception {
  const InvalidAmount();

  String get message => 'Informe uma quantidade válida.';

  @override
  String toString() => 'InvalidAmount: $message';
}

/// The typed amount carries a decimal separator, and no field does any more:
/// every amount is typed in the small unit of its magnitude — grams,
/// millilitres, units, centimetres — which is always a whole number.
final class AmountMustBeWhole implements Exception {
  const AmountMustBeWhole();

  String get message => 'Use um número inteiro.';

  @override
  String toString() => 'AmountMustBeWhole: $message';
}
