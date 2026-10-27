import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/device_user.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/ui/settings/widgets/settings_screen.dart';

import '../helpers/device_user.dart';
import '../helpers/locale.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends SpendingCapRepositoryLocal {
  _SpyRepository({super.cap, super.spending, super.today})
    : super(latency: Duration.zero);

  Object? failNextRead;
  Object? failNextWrite;

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(
    IList<ReportPeriod> months,
  ) async {
    final failure = failNextRead;
    failNextRead = null;
    if (failure != null) throw failure;
    return super.fetchStatuses(months);
  }

  @override
  Future<void> save({
    required SpendingCap cap,
    required CapAlerts alerts,
  }) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    return super.save(cap: cap, alerts: alerts);
  }
}

class _SpySessionRepository extends AuthRepositoryLocal {
  _SpySessionRepository({super.latency = Duration.zero})
    : super(signedIn: true);

  Object? failNextCall;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.signOut();
  }
}

/// A fake that never answers, so the loading state can be SEEN.
class _NeverAnswers extends SpendingCapRepositoryLocal {
  _NeverAnswers() : super(latency: Duration.zero);

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(IList<ReportPeriod> months) =>
      Completer<IList<MonthCapStatus>>().future;
}

/// The screen asks `context.canPop()` for its own way out (R11), so it needs
/// a router in the tree — a one-route one, because what is under test is the
/// screen and not the app's eleven routes.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SettingsScreen()),
  ],
);

void main() {
  // The screen draws money, and `main()` does not run in a test.
  setUpAll(initializePtBr);

  /// The screen reads the phone's clock for the month it shows, so the fake
  /// is anchored on the same day the test runs — which is what keeps this
  /// file passing in any month of any year.
  final today = DateTime.now();
  final thisMonth = DateTime(today.year, today.month);

  Future<void> pumpSettings(
    WidgetTester tester, {
    SpendingCapRepository? caps,
    Override? deviceUser,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceUser ?? deviceUserOverride(),
          spendingCapRepositoryProvider.overrideWith(
            (ref) =>
                caps ??
                _SpyRepository(
                  spending: {thisMonth: const Money(130000)},
                  today: today,
                ),
          ),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the cap in force and where the month stands', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Teto de gasto do mês'), findsOneWidget);
    // R$ 1.300 of R$ 1.500, the case requirement 9 is written with.
    expect(
      find.text(r'Gastou R$ 1.300,00 de R$ 1.500,00 neste mês.'),
      findsOneWidget,
    );
    // The field opens filled with what is in force, written the way the mask
    // writes it: the symbol, the grouping dot and a NO-BREAK SPACE between
    // them (`\u{A0}`, not a plain one).
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('cap-amount')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'R\$\u{A0}1.500,00');
  });

  testWidgets('a month with no cap says so instead of showing a blank', (
    tester,
  ) async {
    // A cap that only starts NEXT month is a month with none.
    await pumpSettings(
      tester,
      caps: _SpyRepository(
        cap: SpendingCap(
          amount: const Money(150000),
          effectiveFrom: DateTime(today.year, today.month + 1),
        ),
        today: today,
      ),
    );

    expect(find.textContaining('Nenhum teto definido'), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-amount')), findsOneWidget);
  });

  testWidgets('shows the spinner while the month is being read', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceUserOverride(),
          spendingCapRepositoryProvider.overrideWith((ref) => _NeverAnswers()),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    // WITH a duration: the device user fake has a latency of its own, and a
    // bare `pump` under the fake clock leaves its timer pending.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byKey(const ValueKey('cap-amount')), findsNothing);
  });

  testWidgets('a network failure says so and offers the retry', (tester) async {
    await pumpSettings(
      tester,
      caps: _SpyRepository(today: today)
        ..failNextRead = NetworkException('offline'),
    );

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('retry-cap')), findsOneWidget);
  });

  testWidgets('a server failure gets its own sentence, never the exception', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      caps: _SpyRepository(today: today)
        ..failNextRead = ApiException(500, 'boom'),
    );

    expect(
      find.text('O servidor está indisponível. Tente de novo em instantes.'),
      findsOneWidget,
    );
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('the retry brings the section back', (tester) async {
    final repository = _SpyRepository(
      spending: {thisMonth: const Money(130000)},
      today: today,
    )..failNextRead = NetworkException('offline');
    await pumpSettings(tester, caps: repository);

    await tester.tap(find.byKey(const ValueKey('retry-cap')));
    await tester.pumpAndSettle();

    expect(
      find.text(r'Gastou R$ 1.300,00 de R$ 1.500,00 neste mês.'),
      findsOneWidget,
    );
  });

  testWidgets('saves a cap the month is under, with no warning', (
    tester,
  ) async {
    // R$ 1.100 of R$ 1.500 is below both cuts.
    final repository = _SpyRepository(
      spending: {thisMonth: const Money(110000)},
      today: today,
    );
    await pumpSettings(tester, caps: repository);

    await tester.enterText(
      find.byKey(const ValueKey('cap-amount')),
      // Cents: the mask turns it into R$ 1.500,00.
      '150000',
    );
    await tester.tap(find.byKey(const ValueKey('save-cap')));
    await tester.pumpAndSettle();

    expect(find.text('Teto do mês salvo.'), findsOneWidget);
    expect(find.byKey(const ValueKey('warnings')), findsNothing);
    expect(repository.saved.single.amount, const Money(150000));
  });

  testWidgets('a cap the month is already over warns ON THE SPOT, with %', (
    tester,
  ) async {
    final repository = _SpyRepository(
      spending: {thisMonth: const Money(130000)},
      today: today,
    );
    await pumpSettings(tester, caps: repository);

    await tester.enterText(
      find.byKey(const ValueKey('cap-amount')),
      // Cents: the mask turns it into R$ 1.500,00.
      '150000',
    );
    await tester.tap(find.byKey(const ValueKey('save-cap')));
    await tester.pumpAndSettle();

    // 1300 of 1500 is 86,66…%, and the documents write this case as 87%.
    expect(
      find.text('Vocês já estão em 87% deste teto neste mês.'),
      findsOneWidget,
    );
    // …and it COUNTS as the 80% warning: the mark went up with it.
    expect(repository.alertsWritten.single.warned80, isTrue);

    await tester.tap(find.byKey(const ValueKey('acknowledge-warnings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('warnings')), findsNothing);
  });

  testWidgets('refuses a cap of zero, and writes nothing', (tester) async {
    final repository = _SpyRepository(today: today);
    await pumpSettings(tester, caps: repository);

    await tester.enterText(find.byKey(const ValueKey('cap-amount')), '0');
    await tester.tap(find.byKey(const ValueKey('save-cap')));
    await tester.pumpAndSettle();

    expect(find.text('Informe um teto maior que zero.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('refuses the field left empty', (tester) async {
    final repository = _SpyRepository(today: today);
    await pumpSettings(tester, caps: repository);

    // The other refusal of the same field, and it is a different one. Letters
    // ARE the empty field now: the mask drops everything that is not a digit,
    // so 'abc' never becomes text in there.
    await tester.enterText(find.byKey(const ValueKey('cap-amount')), 'abc');
    await tester.tap(find.byKey(const ValueKey('save-cap')));
    await tester.pumpAndSettle();

    expect(find.text('Informe um valor válido.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('a failed write says so and keeps what was on screen', (
    tester,
  ) async {
    final repository = _SpyRepository(
      spending: {thisMonth: const Money(130000)},
      today: today,
    )..failNextWrite = NetworkException('offline');
    await pumpSettings(tester, caps: repository);

    await tester.enterText(find.byKey(const ValueKey('cap-amount')), '180000');
    await tester.tap(find.byKey(const ValueKey('save-cap')));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(
      find.text(r'Gastou R$ 1.300,00 de R$ 1.500,00 neste mês.'),
      findsOneWidget,
    );
  });

  testWidgets('the pull to refresh has a scrollable child in every state', (
    tester,
  ) async {
    // The error state is the one where a plain Center would kill it, and it
    // is where people pull the most.
    await pumpSettings(
      tester,
      caps: _SpyRepository(today: today)
        ..failNextRead = NetworkException('offline'),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView).first).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
  });

  testWidgets('the device user section is still here, below the cap', (
    tester,
  ) async {
    await pumpSettings(tester);

    final cap = tester.getTopLeft(find.text('Teto de gasto do mês'));
    final label = tester.getTopLeft(
      find.text('Quem está usando este aparelho'),
    );

    expect(cap.dy, lessThan(label.dy));
  });

  group('sign out', () {
    Future<void> pumpSignedIn(
      WidgetTester tester, {
      required AuthRepository auth,
      PurchaseDraftRepositoryLocal? drafts,
      DeviceUserRepositoryLocal? users,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => auth),
            purchaseDraftRepositoryProvider.overrideWith(
              (ref) => drafts ?? PurchaseDraftRepositoryLocal(),
            ),
            deviceUserRepositoryProvider.overrideWith(
              (ref) =>
                  users ??
                  DeviceUserRepositoryLocal(
                    initial: DeviceUser('Leandro'),
                    latency: Duration.zero,
                  ),
            ),
            spendingCapRepositoryProvider.overrideWith(
              (ref) => _SpyRepository(
                spending: {thisMonth: const Money(130000)},
                today: today,
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sign-out')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the sign out button below the device user section', (
      tester,
    ) async {
      await pumpSignedIn(tester, auth: _SpySessionRepository());

      final label = tester.getTopLeft(
        find.text('Quem está usando este aparelho'),
      );
      final button = tester.getTopLeft(find.byKey(const ValueKey('sign-out')));
      expect(button.dy, greaterThan(label.dy));
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('signs out once after confirming', (tester) async {
      final auth = _SpySessionRepository();
      await pumpSignedIn(tester, auth: auth);

      await openDialog(tester);
      expect(find.text('Sair da conta?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.text('Sair da conta?'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('does nothing when the confirmation is canceled', (
      tester,
    ) async {
      final auth = _SpySessionRepository();
      await pumpSignedIn(tester, auth: auth);

      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('cancel-sign-out')));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsNothing);
      expect(auth.signOutCalls, 0);
      expect(auth.isSignedIn, isTrue);
      expect(find.text('Configurações'), findsOneWidget);
    });

    testWidgets('does nothing when the dialog is dismissed', (tester) async {
      final auth = _SpySessionRepository();
      await pumpSignedIn(tester, auth: auth);

      await openDialog(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsNothing);
      expect(auth.signOutCalls, 0);
      expect(find.text('Configurações'), findsOneWidget);
    });

    testWidgets('shows the failure in a SnackBar and stays on settings', (
      tester,
    ) async {
      final auth = _SpySessionRepository()
        ..failNextCall = Exception('disk-full');
      await pumpSignedIn(tester, auth: auth);

      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível sair. Tente de novo.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sign-out')), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('disables the button while signing out', (tester) async {
      final auth = _SpySessionRepository(
        latency: const Duration(milliseconds: 500),
      );
      await pumpSignedIn(tester, auth: auth);

      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Saindo...'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('sign-out')),
      );
      expect(button.onPressed, isNull);

      // pumpAndSettle alone would not advance the fake's pending delay.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sign-out')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Saindo...'), findsNothing);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('keeps the draft and the label after signing out', (
      tester,
    ) async {
      final draft = PurchaseDraft.startedOn(today, 'Leandro');
      final drafts = PurchaseDraftRepositoryLocal(initial: draft);
      final users = DeviceUserRepositoryLocal(
        initial: DeviceUser('Leandro'),
        latency: Duration.zero,
      );
      await pumpSignedIn(
        tester,
        auth: _SpySessionRepository(),
        drafts: drafts,
        users: users,
      );

      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
      await tester.pumpAndSettle();

      expect(drafts.readNow(), draft);
      expect(drafts.writes, 0);
      expect(users.readNow()?.name, 'Leandro');
    });
  });
}
