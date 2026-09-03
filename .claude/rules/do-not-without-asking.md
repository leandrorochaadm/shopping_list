---
name: do-not-without-asking
description: O que não fazer sem o usuário pedir — use-case, Result, Command, DTO, Record, Mutation, freezed, equatable
quando-ler: antes de introduzir qualquer padrão, pacote ou abstração que não esteja já no projeto
---

# Não fazer sem eu pedir

- use-case, `Result<T>`/`Either`, `Command`, DTO separado da entidade, **e `typedef` de
  `Record`** — `Result` **não** é alternativa ao `AsyncValue` (um é retorno de
  repository, o outro é estado de tela), e mesmo a pedido ele obedece à **regra 15**.
  `sealed` local a um ViewModel **não** é o `Result` que a 15 barra: é o desfecho de uma
  ação, e é a forma prescrita pela **regra 16**
- `Mutation` do Riverpod 3 — é experimental (*"may change in a breaking way without a
  major version bump"*) e o `run()` relança depois de gravar o erro: disparar sem
  `await` deixa erro solto na zona. Ação com loading próprio = um provider pequeno por
  ação
- `freezed`, `json_serializable`, `riverpod_generator`, `@riverpod`
- `equatable` (não elimina o erro que o `IList` elimina), pacote `provider` para DI
  (Riverpod já é o container), `collection`
- interface para service (só repository é abstrato)
