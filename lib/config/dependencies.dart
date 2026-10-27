import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/auth/auth_repository.dart';
import '../data/repositories/auth/auth_repository_local.dart';
import '../data/repositories/auth/auth_repository_remote.dart';
import '../data/repositories/catalog/catalog_repository.dart';
import '../data/repositories/catalog/catalog_repository_local.dart';
import '../data/repositories/catalog/catalog_repository_remote.dart';
import '../data/repositories/consumption/consumption_repository.dart';
import '../data/repositories/consumption/consumption_repository_local.dart';
import '../data/repositories/consumption/consumption_repository_remote.dart';
import '../data/repositories/device_user/device_user_repository.dart';
import '../data/repositories/device_user/device_user_repository_hive.dart';
import '../data/repositories/device_user/device_user_repository_local.dart';
import '../data/repositories/purchase/purchase_repository.dart';
import '../data/repositories/purchase/purchase_repository_local.dart';
import '../data/repositories/purchase/purchase_repository_remote.dart';
import '../data/repositories/purchase_draft/purchase_draft_repository.dart';
import '../data/repositories/purchase_draft/purchase_draft_repository_hive.dart';
import '../data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import '../data/repositories/report/report_repository.dart';
import '../data/repositories/report/report_repository_local.dart';
import '../data/repositories/report/report_repository_remote.dart';
import '../data/repositories/shopping_list/shopping_list_repository.dart';
import '../data/repositories/shopping_list/shopping_list_repository_local.dart';
import '../data/repositories/shopping_list/shopping_list_repository_remote.dart';
import '../data/repositories/spending_cap/spending_cap_repository.dart';
import '../data/repositories/spending_cap/spending_cap_repository_local.dart';
import '../data/repositories/spending_cap/spending_cap_repository_remote.dart';
import '../data/repositories/store/store_repository.dart';
import '../data/repositories/store/store_repository_local.dart';
import '../data/repositories/store/store_repository_remote.dart';

/// The PocketBase client, built by `main` before runApp and handed over with
/// the session already restored.
///
/// It is a PRIVATE member of each `_remote` repository — the UI never reaches
/// it. No `retry`: throwing here is an Error, which Riverpod's automatic retry
/// already skips.
final pocketBaseProvider = Provider<PocketBase>(
  (ref) => throw UnimplementedError(
    'pocketBaseProvider was not overridden. main builds the client before '
    'runApp and overrides it there.',
  ),
);

/// Kept only so the `_remote` repositories that have not moved to PocketBase
/// yet still compile; reading it in the app throws.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => throw UnimplementedError(
    'supabaseClientProvider is no longer initialized: this repository has not '
    'moved to PocketBase yet.',
  ),
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

/// The second box `main` opens before runApp, and the second — and last —
/// thing Hive holds (`tecnico §4.2`): the purchase being typed.
///
/// It is separate from [deviceUserBoxProvider] rather than a second key in
/// the same box because the two have unrelated lifetimes: the label is
/// written once per phone and the draft is cleared after every purchase.
final purchaseDraftBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError(
    'purchaseDraftBoxProvider was not overridden. main opens the box before '
    'runApp and overrides it there.',
  ),
);

/// The third and last box `main` opens before runApp (`tecnico §4.2` now also
/// holds the session).
///
/// It is separate from the other two because the session lives and dies with
/// the login, not with the device label nor with the purchase draft.
final authBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError(
    'authBoxProvider was not overridden. main opens the box before runApp and '
    'overrides it there.',
  ),
);

/// Demo and development without a backend: every repository is overridden with
/// its `_local` fake.
///
/// Each feature adds ONE line here — the repository provider itself is
/// declared next to its repository, and the override lives in this list.
final List<Override> overridesLocal = [
  authRepositoryProvider.overrideWith((ref) {
    final repository = AuthRepositoryLocal();
    ref.onDispose(repository.dispose);
    return repository;
  }),
  deviceUserRepositoryProvider.overrideWith(
    (ref) => DeviceUserRepositoryLocal(),
  ),
  catalogRepositoryProvider.overrideWith((ref) => CatalogRepositoryLocal()),
  storeRepositoryProvider.overrideWith((ref) => StoreRepositoryLocal()),
  shoppingListRepositoryProvider.overrideWith(
    (ref) => ShoppingListRepositoryLocal(),
  ),
  // `sameDayBuyer` is what makes H14 visible in debug: the fake answers that
  // "esposa" already bought the soft drink on whatever day is asked about, and
  // the seeded purchases cannot do it — their dates are fixed and fall out of
  // the "hoje ou ontem" window (D-m).
  purchaseRepositoryProvider.overrideWith(
    (ref) => PurchaseRepositoryLocal(sameDayBuyer: 'esposa'),
  ),
  reportRepositoryProvider.overrideWith((ref) => ReportRepositoryLocal()),
  // The twin of the line above, and it is not a coincidence: the two fakes
  // hold the SAME purchases (decision E-l), so screens 5 and 6 never disagree
  // about the same month in debug.
  consumptionRepositoryProvider.overrideWith(
    (ref) => ConsumptionRepositoryLocal(),
  ),
  spendingCapRepositoryProvider.overrideWith(
    (ref) => SpendingCapRepositoryLocal(),
  ),
  // In memory, not Hive: a draft that survived a restart of a fake-data
  // session would outlive the fake catalog it points at.
  purchaseDraftRepositoryProvider.overrideWith(
    (ref) => PurchaseDraftRepositoryLocal(),
  ),
];

/// Production and `dev` against the PocketBase server; requires `main` to
/// override `pocketBaseProvider` (session already restored) and the three
/// boxes.
///
/// The device user label is the exception that proves the rule: it is local by
/// decision (`handoff §8` — "não vai ao banco"), so its real implementation is
/// Hive on both sides of this list.
final List<Override> overridesRemote = [
  authRepositoryProvider.overrideWith(
    (ref) => AuthRepositoryRemote(ref.watch(pocketBaseProvider)),
  ),
  deviceUserRepositoryProvider.overrideWith(
    (ref) => DeviceUserRepositoryHive(ref.watch(deviceUserBoxProvider)),
  ),
  catalogRepositoryProvider.overrideWith(
    (ref) => CatalogRepositoryRemote(ref.watch(pocketBaseProvider)),
  ),
  storeRepositoryProvider.overrideWith(
    (ref) => StoreRepositoryRemote(ref.watch(pocketBaseProvider)),
  ),
  shoppingListRepositoryProvider.overrideWith(
    (ref) => ShoppingListRepositoryRemote(ref.watch(pocketBaseProvider)),
  ),
  purchaseRepositoryProvider.overrideWith(
    (ref) => PurchaseRepositoryRemote(ref.watch(pocketBaseProvider)),
  ),
  reportRepositoryProvider.overrideWith(
    (ref) => ReportRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
  consumptionRepositoryProvider.overrideWith(
    (ref) => ConsumptionRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
  spendingCapRepositoryProvider.overrideWith(
    (ref) => SpendingCapRepositoryRemote(ref.watch(supabaseClientProvider)),
  ),
  // The second exception, for the same reason as the label: the draft is a
  // purchase that is not a purchase yet, and it must survive precisely when
  // the network does not.
  purchaseDraftRepositoryProvider.overrideWith(
    (ref) => PurchaseDraftRepositoryHive(ref.watch(purchaseDraftBoxProvider)),
  ),
];
