import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_hive.dart';
import 'package:shopping_list/domain/models/device_user.dart';

/// The only storage the label ever has. On the phone this is IndexedDB; here
/// it is a temporary directory, and what is being checked is the same thing:
/// that what goes in comes back out, and that the synchronous read the
/// router's redirect depends on actually sees it.
void main() {
  late Directory directory;
  late Box<String> box;
  late DeviceUserRepositoryHive repository;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('device_user_test');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(DeviceUserRepositoryHive.boxName);
    repository = DeviceUserRepositoryHive(box);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(DeviceUserRepositoryHive.boxName);
    await Hive.close();
    directory.deleteSync(recursive: true);
  });

  test('reads nothing on a device that was never asked', () async {
    expect(await repository.read(), isNull);
    expect(repository.readNow(), isNull);
  });

  test('gives back the label it was given', () async {
    await repository.save(DeviceUser('Leandro'));

    expect(await repository.read(), DeviceUser('Leandro'));
  });

  test('answers the redirect without awaiting anything', () async {
    // go_router runs the redirect synchronously: if this ever needs an await,
    // the redirect silently starts treating every device as unmarked.
    await repository.save(DeviceUser('Esposa'));

    expect(repository.readNow(), DeviceUser('Esposa'));
  });

  test('keeps the last name, since changing it is one tap', () async {
    await repository.save(DeviceUser('Leandro'));
    await repository.save(DeviceUser('Esposa'));

    expect(repository.readNow(), DeviceUser('Esposa'));
    expect(box.length, 1, reason: 'one row, replaced — not a history');
  });

  test(
    'survives being reopened, which is what a PWA does every morning',
    () async {
      await repository.save(DeviceUser('Leandro'));
      await box.close();

      final reopened = await Hive.openBox<String>(
        DeviceUserRepositoryHive.boxName,
      );

      expect(
        DeviceUserRepositoryHive(reopened).readNow(),
        DeviceUser('Leandro'),
      );
    },
  );

  test('stores JSON, so a second field later still reads back', () async {
    // The bare name would have been simpler and would throw a cast error on a
    // phone nobody can open a console on, the day this row grows a field.
    await repository.save(DeviceUser('Leandro'));

    expect(box.get('current'), '{"name":"Leandro"}');
  });
}
