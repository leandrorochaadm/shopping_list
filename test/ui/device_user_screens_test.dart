import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/device_user.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/report/widgets/reports_screen.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/report.dart';
import '../helpers/shopping_list.dart';

/// The `_local` fake that always says no, for the two screens' error paths.
class _FailingRepository extends DeviceUserRepositoryLocal {
  _FailingRepository({super.initial, this.onRead, this.onSave})
    : super(latency: Duration.zero);

  final Object? onRead;
  final Object? onSave;

  @override
  Future<DeviceUser?> read() async {
    if (onRead != null) throw onRead!;
    return super.read();
  }

  @override
  Future<void> save(DeviceUser user) async {
    if (onSave != null) throw onSave!;
    return super.save(user);
  }
}

void main() {
  // Since H11 this file reaches `/reports`, which draws dates and month
  // names — and `main()` does not run in a test.
  setUpAll(initializePtBr);

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required List<Override> overrides,
    String? at,
  }) async {
    // Since H4 the root route is the real screen 1, so the app cannot be
    // pumped without the list's repository — even to open settings, because
    // `/` is what the router starts on.
    final container = ProviderContainer.test(
      overrides: [
        ...overrides,
        shoppingListOverride(),
        catalogOverride(),
        // Since H11 `/reports` is a real screen: without this the contract's
        // UnimplementedError is thrown the moment it mounts.
        reportOverride(),
      ],
    );
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (at != null) router.go(at);
    await tester.pumpAndSettle();
    return router;
  }

  Override failingWith({Object? onRead, Object? onSave, String? initial}) =>
      deviceUserRepositoryProvider.overrideWith(
        (ref) => _FailingRepository(
          initial: initial == null ? null : DeviceUser(initial),
          onRead: onRead,
          onSave: onSave,
        ),
      );

  group('WelcomeScreen', () {
    testWidgets('asks the question and offers the two names', (tester) async {
      await pumpApp(tester, overrides: [deviceUserOverride(name: null)]);

      expect(find.text('Quem está usando?'), findsOneWidget);
      expect(find.byKey(const Key('device-user-Leandro')), findsOneWidget);
      expect(find.byKey(const Key('device-user-Esposa')), findsOneWidget);
    });

    testWidgets('keeps Continuar disabled until a name is chosen', (
      tester,
    ) async {
      // Saving nothing would write a blank label, and the domain would refuse
      // it — better to not offer the tap at all.
      await pumpApp(tester, overrides: [deviceUserOverride(name: null)]);

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('device-user-Leandro')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('saves the label and opens the list, once and for all', (
      tester,
    ) async {
      // The second acceptance criterion of H1: after this, the redirect never
      // fires again on this device.
      final router = await pumpApp(
        tester,
        overrides: [deviceUserOverride(name: null)],
      );

      await tester.tap(find.byKey(const Key('device-user-Esposa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Lista de compras'), findsOneWidget);

      router.go(Routes.reports);
      await tester.pumpAndSettle();
      // By the WIDGET and not by the text: 'Relatórios' is the app bar title
      // AND the bottom bar's own label, so `find.text` finds two.
      expect(find.byType(ReportsScreen), findsOneWidget);
    });

    testWidgets('stays put and explains itself when the save fails', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [failingWith(onSave: NetworkException('offline'))],
      );

      await tester.tap(find.byKey(const Key('device-user-Leandro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Quem está usando?'), findsOneWidget);
      expect(find.text('Lista de compras'), findsNothing);
    });

    testWidgets('offers a way out when the label cannot even be read', (
      tester,
    ) async {
      // There is no previous value on a first opening, so the failure owns the
      // screen — and a screen with no exit would be a dead end (R11).
      await pumpApp(
        tester,
        overrides: [failingWith(onRead: NetworkException('offline'))],
      );

      expect(
        find.text('Não foi possível abrir o app neste aparelho.'),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    testWidgets('shows who is marked on this device', (tester) async {
      await pumpApp(
        tester,
        overrides: [deviceUserOverride()],
        at: Routes.settings,
      );

      expect(find.text('Configurações'), findsOneWidget);
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const Key('device-user-Leandro')),
            )
            .value,
        'Leandro',
      );
    });

    testWidgets('changes the label on the tap, with no confirmation', (
      tester,
    ) async {
      // "Sem senha e sem confirmação" is the acceptance criterion, word for
      // word: it is a label, not an identity.
      await pumpApp(
        tester,
        overrides: [deviceUserOverride()],
        at: Routes.settings,
      );

      await tester.tap(find.byKey(const Key('device-user-Esposa')));
      await tester.pumpAndSettle();

      expect(find.text('Agora este aparelho é Esposa.'), findsOneWidget);
    });

    testWidgets('says so when the change could not be saved', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          failingWith(initial: 'Leandro', onSave: ApiException(500, 'boom')),
        ],
        at: Routes.settings,
      );

      await tester.tap(find.byKey(const Key('device-user-Esposa')));
      await tester.pumpAndSettle();

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
    });
  });
}
