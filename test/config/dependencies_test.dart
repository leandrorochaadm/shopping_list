import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopping_list/config/dependencies.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_remote.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_hive.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_remote.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_hive.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_remote.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only its constructor is used: the three `_remote` repositories read
/// `supabaseClientProvider`, and `Supabase.instance` asserts when
/// `initialize` has not run — which is the case in EVERY test.
class _MockClient extends Mock implements SupabaseClient {}

/// The two override lists are what decides whether the app writes to a real
/// store or to a fake, and a feature that forgets a line here compiles, passes
/// every other test, and only fails on the phone — as a provider that throws
/// the first time a screen reads it.
void main() {
  test('runs every repository on its fake when there is no backend', () {
    final container = ProviderContainer.test(overrides: overridesLocal);

    expect(
      container.read(deviceUserRepositoryProvider),
      isA<DeviceUserRepositoryLocal>(),
    );
    expect(
      container.read(catalogRepositoryProvider),
      isA<CatalogRepositoryLocal>(),
    );
    expect(
      container.read(storeRepositoryProvider),
      isA<StoreRepositoryLocal>(),
    );
    expect(
      container.read(shoppingListRepositoryProvider),
      isA<ShoppingListRepositoryLocal>(),
    );
    expect(
      container.read(purchaseRepositoryProvider),
      isA<PurchaseRepositoryLocal>(),
    );
    expect(
      container.read(purchaseDraftRepositoryProvider),
      isA<PurchaseDraftRepositoryLocal>(),
    );
  });

  test('runs the label on Hive even against the real project', () async {
    // The exception that proves the rule: the label is local by decision
    // (`handoff §8` — "não vai ao banco"), so `_remote` is Hive on both sides.
    final directory = Directory.systemTemp.createTempSync('dependencies_test');
    Hive.init(directory.path);
    final box = await Hive.openBox<String>(DeviceUserRepositoryHive.boxName);
    final draftBox = await Hive.openBox<String>(
      PurchaseDraftRepositoryHive.boxName,
    );
    addTearDown(() async {
      await Hive.deleteBoxFromDisk(DeviceUserRepositoryHive.boxName);
      await Hive.deleteBoxFromDisk(PurchaseDraftRepositoryHive.boxName);
      await Hive.close();
      directory.deleteSync(recursive: true);
    });

    final container = ProviderContainer.test(
      overrides: [
        supabaseClientProvider.overrideWithValue(_MockClient()),
        deviceUserBoxProvider.overrideWithValue(box),
        purchaseDraftBoxProvider.overrideWithValue(draftBox),
        ...overridesRemote,
      ],
    );

    expect(
      container.read(deviceUserRepositoryProvider),
      isA<DeviceUserRepositoryHive>(),
    );
    // The three that DO go to the database. Forgetting one of these lines in
    // `overridesRemote` compiles, passes every other test, and only fails on
    // the phone — the first time a screen reads the provider.
    expect(
      container.read(catalogRepositoryProvider),
      isA<CatalogRepositoryRemote>(),
    );
    expect(
      container.read(storeRepositoryProvider),
      isA<StoreRepositoryRemote>(),
    );
    expect(
      container.read(shoppingListRepositoryProvider),
      isA<ShoppingListRepositoryRemote>(),
    );
    expect(
      container.read(purchaseRepositoryProvider),
      isA<PurchaseRepositoryRemote>(),
    );
    // The second exception, for the same reason as the label: the draft is a
    // purchase that is not a purchase yet, and it has to survive exactly when
    // the network does not.
    expect(
      container.read(purchaseDraftRepositoryProvider),
      isA<PurchaseDraftRepositoryHive>(),
    );
  });

  test('says which override is missing instead of failing later', () {
    // Unoverridden, both providers throw an Error — which AppFailure
    // classifies as AppBug, and the screen says the app has a problem. That
    // is exactly what a forgotten override is.
    final container = ProviderContainer.test();

    expect(
      () => container.read(deviceUserRepositoryProvider),
      throwsA(
        isA<Object>().having(
          (e) => e.toString(),
          'toString',
          contains('deviceUserRepositoryProvider'),
        ),
      ),
    );
    expect(
      () => container.read(deviceUserBoxProvider),
      throwsA(
        isA<Object>().having(
          (e) => e.toString(),
          'toString',
          contains('deviceUserBoxProvider'),
        ),
      ),
    );
    expect(
      () => container.read(purchaseDraftBoxProvider),
      throwsA(
        isA<Object>().having(
          (e) => e.toString(),
          'toString',
          contains('purchaseDraftBoxProvider'),
        ),
      ),
    );
  });
}
