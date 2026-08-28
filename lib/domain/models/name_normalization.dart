/// The Dart half of the catalog's duplicate guard.
///
/// The other half is `normalize_name(text)` in
/// `supabase/migrations/20260827090000_normalize_function.sql`, and the two
/// have to agree: the app is what ANSWERS the user ("esse produto já existe"),
/// and the unique index over the generated column is the net underneath.
///
/// **Removing accents is a table written by hand, and that is a decision.**
/// Dart has no Unicode normalization in its core library — there is no
/// `String.normalize()`, `intl` does not do it, and the dependency list is
/// frozen (`tecnico §3`). So the table below covers what Portuguese uses,
/// plus the Latin-1 letters that show up in imported brand names.
///
/// It is necessarily SMALLER than the `unaccent` dictionary Postgres uses.
/// A letter outside it — the `ř` of "Dvořák", the `ø` of "Smørrebrød" — is
/// stripped by the database and kept here, so the app would offer to create
/// what the index then refuses. The failure is safe (the write is rejected and
/// the user reads "já existe um cadastro com esses dados") but the sentence
/// arrives without the app having explained it first. Widening the table is
/// the fix, and `supabase/checks/normalize_cases.sql` is what exposes the gap.
library;

/// Lower case, no surrounding blanks, no accents — the same three things the
/// SQL function does, in the same order.
String normalizeName(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_withoutAccent[character] ?? character);
  }
  return buffer.toString();
}

/// Lower case only: [normalizeName] lowers the string before looking here, so
/// the upper-case halves would be dead entries.
const _withoutAccent = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
  'ý': 'y',
  'ÿ': 'y',
};
