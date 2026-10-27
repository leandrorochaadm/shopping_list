import 'dart:math';

/// Length of a PocketBase record id.
const recordIdLength = 15;

/// The characters a PocketBase record id is drawn from.
const recordIdAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

final _recordIdPattern = RegExp(r'^[a-z0-9]{15}$');

/// A PocketBase record id (15 chars of `[a-z0-9]`) born on the phone, written by
/// hand: the key has to be known BEFORE the write, because the batch chains
/// parent -> child by id and the 409 on a repeated id is what makes resending a
/// purchase idempotent. No package: the runtime dependency list is frozen
/// (`tecnico §3`) and this is a few lines of pure Dart.
String newRecordId([Random? random]) {
  final source = random ?? Random.secure();

  return String.fromCharCodes([
    for (var i = 0; i < recordIdLength; i++)
      recordIdAlphabet.codeUnitAt(source.nextInt(recordIdAlphabet.length)),
  ]);
}

/// Whether [value] has exactly the shape of a PocketBase record id.
bool isRecordId(String value) => _recordIdPattern.hasMatch(value);
