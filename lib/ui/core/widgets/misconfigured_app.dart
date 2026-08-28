import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../themes/app_theme.dart';
import 'message_view.dart';

/// Shown INSTEAD of the app when the build cannot reach its Supabase project.
///
/// Falling back to the `_local` fakes here is right while developing and wrong
/// in a deploy: it would put an app on the phone that looks like it works and
/// writes nowhere. An installed PWA has no console to print a warning to, so
/// the screen is the only place this can be reported — and a failure escaping
/// `main` would paint a white screen instead.
///
/// The sentences are in pt-BR like every other screen — on this project the
/// person who reads them is also the one who runs the deploy.
class MisconfiguredApp extends StatelessWidget {
  /// The build shipped without SUPABASE_URL / SUPABASE_ANON_KEY.
  const MisconfiguredApp({super.key})
    : title = 'Configuração ausente',
      message =
          'Este build saiu sem o endereço do banco.\n\n'
          'Refaça o deploy passando SUPABASE_URL e SUPABASE_ANON_KEY.';

  /// The two values were there and Supabase still refused to start: a wrong
  /// project URL, an anon key from another project, storage the browser
  /// blocked.
  const MisconfiguredApp.startupFailed({super.key})
    : title = 'Falha ao iniciar',
      message =
          'Não foi possível abrir a conexão com o banco deste build.\n\n'
          'Confira SUPABASE_URL e SUPABASE_ANON_KEY e refaça o deploy.';

  /// The browser refused local storage: a private window, or site data
  /// blocked. Hive holds the purchase draft and the device user label, so
  /// there is no usable app without it.
  const MisconfiguredApp.storageUnavailable({super.key})
    : title = 'Armazenamento bloqueado',
      message =
          'O navegador não deixou o app guardar dados neste aparelho.\n\n'
          'Abra pela tela de início, com o app instalado, e fora de uma '
          'janela privada.';

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lista de compras',
    theme: AppTheme.light,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    locale: ptBrLocale,
    home: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MessageView(message),
    ),
  );
}
