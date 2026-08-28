import 'dart:math';

/// A version 4 UUID over `Random.secure()`, written by hand: the runtime
/// dependency list is frozen at seven (`tecnico §3`) and this is a dozen lines
/// of pure Dart. The `uuid` package IS in `pubspec.lock` as a transitive of
/// `supabase_flutter`, and importing a transitive is exactly what the
/// `depend_on_referenced_packages` lint catches.
///
/// It exists because the key has to be known BEFORE the write: the Realtime
/// echo of an INSERT can arrive ahead of the HTTP response, and discarding it
/// is only possible with the id in hand. It is the same reason `purchase.id`
/// is already born on the phone in the base schema — and it makes resending an
/// `add` that timed out idempotent instead of a second item on the list.
String newUuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));

  // Version 4 in the high nibble of byte 6, and variant 10xx in byte 8 — the
  // two fields RFC 4122 pins down.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
