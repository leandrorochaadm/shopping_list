---
name: errors
description: As duas categorias de erro, a forma do retorno de uma ação, e o Result do guia oficial traduzido para AsyncValue + AppFailure
quando-ler: ao escrever qualquer método de ViewModel que possa falhar, ou ao mexer em AppFailure
---

# Erros — duas categorias

- **Carga inicial** falhou: vai para o `state` como `AsyncError`, ocupa a tela.
- **Ação** falhou (cancelar, salvar, recarregar): o método do ViewModel **retorna
  `String?`** com a mensagem; a lista permanece na tela e a View mostra SnackBar.
- **A forma do retorno depende do número de desfechos** (regra 16):

  | Desfechos | Forma | Exemplo no código |
  |---|---|---|
  | 2, sem carga | `Future<String?>` | `ShoppingListViewModel.add` |
  | 2 com carga, ou 3+ | `sealed` + retorno anulável | `NewPurchaseViewModel.save` |

  **`Record` não é uma das formas.** Ele dá `==` estrutural de graça, mas
  `({String? error, T? payload})` representa 4 estados para 2 válidos, e não há
  `switch` exaustivo sobre record.
- No `catch`, se **não houver dado anterior**, o state tem de virar `AsyncError`.
  Deixar em `AsyncLoading` trava a tela num spinner que nunca resolve.
- **Nunca interpolar a exceção na mensagem do usuário** — nem `'Falhou: $e'`, nem
  `'${state.error}'` na tela de erro. A falha é classificada em `AppFailure`
  (`ui/core/app_failure.dart`) e traduzida por `translateFailure`, com o detalhe cru
  indo para `debugPrint`. As frases devolvidas são em português.
- **Toda ação tem guarda de reentrância.** `if (_running) return null;` na entrada e
  `_running = false` num `finally` — a lista continua na tela durante a ação, então o
  botão continua clicável.

**O `Result` do guia oficial, traduzido para este projeto:**

| Guia oficial do Flutter | Aqui |
|---|---|
| `sealed class Result<T>` | `sealed class AsyncResult<T>` (Riverpod) |
| `Ok<T>` com `.value` | `AsyncData<T>` com `.value` |
| `Error<T>` com `.error` (`Exception` crua) | `AsyncError<T>` com `.error` + `AppFailure` classificado |
| `Result.ok(v)` / `Result.error(e)` | `AsyncData(v)` / `AsyncError(e, st)` |
| `switch (r) { case Ok(): ... case Error(): ... }` | idem, com `AsyncData`/`AsyncError` |
| — não existe | `AsyncLoading<T>` e `AsyncValue.guard` |

Quem **constrói** cada um: o `Result` do guia é construído pelo repository; o
`AsyncValue`/`AsyncResult` é construído **pelo Riverpod**, ao redor do `build()`.
Não existe `AsyncData(` nem `AsyncError(` dentro de `lib/data/` — ver regra 17.

Adaptações menores, já aplicadas:

- **`SessionExpired` virou `AccessDenied`** no `AppFailure`: não há login, então 401/403
  é RLS ou chave errada, nunca sessão vencida.
- **`EditConflict` virou `DuplicateRecord`**: a gravação é "último a escrever vence"
  (`tecnico §4.5`), então o 409 que de fato acontece é a trava de duplicidade do cadastro.
- **`translateError`/`translateFailure` moram em `ui/core/error_translation.dart`**, não
  dentro de um ViewModel: são 11 telas, e uma cópia por ViewModel seriam 11 lugares para
  editar quando uma frase mudar.
- **`ApiException`/`NetworkException` moram em `data/services/api_exception.dart`**, sem
  `api_client.dart`: quem faz I/O é o `supabase_flutter`, não um cliente HTTP nosso.
