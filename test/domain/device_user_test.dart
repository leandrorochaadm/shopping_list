import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/device_user.dart';

void main() {
  group('DeviceUser', () {
    test('keeps the name it was given', () {
      expect(DeviceUser('Leandro').name, 'Leandro');
    });

    test('trims the name, since the label is copied onto every purchase', () {
      // '  Leandro ' and 'Leandro' have to be the same person in the history.
      expect(DeviceUser('  Leandro ').name, 'Leandro');
      expect(DeviceUser('  Leandro '), DeviceUser('Leandro'));
    });

    test('refuses a name that is empty once trimmed', () {
      // The boundary: a single space is still nothing. Accepting it would put
      // a blank column on the purchase history with nobody able to say whose
      // it was.
      expect(() => DeviceUser(''), throwsA(isA<EmptyDeviceUserName>()));
      expect(() => DeviceUser('   '), throwsA(isA<EmptyDeviceUserName>()));
      expect(() => DeviceUser('\n\t'), throwsA(isA<EmptyDeviceUserName>()));
    });

    test('accepts a single character, which is the other boundary', () {
      expect(DeviceUser('L').name, 'L');
      expect(DeviceUser(' L ').name, 'L');
    });

    test('says what to do when the name is empty', () {
      // The sentence reaches the screen, so it is pt-BR and it has to ask for
      // an action instead of describing the error.
      const failure = EmptyDeviceUserName();

      expect(failure.message, 'Escolha quem está usando este aparelho.');
      expect(failure.toString(), contains(failure.message));
    });

    test('suggests the two people the app was built for', () {
      // Suggestions, not a closed set — the entity accepts any non-blank name.
      expect(DeviceUser.suggestedNames, ['Leandro', 'Esposa']);
      expect(DeviceUser('Terceiro').name, 'Terceiro');
    });

    test('survives the round trip through JSON', () {
      final user = DeviceUser('Leandro');

      expect(DeviceUser.fromJson(user.toJson()), user);
      expect(user.toJson(), {'name': 'Leandro'});
    });

    test('compares by every field it has', () {
      // Riverpod filters updates with ==: an entity that compares by
      // reference would repaint the screen on every read.
      expect(DeviceUser('Leandro'), DeviceUser('Leandro'));
      expect(DeviceUser('Leandro').hashCode, DeviceUser('Leandro').hashCode);
      expect(DeviceUser('Leandro'), isNot(DeviceUser('Esposa')));
    });

    test('copies with a new name, applying the same rule', () {
      expect(DeviceUser('Leandro').copyWith(name: 'Esposa').name, 'Esposa');
      expect(DeviceUser('Leandro').copyWith().name, 'Leandro');
      expect(
        () => DeviceUser('Leandro').copyWith(name: ' '),
        throwsA(isA<EmptyDeviceUserName>()),
      );
    });

    test('names itself in a log line', () {
      expect(DeviceUser('Leandro').toString(), 'DeviceUser(Leandro)');
    });
  });
}
