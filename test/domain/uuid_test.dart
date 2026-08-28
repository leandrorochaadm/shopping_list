import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/uuid.dart';

void main() {
  group('newUuidV4', () {
    test('has the shape a uuid column accepts', () {
      final value = newUuidV4();

      expect(value.length, 36);
      expect(value[8], '-');
      expect(value[13], '-');
      expect(value[18], '-');
      expect(value[23], '-');
      expect(RegExp(r'^[0-9a-f-]+$').hasMatch(value), isTrue, reason: value);
    });

    test('says it is a version 4 with the RFC variant', () {
      for (var i = 0; i < 20; i++) {
        final value = newUuidV4(Random(i));

        expect(value[14], '4', reason: value);
        expect('89ab', contains(value[19]), reason: value);
      }
    });

    test('draws a different one every time', () {
      expect(newUuidV4(), isNot(newUuidV4()));
    });

    test('is deterministic with a seeded Random — which tests can rely on', () {
      expect(newUuidV4(Random(7)), newUuidV4(Random(7)));
    });
  });
}
