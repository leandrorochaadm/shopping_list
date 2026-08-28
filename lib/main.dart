import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/dependencies.dart';
import 'config/environment.dart';
import 'config/startup.dart';
import 'routing/router.dart';
import 'ui/core/app_locale.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/core/widgets/misconfigured_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Required by the pt_BR DateFormat used across the screens.
    await initializeDateFormatting('pt_BR');

    // Hive holds exactly two things (`tecnico §4.2`): the purchase draft and
    // the device user label. On web it writes to IndexedDB — which Safari
    // denies in a private window — and that is also why the app MUST be
    // tested installed on the home screen: an installed PWA and a Safari tab
    // have separate storage.
    await Hive.initFlutter();
  } on Object catch (e, st) {
    debugPrint('Local storage unavailable: $e\n$st');
    runApp(const MisconfiguredApp.storageUnavailable());
    return;
  }

  final List<Override> overrides;
  final bool usingFakes;
  switch (resolveStartup(
    configured: Environment.isSupabaseConfigured,
    debug: kDebugMode,
  )) {
    case StartupPlan.remote:
      try {
        await Environment.initializeSupabase();
      } on Object catch (e, st) {
        // The defines were there and the SDK still refused to start: a wrong
        // project URL, an anon key from another project. Letting it escape
        // from main paints a white screen, and an installed PWA has no
        // console to explain one.
        debugPrint('Supabase.initialize failed: $e\n$st');
        runApp(const MisconfiguredApp.startupFailed());
        return;
      }
      overrides = overridesRemote;
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
      overrides: overrides,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Lista de compras',
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

  // topStart because the debug checked-mode banner already owns topEnd.
  static Widget _fakeDataBanner(BuildContext context, Widget? child) => Banner(
    message: 'DADOS FAKE',
    location: BannerLocation.topStart,
    child: child ?? const SizedBox.shrink(),
  );
}
