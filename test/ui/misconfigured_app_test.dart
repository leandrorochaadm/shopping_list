import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/widgets/misconfigured_app.dart';

import '../helpers/locale.dart';

void main() {
  // The whole point of this screen is being specific: "something went wrong"
  // would leave the person redeploying with nothing to act on. Each variant
  // names what has to change, and no two of them are fixed the same way.
  testWidgets('names the two build variables the deploy forgot', (
    tester,
  ) async {
    await tester.pumpWidget(const MisconfiguredApp());

    expect(find.text('Configuração ausente'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
  });

  testWidgets('separates a failed startup from a missing configuration', (
    tester,
  ) async {
    // The defines were there and Supabase still refused to start — a wrong
    // URL, a key from another project. Reusing the "missing configuration"
    // sentence here would send the reader looking for a flag that IS set.
    await tester.pumpWidget(const MisconfiguredApp.startupFailed());

    expect(find.text('Falha ao iniciar'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('saiu sem o endereço'), findsNothing);
  });

  testWidgets('tells the user to leave the private window', (tester) async {
    // Nothing about the build is wrong here: the browser denied storage, and
    // the fix is on the phone. Naming the defines would be a wild goose
    // chase.
    await tester.pumpWidget(const MisconfiguredApp.storageUnavailable());

    expect(find.text('Armazenamento bloqueado'), findsOneWidget);
    expect(find.textContaining('janela privada'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsNothing);
  });

  testWidgets('renders in pt-BR like every other screen', (tester) async {
    // It is an application root of its own: forgetting the delegates here
    // would put Material's English strings on the only screen a broken
    // deploy ever shows.
    await tester.pumpWidget(const MisconfiguredApp());

    expectPtBrDelegates(tester);
  });
}
