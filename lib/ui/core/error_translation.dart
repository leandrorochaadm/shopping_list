import 'package:flutter/foundation.dart' show debugPrint;

import 'app_failure.dart';

/// Turns the technical failure into a sentence the client understands.
/// The raw detail goes to the log — never to the screen.
///
/// It lives here, and not inside a ViewModel, because this project has eleven
/// screens: keeping one copy per ViewModel would mean eleven places to edit
/// when a sentence changes.
///
/// [action] is a pt-BR fragment composed into the sentence
/// ('atualizar a lista', 'salvar a compra').
String translateError(Object e, StackTrace? st, String action) {
  debugPrint('[$action] $e\n${st ?? ''}');
  return translateFailure(AppFailure.from(e), action);
}

/// The switch the compiler polices. Adding a variant to AppFailure makes this
/// function stop compiling until the new case has a sentence — which is the
/// whole reason the classification is a sealed type and not an if-chain.
///
/// The returned strings are user-facing, so they are written in pt-BR.
String translateFailure(AppFailure failure, String action) => switch (failure) {
  NoConnection() => 'Sem conexão. Verifique a internet e tente de novo.',
  AccessDenied() => 'O servidor recusou o acesso a este dado.',
  RecordNotFound() => 'Este registro não existe mais. Atualize a tela.',
  DuplicateRecord() => 'Já existe um cadastro com esses dados.',
  ServerUnavailable() =>
    'O servidor está indisponível. Tente de novo em instantes.',
  RequestRejected() => 'Não foi possível $action.',
  AppBug() => 'Ocorreu um erro no aplicativo. Tente de novo mais tarde.',
  UnexpectedFailure() => 'Não foi possível $action. Tente de novo.',
};
