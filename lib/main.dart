import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketbase/pocketbase.dart';

import 'config/app_config.dart';
import 'config/dependencies.dart';
import 'config/startup.dart';
import 'data/repositories/auth/auth_repository_remote.dart';
import 'data/repositories/device_user/device_user_repository_hive.dart';
import 'data/repositories/purchase_draft/purchase_draft_repository_hive.dart';
import 'data/services/auth_store_hive.dart';
import 'routing/router.dart';
import 'ui/core/app_locale.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/core/widgets/misconfigured_app.dart';
import 'ui/purchase/view_model/pending_purchase_submitter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Two `try` blocks, not one: they fail for unrelated reasons and are fixed
  // in different places, and a single catch would put "the browser blocked
  // storage" on the screen when what broke was the date formatting.
  try {
    // Required by the pt_BR DateFormat used across the screens.
    await initializeDateFormatting('pt_BR');
  } on Object catch (e, st) {
    debugPrint('Locale data unavailable: $e\n$st');
    runApp(const MisconfiguredApp.formattingUnavailable());
    return;
  }

  final Box<String> deviceUserBox;
  final Box<String> purchaseDraftBox;
  final Box<String> authBox;
  try {
    // Hive holds three things (`tecnico §4.2`): the purchase draft, the
    // device user label and the session. On web it writes to IndexedDB — which Safari
    // denies in a private window — and that is also why the app MUST be
    // tested installed on the home screen: an installed PWA and a Safari tab
    // have separate storage.
    await Hive.initFlutter();

    // Opened HERE, before runApp, and not inside the repository: after this
    // line `box.get` is synchronous, which is what lets the router's redirect
    // — which go_router runs synchronously — ask whether this phone already
    // has a label. openBox is also refused in a private window, and the right
    // outcome for that is this screen, never a white one.
    deviceUserBox = await Hive.openBox<String>(
      DeviceUserRepositoryHive.boxName,
    );
    // The second box, opened in the SAME try: a phone that denies IndexedDB
    // denies both, and the purchase draft is the half of the app that exists
    // for the moment the network does not. Discovering the refusal from
    // inside screen 3, with eighteen items typed, is the one outcome worth
    // avoiding at any cost.
    purchaseDraftBox = await Hive.openBox<String>(
      PurchaseDraftRepositoryHive.boxName,
    );
    await PurchaseDraftRepositoryHive.discardLegacyDraft(purchaseDraftBox);
    // The third box, in the SAME try: a browser that denies IndexedDB denies
    // all three, and without the session box no login survives closing the app.
    authBox = await Hive.openBox<String>(authBoxName);
  } on Object catch (e, st) {
    debugPrint('Local storage unavailable: $e\n$st');
    runApp(const MisconfiguredApp.storageUnavailable());
    return;
  }

  final config = AppConfig.fromEnvironment();
  final List<Override> overrides;
  final bool usingFakes;
  switch (resolveStartup(
    configured: config.missingKeys.isEmpty,
    debug: kDebugMode,
  )) {
    case StartupPlan.remote:
      final PocketBase pb;
      try {
        pb = PocketBase(
          config.pocketBaseUrl,
          authStore: buildAuthStore(authBox),
        );
        await restoreSession(pb);
      } on Object catch (e, st) {
        // The address was there and the client still failed to start. Letting
        // it escape from main paints a white screen, and an installed PWA has
        // no console to explain one.
        debugPrint('PocketBase startup failed: $e\n$st');
        runApp(const MisconfiguredApp.startupFailed());
        return;
      }
      overrides = [
        pocketBaseProvider.overrideWithValue(pb),
        ...overridesRemote,
      ];
      usingFakes = false;
    case StartupPlan.fakes:
      overrides = overridesLocal;
      usingFakes = true;
    case StartupPlan.missingConfiguration:
      runApp(const MisconfiguredApp());
      return;
  }

  runApp(
    ProviderScope(
      overrides: [
        deviceUserBoxProvider.overrideWithValue(deviceUserBox),
        purchaseDraftBoxProvider.overrideWithValue(purchaseDraftBox),
        authBoxProvider.overrideWithValue(authBox),
        ...overrides,
      ],
      child: ShoppingListApp(usingFakes: usingFakes),
    ),
  );
}

class ShoppingListApp extends ConsumerWidget {
  const ShoppingListApp({super.key, this.usingFakes = false});

  /// True when the repositories are the `_local` fakes — debug only. Nothing
  /// typed on the screens reaches a database then, and a mark on the screen is
  /// the only way to know: there is no console to read in an installed PWA.
  final bool usingFakes;

  /// The SnackBar of the automatic resend is born OUTSIDE any Scaffold — it
  /// belongs to the app, not to a screen — so the messenger has to be
  /// reachable from here.
  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `listen`, NEVER `watch`: watching would rebuild the whole
    // MaterialApp.router on every transition of the resend — an entire screen
    // repainted to show one SnackBar.
    ref.listen(pendingPurchaseSubmitterProvider, (_, status) {
      if (status != PendingSubmission.sent) return;
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('A compra pendente foi salva.')),
      );
    });

    return MaterialApp.router(
      title: 'Lista de compras',
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light,
      // Portrait phone only (tecnico 7.3, decision 2). Landscape is not
      // preventable on web and is left untested by decision, not by omission.
      routerConfig: ref.watch(appRouterProvider),
      // Without this, showDatePicker and the Material tooltips stay in English
      // even though the screens render pt-BR dates.
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: ptBrLocale,
      builder: usingFakes ? _fakeDataBanner : null,
    );
  }

  // topStart because the debug checked-mode banner already owns topEnd.
  static Widget _fakeDataBanner(BuildContext context, Widget? child) => Banner(
    message: 'DADOS FAKE',
    location: BannerLocation.topStart,
    child: child ?? const SizedBox.shrink(),
  );
}
