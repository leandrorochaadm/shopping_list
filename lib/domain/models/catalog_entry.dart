import 'name_normalization.dart';

/// What the FOUR name-based catalogs have in common — category, product
/// type, brand and store.
///
/// **The product registration is not one of them**, and this comment used to
/// say it was. Its guard is not a name at all: it is the triple identity of
/// `hasSameIdentityAs`/`conflictIn` — type + brand + normalized description —
/// and `Product` has no name whatsoever, only content. While `id` did not
/// exist here the difference was academic; from H10 on it stops being, because
/// whoever reads "five" goes looking for [findNameConflict]'s `ignoringId` on
/// the wrong guard — and the wrong guard accepts two identical descriptions
/// under the same type and brand.
///
/// It exists for [findNameConflict]: writing the duplicate guard once is what
/// keeps "Limpeza" and "limpeza  " being the same thing on every screen.
abstract interface class CatalogEntry {
  /// Null before the row exists. It is here because of RENAMING: without it
  /// the duplicate guard reports the very line being edited as a conflict,
  /// and correcting "Carrefur" to "Carrefour" would be impossible (D8).
  String? get id;

  String get name;

  /// Nothing is ever deleted (decision 19), so every catalog carries this.
  bool get active;
}

/// The duplicate guard, and the app's answer to the user — the unique index in
/// Postgres is only the net underneath.
///
/// Returns the entry that already uses [candidate], **active or not**: that is
/// decision B3. A deactivated "Limpeza" blocks a new "Limpeza", and the screen
/// offers to REACTIVATE the one that exists instead of creating a second one —
/// which is what keeps a catalog's whole history in one place.
/// [ignoringId] is the row being renamed. It is never a conflict with itself,
/// and leaving it out is what would make correcting an accent impossible (D8).
/// Creating passes nothing and every row counts.
T? findNameConflict<T extends CatalogEntry>(
  Iterable<T> entries,
  String candidate, {
  String? ignoringId,
}) {
  final normalized = normalizeName(candidate);
  if (normalized.isEmpty) return null;

  for (final entry in entries) {
    if (ignoringId != null && entry.id == ignoringId) continue;
    if (normalizeName(entry.name) == normalized) return entry;
  }
  return null;
}

/// What the duplicate guard SAYS, in one place — pt-BR, because it is read on
/// screen, and written here rather than in a ViewModel because there are three
/// of them saying it.
///
/// **It carries no destination, and that is the point.** Until H10 both copies
/// of this sentence ended in "Reative-o na manutenção do cadastro", which was
/// a detour: whoever reads it is holding a receipt in the middle of an entry,
/// and the way out offered was to leave the screen, find the row in a list of
/// six catalogs and come back to type everything again. Since 29/08/2026 the
/// dialog that shows this offers `[ Reativar ]` right there, so the sentence
/// says WHAT happened and the button says what to do about it.
///
/// [noun] is the catalog with its article — 'a categoria', 'o mercado'. The
/// deactivated sentence deliberately uses "o cadastro" instead: the adjective
/// has to agree in gender, and one neutral noun beats six sentences drifting
/// apart.
String nameConflictMessage(CatalogEntry conflict, String noun) =>
    conflict.active
    ? 'Já existe $noun ${conflict.name}.'
    : 'O cadastro ${conflict.name} existe, mas está desativado.';

/// A name made of blanks. pt-BR: it is read on screen.
final class BlankName implements Exception {
  const BlankName();

  String get message => 'Informe um nome.';

  @override
  String toString() => 'BlankName: $message';
}
