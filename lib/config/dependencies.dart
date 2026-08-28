import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/catalog/catalog_repository.dart';
import '../data/repositories/catalog/catalog_repository_local.dart';
import '../data/repositories/catalog/catalog_repository_remote.dart';
import '../data/repositories/device_user/device_user_repository.dart';
import '../data/repositories/device_user/device_user_repository_hive.dart';
import '../data/repositories/device_user/device_user_repository_local.dart';
import '../data/repositories/shopping_list/shopping_list_repository.dart';
import '../data/repositories/shopping_list/shopping_list_repository_local.dart';
import '../data/repositories/shopping_list/shopping_list_repository_remote.dart';
import '../data/repositories/store/store_repository.dart';
import '../data/repositories/store/store_repository_local.dart';
import '../data/repositories/store/store_repository_remote.dart';

/// The Supabase client, injected into every `_remote` repository as a PRIVATE
/// member — the UI never reaches it.
///
/// No `retry`: a failure here means `Supabase.initialize` did not run, which
/// is an initialization Error, and Riverpod's automatic retry skips Errors.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// The Hive box `main` opens before runApp, handed over already open.
///
/// It is a provider and not a global so tests can hand over their own — and
/// so the failure of a phone that denies IndexedDB stays in `main`, where it
/// becomes `MisconfiguredApp.storageUnavailable()` instead of an exception
/// thrown from inside the first repository call.
final deviceUserBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError(
    'deviceUserBoxProvider was not overridden. main opens the box before '
    'runApp and overrides it there.',
  ),
);

/// Demo and development without a backend: every repository is overridden with
/// its `_local` fake.
///
/// Each feature adds ONE line here — the repository provider itself is
/// declared next to its repository, and the override lives in this list.
final List<Override> overridesLocal = [
  deviceUserRepositoryProvider.overrideWith(
    (ref) => DeviceUserRepositoryLocal(),
  ),
  catalogRepositoryProvider.overrideWith((ref) => CatalogRepositoryLocal()),
  storeRepositoryProvider.overrideWith((ref) => StoreRepositoryLocal()),
  shoppingListRepositoryProvider.overrideWith(
    (ref) => ShoppingListRepositoryLocal(),
  ),
];

/// Production and `dev` against the real Supabase project. Requires
/// `Environment.initializeSupabase()` to have run in `main`.
///
/// The device user label is the exception that proves the rule: it is local by
/// decision (`handoff §8` — "não vai ao banco"), so its real implementation is
/// Hive on both sides of this list.
final List<Override> overridesRemote = [
  deviceUserRepositoryProvider.overrideWith(
    (ref) => DeviceUserRepositoryHive(ref.watch(deviceUserBoxProvider)),
  ),
  catalogRepositoryProvider.overrideWith(
    (ref) => CatalogRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
  storeRepositoryProvider.overrideWith(
    (ref) => StoreRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
  shoppingListRepositoryProvider.overrideWith(
    (ref) => ShoppingListRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
];
