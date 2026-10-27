import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/record_id.dart';

void main() {
  group('record id', () {
    test('draws 15 characters', () {
      expect(newRecordId(), hasLength(recordIdLength));
      expect(recordIdLength, 15);
    });

    test('uses only lowercase letters and digits', () {
      final allowed = RegExp(r'^[a-z0-9]+$');

      for (var i = 0; i < 200; i++) {
        expect(allowed.hasMatch(newRecordId(Random(i))), isTrue);
      }
    });

    test('draws a different one every time', () {
      expect(newRecordId(), isNot(newRecordId()));
    });

    test('is deterministic with a seeded Random', () {
      expect(newRecordId(Random(7)), newRecordId(Random(7)));
    });

    test('accepts what newRecordId draws', () {
      expect(isRecordId(newRecordId()), isTrue);
      expect(isRecordId('abc123def456ghi'), isTrue);
    });

    test('refuses a uuid, empty, uppercase and the wrong length', () {
      expect(isRecordId('3f2b8c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e'), isFalse);
      expect(isRecordId(''), isFalse);
      expect(isRecordId('abc123def456gh'), isFalse);
      expect(isRecordId('abc123def456ghij'), isFalse);
      expect(isRecordId('Abc123def456ghi'), isFalse);
      expect(isRecordId('abc123def-56ghi'), isFalse);
      expect(isRecordId('abc123def456ghi\n'), isFalse);
    });
  });
}
