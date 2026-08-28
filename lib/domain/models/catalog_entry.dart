import 'name_normalization.dart';

/// What the five name-based catalogs have in common — category, product type,
/// brand, store, and (by its description) the product registration.
///
/// It exists for [findNameConflict]: writing the duplicate guard once is what
/// keeps "Limpeza" and "limpeza  " being the same thing on every screen.
abstract interface class CatalogEntry {
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
T? findNameConflict<T extends CatalogEntry>(
  Iterable<T> entries,
  String candidate,
) {
  final normalized = normalizeName(candidate);
  if (normalized.isEmpty) return null;

  for (final entry in entries) {
    if (normalizeName(entry.name) == normalized) return entry;
  }
  return null;
}

/// A name made of blanks. pt-BR: it is read on screen.
final class BlankName implements Exception {
  const BlankName();

  String get message => 'Informe um nome.';

  @override
  String toString() => 'BlankName: $message';
}
