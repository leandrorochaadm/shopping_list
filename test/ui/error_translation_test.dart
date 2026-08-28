import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/app_failure.dart';
import 'package:shopping_list/ui/core/error_translation.dart';

void main() {
  // translateError is the door all eleven ViewModels go through: it classifies
  // and translates in one call. translateFailure below is only the second half.
  group('translateError', () {
    test('classifies and translates in a single call', () {
      expect(
        translateError(
          NetworkException(Exception('offline')),
          StackTrace.empty,
          'atualizar a lista',
        ),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
    });

    test('keeps the raw detail out of the sentence it returns', () {
      // The body of a PostgREST error names columns and values. It belongs in
      // the log the function writes, never in the sentence it returns.
      final message = translateError(
        ApiException(422, 'column "preco" does not exist'),
        StackTrace.empty,
        'salvar a compra',
      );

      expect(message, isNot(contains('preco')));
      expect(message, isNot(contains('422')));
      expect(message, isNot(contains('ApiException')));
      expect(message, contains('salvar a compra'));
    });

    test('accepts a missing stack trace', () {
      expect(
        translateError(ApiException(404, ''), null, 'abrir a compra'),
        contains('não existe mais'),
      );
    });

    test('unwraps a failure Riverpod wrapped on the way up', () {
      final failing = Provider<int>((ref) => throw ApiException(409, ''));
      final container = ProviderContainer.test();

      Object? caught;
      try {
        container.read(failing);
      } on Object catch (e) {
        caught = e;
      }

      expect(
        translateError(caught!, StackTrace.empty, 'salvar o produto'),
        contains('Já existe'),
      );
    });
  });

  // One case per variant: the switch is exhaustive by the compiler, but only a
  // test says whether each arm returns the sentence that arm is for.
  group('translateFailure', () {
    test('tells the user to check the connection on NoConnection', () {
      expect(
        translateFailure(const NoConnection(), 'atualizar a lista'),
        contains('Sem conexão'),
      );
    });

    test('blames the access, not the login, on AccessDenied', () {
      // There is no session in this app, so this is RLS or a wrong key — the
      // sentence must never suggest signing in again.
      final message = translateFailure(
        const AccessDenied(),
        'abrir o relatório',
      );

      expect(message, contains('recusou o acesso'));
      expect(message, isNot(contains('sessão')));
    });

    test('asks for a refresh on RecordNotFound', () {
      expect(
        translateFailure(const RecordNotFound(), 'abrir a compra'),
        contains('não existe mais'),
      );
    });

    test('tells the user the record already exists on a duplicate', () {
      expect(
        translateFailure(const DuplicateRecord(), 'salvar o produto'),
        contains('Já existe'),
      );
    });

    test('asks the user to wait on ServerUnavailable', () {
      expect(
        translateFailure(const ServerUnavailable(), 'salvar a compra'),
        contains('indisponível'),
      );
    });

    test('names the action on RequestRejected', () {
      expect(
        translateFailure(const RequestRejected(), 'salvar a compra'),
        'Não foi possível salvar a compra.',
      );
    });

    test('blames the app, not the connection, on our own bug', () {
      final message = translateFailure(AppBug(StateError('boom')), 'seguir');

      expect(message, contains('aplicativo'));
      expect(message, isNot(contains('conexão')));
    });

    test('never leaks the raw exception into the sentence', () {
      final message = translateFailure(
        UnexpectedFailure(Exception('PostgrestException(code: 42P01)')),
        'salvar a compra',
      );

      expect(message, isNot(contains('PostgrestException')));
      expect(message, contains('salvar a compra'));
    });
  });
}
