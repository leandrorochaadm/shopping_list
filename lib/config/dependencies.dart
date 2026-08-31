import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  purchaseRepositoryProvider.overrideWith(
    (ref) => PurchaseRepositoryRemote(ref.watch(supabaseClientProvider)),
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
