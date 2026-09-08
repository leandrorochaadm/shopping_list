/// Money, and it is an INTEGER number of cents — never a `double`.
///
/// That is `R15` and decision B5, and the reason is one line long: `0.35 *
/// 100` in binary floating point is 34.999999999999996, and one truncation
/// later R$ 0,35 has become R$ 0,34. Every cent in this app is born, stored,
/// added and displayed as an int; the only rounding allowed is in the
/// formatting, and it lives in `ui/core/formatting.dart`.
final class Money implements Comparable<Money> {
  const Money(this.cents);

  /// Reads what was typed — '56,70', '56.70', '56' — and returns the cents.
  ///
  /// Same algorithm as `BaseUnit.parseAmount`, and for the same reason: it
  /// is done digit by digit and NEVER goes through a double. A comma and a
  /// dot are both accepted because the iOS number keyboard offers whichever
  /// the layout feels like.
  factory Money.parse(String typed) {
    final cleaned = typed.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) throw const InvalidMoney();

    final parts = cleaned.split('.');
    if (parts.length > 2) throw const InvalidMoney();

    final whole = parts.first;
    final fraction = parts.length == 2 ? parts[1] : '';
    if (whole.isEmpty && fraction.isEmpty) throw const InvalidMoney();
    if (!_isDigits(whole) || !_isDigits(fraction)) throw const InvalidMoney();

    // There is no third decimal place in money. '56,700' is a typo, not
    // seven tenths of a cent, and swallowing it would put R$ 56,70 on a
    // receipt that said something else.
    if (fraction.length > 2) throw const InvalidMoney();

    final scaled = fraction.padRight(2, '0');
    return Money(
      int.parse(whole.isEmpty ? '0' : whole) * 100 +
          int.parse(scaled.isEmpty ? '0' : scaled),
    );
  }

  /// What PostgREST returns for the `bigint` cents column. `num` and not
  /// `int` because a JSON number that fits in an int still arrives as a num
  /// through some paths.
  factory Money.fromJson(Object? value) =>
      Money((value as num?)?.toInt() ?? 0);

  static const zero = Money(0);

  final int cents;

  int toJson() => cents;

  bool get isZero => cents == 0;

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator >(Money other) => cents > other.cents;

  static bool _isDigits(String value) =>
      value.isEmpty || RegExp(r'^\d+$').hasMatch(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && other.cents == cents);

  @override
  int get hashCode => cents.hashCode;

  /// Never read on screen — `formatMoney` is what the user sees. This is for
  /// the debugger and for a failed test's message.
  @override
  String toString() => 'Money($cents)';
}

/// The typed value is not a value. pt-BR: it is read on screen.
final class InvalidMoney implements Exception {
  const InvalidMoney();

  String get message => 'Informe um valor válido.';

  @override
  String toString() => 'InvalidMoney: $message';
}
