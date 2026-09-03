---
name: inviolable-rules
description: As 18 regras invioláveis da arquitetura MVVM (numeradas 0 a 17, citadas por outros documentos)
quando-ler: sempre — é o contrato de toda linha de código do projeto
---

# Regras invioláveis

> Mesma numeração da skill `flutter-mvvm`. Os números são citados por outros documentos —
> regra nova entra **no fim**, nunca no meio.

0. **Código todo em inglês americano**; só o texto de tela é pt-BR (ver `.claude/rules/language.md`).
1. Nada em `domain/` importa `flutter`, `http`, `dio` ou `supabase`.
   `fast_immutable_collections` **pode**: é Dart puro, o critério é dependência de
   plataforma ou de I/O, não "pacote externo".
2. ViewModel não importa `material.dart` e não recebe `BuildContext`.
   Navegação e SnackBar são reação da View ao retorno do método.
3. Repository só faz I/O. Nenhuma decisão de negócio ali.
4. Widget nunca chama repository — sempre via ViewModel.
5. Service (`ApiClient`, `SupabaseClient`, `Dio`) é membro **privado** do repository.
6. Número mágico de regra (prazo, limite, percentual) vira `static const` no domínio.
   Mensagem de erro **deriva** da constante, nunca repete o valor em texto.
7. **Transição de status é regra**: `x.canceled()` na entidade, nunca
   `copyWith(status: ...)` espalhado por repository ou ViewModel.
8. `==`/`hashCode` cobrem **todos** os campos da entidade. E **toda coleção é `IList`**,
   nunca `List` — inclusive campo de coleção dentro da entidade: o `==` de `List` compara
   por referência, então lista mutada no lugar não repinta a tela. `.lock` converte,
   `.unlock` volta, `.toIList()` fecha um `map`.
9. Nada de `DateTime.now()` dentro de widget ou de entidade: o instante é
   parâmetro (`canSomething(now)`), calculado uma vez na tela e **arredondado**
   para a menor unidade que a regra usa — valor novo a cada frame anula o `==`.
   No **ViewModel é permitido**: é ali que o relógio entra no sistema.
10. Nunca interpolar a exceção em mensagem de usuário (`'Falhou: $e'`).
11. View **pergunta** a regra (`x.canSomething(now)`), nunca a reimplementa.
    `if` composto sobre campos de entidade dentro de `build()` é bug de arquitetura.
12. Fluxo unidirecional: dados vão de data -> ui; eventos vão de ui -> data.
13. Falha técnica é **classificada** em `AppFailure` (sealed) antes de virar frase.
    Ninguém fora de `ui/core/app_failure.dart` inspeciona exceção crua, e o
    desembrulho de `ProviderException` é em **laço** — o Riverpod aninha uma
    camada por salto na cadeia de providers.
14. Toda ação do ViewModel tem guarda de reentrância (`if (_running) return null;`),
    liberada num `finally`. Sem ela um toque duplo dispara duas requisições.
15. `Result<T>` só entra quando `AsyncNotifier`/`AsyncValue` **não bastam** — ou seja,
    quando nasce um ponto de entrada de erro que nem o `build()` nem o molde de ação
    cobrem: `Stream` que precisa sobreviver ao erro, tela em `Notifier<SeuState>` (o
    `build()` parou de proteger a carga inicial), `Timer`, callback de push. Distinguir
    tipo de falha é trabalho do `AppFailure`, não dele. Se entrar, o repository
    **inteiro** devolve `Result`.
    **Isto não é a forma do retorno de uma ação** — essa é a regra 16.
16. **A forma do retorno de uma ação sai do número de desfechos**, e são duas —
    `Record` não é uma delas, em lugar nenhum do projeto. Dois desfechos sem carga:
    `Future<String?>`, `null` = deu certo. Dois desfechos com carga, ou três ou mais:
    `sealed` local ao ViewModel, consumido por `switch` exaustivo, com retorno
    **anulável** — o `null` é a guarda de reentrância da regra 14 dizendo "não fiz
    nada", e não um terceiro ramo. Agrupamento de dados sem desfecho (o `T` de um
    `AsyncNotifier`, um valor devolvido num `pop`) é `final class` com `==`/`hashCode`
    cobrindo todos os campos — a regra 8 vale para eles.
17. Em `data/`, só o **arquivo do contrato** conhece o Riverpod, e apenas para declarar
    o `Provider` que `config/dependencies.dart` sobrescreve. As implementações
    (`_local`, `_remote`, `_hive`) não importam pacote de estado, e **nenhum arquivo de
    `data/` constrói `AsyncValue`/`AsyncResult`** — esse envelope é do Riverpod, criado
    ao redor do `build()`. O que atravessa a fronteira é `Future<T>` mais exceção.
