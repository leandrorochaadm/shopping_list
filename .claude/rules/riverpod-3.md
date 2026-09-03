---
name: riverpod-3
description: As armadilhas do Riverpod 3 — valueOrNull, retry automático, family, ref.mounted, copyWithPrevious
quando-ler: ao criar ou editar qualquer Notifier, AsyncNotifier ou Provider
---

# Riverpod 3 — atenção

- `AsyncValue.valueOrNull` **não existe mais**; use `.value` — que devolve o valor
  **anterior** durante loading/erro, e `null` só quando nunca houve valor. Para "há o que
  mostrar?", use `hasValue`.
- `AsyncValue` **tem** progresso desde a v3: `AsyncLoading(progress: 0.5)`, `num?`, 0..1.
  Lista vazia, paginação e "dado desatualizado" são variações do **dado** — resolvem-se
  trocando o `T`, não trocando o `AsyncValue`.
- Num `Notifier<SeuState>` (state class própria), o erro do `build()` **não** vira um dos
  seus estados: ele relança como `ProviderException` na leitura. Por isso o `build()` fica
  puro e a carga inicial migra para um método. Não suba para essa forma sem eu pedir.
- Providers têm **retry automático**: 10 tentativas, backoff de 200ms até 6.4s.
  Ele já pula `Error` e `ProviderException` — só age sobre `Exception`. Desligue com
  `retry: (retryCount, error) => null` nos ViewModels, onde o erro precisa aparecer.
- Depois de todo `await`, cheque `if (!ref.mounted) return ...;` antes de tocar no
  `state`: todo método de `ref`/notifier lança se o provider já foi descartado
  (fechar a tela durante um refresh derruba o app).
- Durante recarga, `state = const AsyncLoading<T>()` **puro**: o Riverpod 3 preserva o
  valor anterior sozinho. Nada de `.copyWithPrevious(state)` — virou `@internal` na 3.0 e
  o `flutter analyze` acusa `invalid_use_of_internal_member`.
- `family`: o argumento chega pelo **construtor** do notifier, e o `build()` continua
  sem parâmetro. Não existe classe base `FamilyAsyncNotifier`.
- Notifiers são recriados a cada rebuild do provider.
- Providers filtram update com `==` — entidades precisam de `==`/`hashCode` completos.
