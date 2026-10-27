import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shopping_list/data/services/auth_store_hive.dart';

import '../helpers/pocketbase_test_client.dart';

RecordModel _user() => RecordModel.fromJson({
  'id': testUserId,
  'collectionId': '_pb_users_auth_',
  'collectionName': 'users',
});

void main() {
  late Directory directory;
  late Box<String> box;
  final token = fakeAuthToken(DateTime.utc(2100));

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('auth_store_test');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(authBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(authBoxName);
    await Hive.close();
    directory.deleteSync(recursive: true);
  });

  test('starts signed out on an empty box', () {
    final store = buildAuthStore(box);

    expect(store.token, isEmpty);
    expect(store.isValid, isFalse);
  });

  test('writes the session under the session key', () async {
    buildAuthStore(box).save(token, _user());
    await pumpEventQueue();

    final stored = jsonDecode(box.get('session')!) as Map<String, dynamic>;
    expect(stored['token'], token);
  });

  test('reads back the session after the box is reopened', () async {
    buildAuthStore(box).save(token, _user());
    await pumpEventQueue();
    await Hive.close();
    box = await Hive.openBox<String>(authBoxName);

    final store = buildAuthStore(box);

    expect(store.token, token);
    expect(store.record?.id, testUserId);
    expect(store.isValid, isTrue);
  });

  test('deletes the session key on clear', () async {
    final store = buildAuthStore(box)..save(token, _user());
    await pumpEventQueue();

    store.clear();
    await pumpEventQueue();

    expect(box.containsKey('session'), isFalse);
  });

  test('starts signed out and drops an unreadable session', () async {
    await box.put('session', 'not json {');

    final store = buildAuthStore(box);

    expect(store.token, isEmpty);
    expect(box.containsKey('session'), isFalse);
  });

  test('keeps one row, replaced on each save', () async {
    final store = buildAuthStore(box)
      ..save(token, _user())
      ..save(fakeAuthToken(DateTime.utc(2101)), _user());
    await pumpEventQueue();

    expect(box.length, 1);
    expect(store.token, isNot(token));
  });
}
