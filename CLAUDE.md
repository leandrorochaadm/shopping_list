# Lista de compras de supermercado

PWA em Flutter Web para **dois iPhones**, sem login, com base única no Supabase.
Casal que quer saber quanto gasta em quê, não esquecer item e não pagar caro.

**As fontes da verdade estão em `docs/`, nesta ordem de precedência:**

1. `docs/requisitos-lista-de-compras.md` — 18 requisitos essenciais, é o que o cliente lê
2. `docs/tecnico-lista-de-compras.md` — questionário técnico, **decisões 1 a 25 congeladas**
3. `docs/wireframes-lista-de-compras.md` — 6 telas + 6 diálogos + painel `#3a`
4. `docs/handoff-lista-de-compras.md` — 19 histórias (H1–H19), ordem de entrega, glossário

Onde este arquivo divergir dos três primeiros, **são eles que valem**. Mudar qualquer
linha de `tecnico §12` (decisões congeladas) é **alteração de escopo** — pergunte antes.

Cliente, desenvolvedor e homologador são a mesma pessoa. Sem QA, sem board, sem prazo.

---

# Arquitetura — MVVM (guia oficial do Flutter)

## Stack

Riverpod **3 ou superior**, escrito **à mão**: sem `@riverpod`, sem `riverpod_annotation`,
sem `build_runner`. Nada de `freezed` nem `json_serializable` — `fromJson`/`toJson`,
`copyWith` e `==` são escritos no arquivo.

`fast_immutable_collections` para as coleções: repository, ViewModel e View trabalham
com `IList<T>`, não `List<T>`.

**Dependências de runtime, e nada além disto** (`tecnico §3`, decisão registrada):

| Pacote | Para quê |
|---|---|
| `supabase_flutter` | backend inteiro: Postgres, PostgREST e Realtime. Traz o cliente HTTP |
| `flutter_riverpod` 3.x | estado e injeção de dependência |
| `go_router` | as 11 rotas nomeadas |
| `hive_ce` + `hive_ce_flutter` | duas coisas só: o rascunho do lançamento e a etiqueta de quem está usando |
| `intl` | formatação pt-BR de data e moeda |
| `fast_immutable_collections` | `IList` — **acréscimo à lista congelada**, ver "Divergências" |
| `http` | só pelo `ClientException`: o `postgrest` fala por ele e é assim que falha de transporte chega |
| `flutter_localizations` | os delegates pt-BR do Material. Vem do SDK — **acréscimo à lista congelada**, ver "Divergências" |

Em desenvolvimento: `flutter_test`, `mocktail`, `flutter_lints` ^6.0.0.

**Sem `connectivity_plus`** (decisão 22): em web os eventos `online`/`offline` chegam
pelo pacote `web` que o SDK já traz, e a reconexão do canal do Supabase é o segundo sinal.

Versões mínimas: **Flutter 3.44.0 stable · Dart 3.12.0**.

## Idioma do código — regra zero

**Todo o código é escrito em inglês americano.** Classes, métodos, variáveis, campos,
constantes, enums, nomes de arquivo e de pasta, comentários e descrições de teste.

**Única exceção:** o texto que o usuário final lê na tela (títulos, botões, estado vazio,
mensagens de erro traduzidas) fica em **português do Brasil**.

| Item | Idioma |
|---|---|
| `class Appointment`, `canCancel(now)`, `clientName` | inglês |
| `appointment_repository_local.dart` | inglês |
| `// The rule comes from the domain.` | inglês |
| `test('blocks canceling less than 24h ahead', ...)` | inglês |
| `throw ArgumentError('baseUrl is empty...')` | inglês (lê o dev) |
| `Text('Cancelar')`, `'Nenhum agendamento.'` | português (lê o usuário) |
| `'Cancelamento exige $hours horas de antecedência.'` | português (lê o usuário) |

Regra em português vira nome em inglês antes do primeiro arquivo: "só cancela com 24h de
antecedência" → `canCancel(DateTime now)` com `minCancellationNotice`. Chave de JSON
espelha o contrato real da API; o campo Dart continua em inglês
(`clientName: json['nome_cliente'] as String`). Vocabulário sem tradução consagrada
(`CPF`, `PIX`, `boleto`) fica como está.

## Glossário pt-BR → inglês

**Consulte antes de traduzir qualquer termo novo; acrescente o termo depois de escolher.**

Sem isto, "fatura" vira `Invoice` numa feature e `Bill` na seguinte — os dois em inglês
correto, então nenhuma verificação automática acusa, e o custo de unificar cresce a cada
feature. Este é o único registro dessa decisão entre sessões.

O glossário do negócio é o `handoff §10` — ele é a linguagem ubíqua **em português**.
A tabela abaixo é a tradução dele para o código, e é obrigatória: **consulte antes de
traduzir qualquer termo novo, e acrescente o termo depois de escolher.**

| Termo do negócio | No código | Observação |
|---|---|---|
| categoria | `Category` | "Limpeza", "Carnes". Única pelo nome normalizado |
| tipo do produto | `ProductType` | o nível **que soma**; carrega a unidade base |
| marca | `Brand` | cadastro próprio, opcional |
| descrição | `description` | texto livre; separa um cadastro do outro. Nunca `NULL`, sempre `''` |
| cadastro de produto | `ProductRegistration` | `tipo + marca + descrição`. É o que não pode se repetir |
| produto (a folha) | `Product` | cadastro **+ embalagem**. É o que a compra aponta |
| embalagem | `Packaging` | quantas peças × quanto tem cada peça. **Não** `Package`, que em Dart já significa outra coisa |
| medida da peça | `pieceSize` | guardada nas duas formas: a digitada e a convertida |
| conteúdo total | `totalContent` | na unidade base. **Calculado, nunca digitado** |
| unidade base | `BaseUnit` | enum: `kilogram`, `liter`, `unit` |
| vendido a peso / por peça | `SellingMode.byWeight` / `.byPiece` | decide o que o lançamento pergunta |
| custo proporcional / preço por unidade base | `costPerBaseUnit` | preço ÷ conteúdo total |
| melhor custo | `bestCost` | o menor `costPerBaseUnit`, não o menor preço |
| mercado | `Store` | supermercado, feira, açougue, hortifrúti |
| lista de compras | `ShoppingList` / `ShoppingListItem` | o item guarda a **data em que entrou** |
| preferência da lista | `listPreference` | marca e embalagem desejadas. **Não mandam na baixa** |
| não encontrei | `notFound` | mora no diálogo do item; volta se a compra for apagada |
| lançar a compra | `Purchase` / `PurchaseItem` | produto, quantidade e **valor total pago** |
| saldo do item | `remainingQuantity` | "restam 2 de 6 kg" — esse tira o item da lista |
| teto de gasto | `spendingCap` | valor máximo pretendido no mês |
| quem está usando | `deviceUser` | etiqueta local do aparelho. **Não é conta nem login** |
| janela de referência | `ReferenceWindow.rolling` / `.closed` | são duas e **nunca se misturam** |
| média mensal | `monthlyAverage` | consumo na janela fechada ÷ meses fechados de vida |
| falta comprar no mês | `remainingForMonth` | informa e nada mais |
| gasto | `spending` | quanto dinheiro saiu |
| consumo | `consumption` | quanta quantidade entrou, na unidade base |
| alerta de alta de preço | `priceIncreaseThreshold` | o limiar é `static const` no domínio |

**`ProductRegistration` e `Packaging` foram escolhidos aqui, não pelo cliente** — os dois
termos são ambíguos em inglês. Confirme na H2, antes de a entidade existir; depois disso
renomear custa caro. Todo termo novo ambíguo é decisão do usuário: **pergunte** e
registre nesta tabela.

## Camadas

- `config/` — `dependencies.dart` (providers e overrides) e `environment.dart` (`--dart-define`).
- `routing/` — `routes.dart` (os 11 paths) e `router.dart` (o `GoRouter`).
- `domain/models/` — entidades, **todas as regras de negócio** e as exceções de regra. Dart puro.
- `domain/use_cases/` — só quando a lógica usa 2+ repositories ou é repetida em 2+ ViewModels.
- `data/repositories/<feature>/` — abstract + `_local` (fake) + `_remote` (API).
- `data/services/` — cliente HTTP. Sempre membro **privado** do repository.
- `ui/<feature>/view_model/` — orquestração, estado.
- `ui/<feature>/widgets/` — telas e componentes.

## Regras invioláveis

> Mesma numeração da skill `flutter-mvvm`. Os números são citados por outros documentos —
> regra nova entra **no fim**, nunca no meio.

0. **Código todo em inglês americano**; só o texto de tela é pt-BR (ver acima).
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

## Erros — duas categorias

- **Carga inicial** falhou: vai para o `state` como `AsyncError`, ocupa a tela.
- **Ação** falhou (cancelar, salvar, recarregar): o método do ViewModel **retorna
  `String?`** com a mensagem; a lista permanece na tela e a View mostra SnackBar.
- No `catch`, se **não houver dado anterior**, o state tem de virar `AsyncError`.
  Deixar em `AsyncLoading` trava a tela num spinner que nunca resolve.
- **Nunca interpolar a exceção na mensagem do usuário** — nem `'Falhou: $e'`, nem
  `'${state.error}'` na tela de erro. A falha é classificada em `AppFailure`
  (`ui/core/app_failure.dart`) e traduzida por `translateFailure`, com o detalhe cru
  indo para `debugPrint`. As frases devolvidas são em português.
- **Toda ação tem guarda de reentrância.** `if (_running) return null;` na entrada e
  `_running = false` num `finally` — a lista continua na tela durante a ação, então o
  botão continua clicável.

## Observabilidade — só se o projeto tiver Sentry/PostHog

Se existir `lib/data/services/observability/`, estas regras valem em toda feature nova:

- O padrão dos providers (`loggerProvider`, `crashReporterProvider`, `analyticsProvider`)
  é **`Noop`**. Nenhum teste faz rede; não mude isso para "facilitar" um teste.
- **Nada de dado pessoal sai do dispositivo**: nem nome, e-mail, telefone, CPF, endereço,
  nem o corpo de resposta da API. Mande `id`, `statusCode` e a rota.
- **Nenhum `toString()` de exceção carrega payload** — é essa string que o Sentry envia.
- Erro de ação: log + `recordHandled` dentro do `catch`, **antes** de traduzir.
- Bloqueio por regra de negócio **não** é erro — não reporte.
- Nada de `await` em `track`/`identify`/`recordHandled` no caminho do usuário.
- Nome de evento: inglês, snake_case, no passado (`appointment_canceled`).
- Build de release com `--obfuscate` ou `--split-debug-info` **exige**
  `dart run sentry_dart_plugin` depois do `flutter build` — sem os símbolos, o stack trace
  de produção é uma lista de endereços. O `auth_token` vem de `SENTRY_AUTH_TOKEN` no
  ambiente, nunca do `pubspec.yaml`.

Detalhes e código: `11_observabilidade` na skill `flutter-mvvm`.

## SnackBar e contexto

`ScaffoldMessenger.of(context)` precisa de um context **abaixo** do `Scaffold` —
usar `Builder` no `body`. E capturar o messenger **antes** do `await`.

## Listas na tela

`RefreshIndicator` exige filho rolável **em todos os estados**. Usar
`physics: AlwaysScrollableScrollPhysics()` no `ListView` e `MessageView` (rolável)
para vazio e erro — `Center` puro quebra o pull-to-refresh.

## Textos de tela

O único conteúdo em português do código. Escrever em português correto para **esta**
entidade: artigo e plural não saem de substituição mecânica. "Nenhuma reserva", não
"Nenhum reserva"; "Animais", não "Animals". O identificador do widget que mostra o texto
continua em inglês (`MessageView`, `emptyLabel`).

## Ao criar uma feature nova

0. traduzir o vocabulário de negócio para inglês (`Agendamento` → `Appointment`)
1. `domain/models/<x>.dart` — entidade + regras + exceções + `fromJson`/`toJson` + `copyWith` + `==`
2. `data/repositories/<x>/<x>_repository.dart` — abstract, devolvendo `IList<T>`, com
   métodos em inglês (`fetchAll`, `cancel`, `create`)
3. `..._local.dart` com dados fake e latência de ~400ms
4. `..._remote.dart`
5. registrar provider e overrides em `config/dependencies.dart`
6. `ui/core/app_failure.dart` — uma vez por projeto, não por feature
7. `ui/<x>/view_model/<x>_view_model.dart` — `AsyncNotifier` com `retry: (retryCount, error) => null`
8. `ui/<x>/widgets/<x>_screen.dart` — `ConsumerWidget`
9. `test/domain/<x>_test.dart` — cada regra, incluindo os limites
10. `domain/use_cases/` nasce vazia com `.gitkeep`

## Testes

- Regra de negócio: teste puro em `test/domain/`, incluindo os **limites**
  (exatamente no prazo, exatamente encostado) e a transição de status.
- Nomes de teste, helpers e classes espiãs em inglês:
  `test('allows canceling more than 24h ahead', ...)`.
- ViewModel: espião herdando do `_local` com `failNextCall`, sem mocktail.
  Cobrir os dois caminhos de erro (**com** e **sem** dado anterior), o `refresh()` que dá
  **certo**, e a classificação de cada status em `AppFailure` — sem esses três, o alvo
  de 85% não fecha. Mais o toque duplo e o desembrulho de `ProviderException`: os dois
  precisam **falhar** se a guarda ou o laço forem removidos.
- Domínio: **toda** transição de status tem teste, mesmo a que a tela ainda não chama,
  mais o `toString()` das exceções de regra. É o que falta para os 95%.
- Teste de widget que renderize data ou moeda precisa de
  `setUpAll(() => initializeDateFormatting('pt_BR'))` — `main()` não roda em teste.
- Usar `ProviderContainer.test(...)`, não `ProviderContainer()` + `addTearDown`.
- Nunca `DateTime.now()` em teste: instante fixo sempre.

## Não fazer sem eu pedir

- use-case, `Result<T>`/`Either`, `Command`, DTO separado da entidade
  — `Result` **não** é alternativa ao `AsyncValue` (um é retorno de repository, o outro é
  estado de tela), e mesmo a pedido ele obedece à **regra 15** acima
- `Mutation` do Riverpod 3 — é experimental (*"may change in a breaking way without a
  major version bump"*) e o `run()` relança depois de gravar o erro: disparar sem
  `await` deixa erro solto na zona. Ação com loading próprio = um provider pequeno por
  ação
- `freezed`, `json_serializable`, `riverpod_generator`, `@riverpod`
- `equatable` (não elimina o erro que o `IList` elimina), pacote `provider` para DI
  (Riverpod já é o container), `collection`
- interface para service (só repository é abstrato)

## Riverpod 3 — atenção

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

---

## Divergências decididas entre a skill e os documentos

Os documentos foram escritos antes de a arquitetura ser materializada, e em quatro pontos
eles e a skill `flutter-mvvm` diziam coisas diferentes. **As decisões abaixo já estão em
vigor no código** — não reabrir sem o usuário pedir.

| Ponto | O que o doc dizia | O que vale | Por quê |
|---|---|---|---|
| Idioma do código | `handoff §10`: classes e tabelas com os termos pt-BR do cliente | **Inglês em tudo**, inclusive nas tabelas do Supabase | regra 0 da skill; a linguagem ubíqua sobrevive no glossário acima |
| Coleções | `tecnico §3`: cinco pacotes, "nada além disso" | **`fast_immutable_collections` entra** como sexta dependência | o `==` de `List` é por referência: lista mutada no lugar não repinta a tela no Riverpod 3 |
| Localização | `tecnico §3`: cinco pacotes, "nada além disso" | **`flutter_localizations` entra**, do SDK do Flutter | `intl` formata data e moeda, mas não traduz widget nenhum: sem os delegates o `showDatePicker` e os tooltips do Material saem em inglês dentro de uma tela pt-BR |
| Tratamento de erro | `tecnico §3.11`: `Result<T>` selado atravessando as camadas | **`AsyncValue` + `AppFailure`**; sem `Result` | regra 15 — `Result` só com gatilho observado (`Stream` que sobrevive ao erro, `Notifier<State>` próprio) |
| `analysis_options.yaml` | `tecnico §3.13`: o padrão do `flutter_lints` | **mantido o padrão** | a skill sugere 3 lints extras; a decisão congelada vence, e a diferença é irrelevante |

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

## O tradutor de erro do Supabase — `data/services/supabase_error.dart`

**Todo método de `_remote` fecha seu I/O com `rethrowAsKnownFailure(e, st)`.** Sem isso a
`PostgrestException` sobe crua e o `AppFailure` a joga em `UnexpectedFailure`.

A armadilha que ele resolve: o PostgREST põe o **SQLSTATE** em `code`, não um status HTTP.
`'23505'` (a trava de duplicidade do cadastro) lido como número vira "status 23505", cai
no ramo `>= 500` e o usuário lê *"o servidor está indisponível"* quando o que houve foi
*"esse produto já existe"*. Estado novo mapeado entra em `_httpStatusBySqlState`, com teste.

## Rotas — `routing/routes.dart`

São **11 telas** (`tecnico §3.4`), não as 6 do rascunho. Todas as rotas já estão
registradas; a que ainda não tem tela aponta para `UnderConstructionScreen`, que diz qual
história a entrega. **Cada história troca uma entrada do router pela tela real** — e
`UnderConstructionScreen` é apagada quando a última tela existir.

`/` é a Tela 1. `/purchases/new` é declarada **antes** de `/purchases/:id/edit`: o
`go_router` casa na ordem, e senão `new` viraria um id.

**Nenhuma rota é protegida** — não há sessão. O único `redirect` do app nasce na **H1**:
enquanto a etiqueta de `deviceUser` não estiver no Hive, toda rota cai em `/welcome`.

## Regras do projeto que o código ainda vai ter de honrar

Não são da arquitetura, são do negócio — e cada uma já derrubou uma versão de documento:

- **Dinheiro e quantidade nunca são `double`.** `numeric` no Postgres, decimal no Dart.
  Conteúdo de embalagem comparado em **inteiros na menor unidade**; arredondar só na
  formatação (decisão 24, `R15`).
- **`DateTime.now()` não desce para o domínio nem para o widget.** A data da compra é
  `date` sem fuso; o "hoje" nasce no ViewModel, no relógio do aparelho, e viaja como
  parâmetro (decisão 13). **Nenhum `now()` ou `current_date` no SQL** (decisão 7).
- **Nenhum limiar numérico no SQL.** O Postgres soma e agrupa; toda regra é Dart.
- **Soft delete nos seis cadastros** (categoria, tipo, marca, produto, embalagem,
  mercado): renomear vale para todo o histórico, e a compra aponta por chave, nunca
  copia o nome. Nenhum `DELETE` neles.
- **A trava de duplicidade compara normalizado** — sem maiúsculas, sem espaço sobrando,
  sem acento — e **quem responde ao usuário é o Dart**; o índice único é a rede embaixo.
- **O item da lista guarda a data em que entrou**, e só sai da lista se entrou antes ou
  no mesmo dia da compra lançada.
- **A lista nunca se mexe debaixo do dedo**: o que chega do outro celular entra por uma
  faixa de aviso, e é o toque dela que refaz a tela.
- **Teste sempre no PWA instalado na tela de início**, nunca em aba: o armazenamento é
  separado, e o deploy só passa a valer na abertura seguinte do app.

## Estado atual do projeto
**Atualizado em 28/08/2026**, ao fim do plano `temp/plan/plano-fundacao-e-entrega-1-2026-08-27.md`
(**passos 1 a 15, 17 a 21, 23 e 24 dos 25**). `flutter analyze` limpo, **271 testes
verdes**, cobertura de linha **92,2%**.

**Existe:** o esqueleto — `pubspec` (com o Flutter 3.44.0 pinado), `config/`, `routing/`
com as 11 rotas mais a 12ª descartável do spike, `ui/core/` (tema Material 3 claro,
`MessageView`, `AppFailure`, tradução de erro, `SingleFieldDialog`), `data/services/`
(exceções e o tradutor do Supabase) — e três features inteiras:

- **H1 — `DeviceUser`:** `device_user_repository` (abstract + `_local` + `_hive`),
  `DeviceUserViewModel`, a tela de boas-vindas, uma `/settings` mínima e o **único
  `redirect` do app**.
- **H2 — cadastro de produto em cinco níveis:** o domínio inteiro (`BaseUnit`/
  `MeasureUnit`, `Packaging`, `Category`, `ProductType`, `Brand`, `ProductRegistration`,
  `Product`, `normalizeName`, `findNameConflict`), o `catalog_repository`
  (abstract + `_local` + `_remote`), o `NewProductViewModel`, a **Tela 4** e os três
  diálogos que ela abre (categoria, marca e o mini-cadastro de tipo).
- **H3 — mercados:** `Store`, `store_repository` (abstract + `_local` + `_remote`),
  `StoreViewModel` e o `NewStoreDialog`. **Sem tela própria** — o diálogo mora dentro da
  Tela 3, que é da H7; até lá quem prova que funciona é o teste.

O `main.dart` tem **cinco saídas**, e nenhuma delas é tela branca — deixar uma exceção
escapar do `main` pinta exatamente isso, e o PWA instalado não tem console para
explicá-la. São elas: o app; `MisconfiguredApp()` quando um build fora de debug saiu sem
os dois `--dart-define`; `MisconfiguredApp.startupFailed()` quando eles vieram e o
`Supabase.initialize` recusou; `MisconfiguredApp.formattingUnavailable()` quando o `intl`
não carregou o pt-BR; e `MisconfiguredApp.storageUnavailable()` quando o navegador negou o
IndexedDB que o Hive usa (janela privada, dados de site bloqueados). As duas últimas
dividiam um `try` até 28/08 — e a falha do `intl` culpava o armazenamento. Qual delas
depende dos defines é decisão de `config/startup.dart` — função pura, porque `main()` não
é testável e essa escolha é a que só falha em deploy.

`Supabase.initialize` roda com `persistSession`, `autoRefreshToken` e `detectSessionInUri`
**desligados**: não há login, e os defaults punham o `localStorage` no caminho aguardado —
o que fazia uma janela privada acusar `SUPABASE_URL` errada, com a URL certa.

Em debug sem os defines o app roda nos fakes com a faixa **DADOS FAKE** na tela: nada do
que for digitado chega ao banco, e não há outro lugar onde isso apareça.

O `web/` deixou de ser o do `flutter create`: nome, descrição e `lang` em pt-BR, cores
vindas do `ColorScheme` (`test/web_assets_test.dart` falha se elas divergirem do tema),
ícones gerados por `uv run tool/make_icons.py` — troca de seed do tema pede rodar de
novo —, e as metas `apple-mobile-web-app-capable` e `robots: noindex` mais o
`web/robots.txt`, porque a URL não divulgada é a única barreira do sistema.

O `.github/workflows/deploy.yml` existe e **nunca rodou**: analisa, testa com cobertura
(**piso de 90%**, verificado em script), constrói com os dois `--dart-define` e publica
no Cloudflare Pages — e a publicação é **pulada, não falhada**, enquanto os secrets de A3
não existirem. A regra escrita nele: **`main` aponta para o `prod`, qualquer outra branch
publica um preview contra o `dev`**. Não há remote nem branch neste repositório ainda, e
**abrir uma branch antes do primeiro push é obrigatório** — senão a primeira publicação
sai de `main` contra a base sem backup do `R13`.

O `supabase/` existe com o `config.toml`, **três migrations** (a função `normalize_name`
`IMMUTABLE`, as 12 tabelas com a função transacional de cadastro, e a RLS permissiva com
os `grant`) e o **seed de 4 meses**, gerado por `uv run tool/make_seed.py` — reancorar é
rodar de novo. As três migrations e o seed foram **aplicados e verificados** num banco
descartável no Postgres 17 local (ver o parágrafo seguinte): as travas de duplicidade, o
`NULLS NOT DISTINCT`, a igualdade de embalagem em inteiros e o rollback da função
transacional foram exercitados um a um.
**Nada foi aplicado em `dev` nem em `prod`** — os projetos não existem (pendência A1).

**O banco local de desenvolvimento é o `postgresql@17` nativo do Homebrew, não o stack
Docker do Supabase** (decisão de 28/08/2026). É escolha, não limitação: o Docker Desktop
está instalado e funciona. A máquina é um Mac Intel i3-8100B de 4 núcleos com ~20 GB de
disco livres, o `supabase start` sobe ~10 containers dentro de uma VM, e nada do trabalho
de schema em curso distingue Postgres em container de Postgres nativo.

O que isso custa: **`supabase db reset` e `supabase db diff` não rodam** — os dois exigem
Docker. O `db reset` tem substituto, `uv run tool/local_dev/setup.py --reset` (ver
abaixo); o `db diff` **não tem**, então migration nova é SQL escrito à mão, que é como as
três primeiras nasceram. O que **não** custa: `supabase db push` não usa Docker, conecta
direto no banco hospedado. O passo 22 está liberado assim que o A1 sair.

**Subir o stack local só com gatilho**, e são dois: o Realtime da H5, ou o formato de
erro do PostgREST que o `supabase_error.dart` traduz numa versão diferente da 16.2 do
Homebrew. **A RLS não é gatilho**: a política é `for all ... using (true) with check
(true)` nas 12 tabelas — ela está ligada, mas não nega nada, porque não há login
(decisão 6). O que importa nela são os `grant`, sem os quais a role não alcança a
tabela, e isso o ambiente local já exercita. Quando o `dev` hospedado existir ele
já dá essa paridade — daí o stack local vira conveniência para não sujar o `dev`, não
obrigação. **Editar schema pelo dashboard do Supabase, em qualquer ambiente, está fora:**
o que se clica lá não vira arquivo, e o `supabase/migrations/` passa a mentir.

**O app em desenvolvimento fala com o Postgres local, e o que torna isso possível é
`tool/local_dev/`** (montado em 28/08/2026). O app é Flutter Web: não abre socket de
Postgres, fala PostgREST por HTTP. Então "usar o banco local" são três peças —
o banco, o `postgrest` na frente dele e um `caddy` que reescreve o prefixo `/rest/v1`
que o `supabase_flutter` monta para a raiz onde o PostgREST serve. Ambos nativos, do
Homebrew, sem container.

- `uv run tool/local_dev/setup.py` cria o `shopping_list_dev`, aplica bootstrap +
  as migrations pendentes + o seed, gera a chave e escreve as configs. Ele mantém o
  histórico em `supabase_migrations.schema_migrations`, **a mesma tabela e o mesmo
  nome de versão que o CLI usa**, então migration nova entra sobre um banco com dados
  em vez de exigir recriação. `--reset` recria do zero — é o `db reset` que o Docker
  levaria embora. O seed só é carregado num banco recém-criado; `--seed` força.
- `tool/local_dev/up.sh` sobe as duas peças; Ctrl+C derruba as duas.
- **`tool/local_dev/run.sh` é o atalho do dia a dia**: garante a API de pé e chama o
  `flutter run` já com os dois `--dart-define` lidos do `.env`. Sem argumento usa
  `-d chrome`; o que for passado atravessa para o `flutter run`. Se ele mesmo subiu a
  API, derruba ao sair; uma API que já estava de pé ele não toca.
- `setup.py` também imprime o `flutter run` completo, se preferir montar à mão.
- **A chave anon é um JWT HS256 com o claim `role: anon`** assinado por um segredo
  local. É esse claim que faz o PostgREST dar `SET ROLE anon`, que é o que sujeita a
  requisição aos `grant` do `rls.sql` — o mesmo mecanismo do projeto hospedado. Não
  espere que a RLS negue nada: a política é permissiva de propósito, mas a **assinatura
  é conferida**: chave forjada leva 401. A chave é **estável entre execuções** — o
  `setup.py` reaproveita a do `.env` enquanto ela casar com o segredo, e só emite outra
  quando o `.jwt_secret` muda. Segredo, chave e configs geradas são git-ignored, em 600.
- Com o Postgres fora do ar o `setup.py` para na primeira linha com a frase e o comando
  do `brew services`, em vez de um traceback de `subprocess.py`.
- `tool/local_dev/bootstrap.sql` existe porque as migrations assumem um projeto
  Supabase: o schema `extensions` (com `usage` para as roles), as roles `anon`,
  `authenticated` e `service_role`, o `authenticator` que o PostgREST usa para o
  `SET ROLE`, e a publication `supabase_realtime`. Um banco de `createdb` não tem
  nada disso.

**O que este ambiente não cobre: Realtime.** É uma app Elixir sem binário nativo, então
a H5 continua precisando do projeto hospedado ou do Docker. E o PostgREST do Homebrew é
o 16.2, que não é necessariamente a versão que o Supabase roda — o formato de erro pode
divergir do que `supabase_error.dart` espera. Verificado aqui contra ele: o SQLSTATE
`23505` chega como **HTTP 409**, e `normalize_name` passa os 11 casos de
`supabase/checks/normalize_cases.sql` chamada com a chave anon.

Uma coisa que este ambiente revelou e vale saber: **nem o Dart nem o SQL colapsam espaço
interno**. `normalizeName` faz `trim().toLowerCase()` mais a tabela de acentos, e o SQL
faz `lower(trim(unaccent(...)))` — os dois concordam, então o app não promete o que o
banco recusa, mas "Café  Pilão" com dois espaços é um cadastro diferente de
"Café Pilão".

**Os dois `_remote` continuam cobertos por `mocktail` na suíte**, e o que
`test/data/catalog_repository_remote_test.dart` fixa é o inviolável que falha em
silêncio: **todo método fecha em `rethrowAsKnownFailure`**, e o SQLSTATE `23505` vira 409
em vez de "status 23505" lido como `>= 500`. São 13 métodos, um teste cada.

Isso não mudou com o `tool/local_dev/`, e a razão é uma armadilha que custa uma tarde:
**`flutter_test` instala um `HttpOverrides` que responde 400 a toda requisição**. Um teste
de integração contra a API local só roda com `HttpOverrides.global = null` depois do
`ensureInitialized()` — e mesmo assim **não pode entrar na suíte**, porque o
`deploy.yml` roda `flutter test` sem API de pé e o teste derrubaria o CI. O caminho real
**foi exercitado à mão** com uma sonda descartável em 28/08/2026: o
`StoreRepositoryRemote` de verdade, com o `SupabaseClient` de verdade, fez `fetchAll` e
`create` contra o PostgREST local. É o que prova que a montagem serve ao app, e não
só ao `curl`.

Nessa sonda apareceu uma segunda coisa, e ela é do app, não do ambiente:
**`Supabase.initialize` constrói um `SharedPreferencesGotrueAsyncStorage` mesmo com
`persistSession: false`** — é o storage do PKCE que o comentário do `environment.dart`
descreve como criado incondicionalmente. Na VM de teste, sem o plugin, ele **lançou**
`MissingPluginException`; no navegador o `shared_preferences` usa `localStorage` e o
caminho se resolve. Ou seja, o "no pior caso imprime uma linha no console" daquele
comentário é mais otimista do que o observado. Se um dia a
`MisconfiguredApp.storageUnavailable()` aparecer sem explicação, **comece por aqui**.

**Não existe ainda:** o deploy publicado, o schema aplicado em `dev`, a S1 medida, e
nenhuma das outras oito telas. O que trava cada um está em
`docs/pendencias-lista-de-compras.md`: **o bloco B está fechado** (as cinco decisões
foram respondidas em 28/08/2026 e já estão no schema), e o que resta é o **bloco A** —
contas do Supabase (A1), a medição no iPhone (A2) e o Cloudflare (A3).

**A rota `/spike` e `lib/ui/spike/` são descartáveis:** existem para a medição S1 no
iPhone 12 e são apagadas junto com o teste delas assim que a pendência A2 estiver
respondida (passo 25 do plano).

**A próxima entrega:** os dois passos que dependem de você — publicar e medir a digitação
no iPhone 12 (passo 16, precisa de A1, A2 e A3) e aplicar o schema no `dev` (passo 22,
precisa de A1) —, e depois a **Entrega 2** (H4, H5, H6: a lista no corredor, o canal
Realtime e o diálogo do item).

**Uma decisão tomada ao escrever a Tela 4, e registrada aqui porque muda texto de
usuário:** `Packaging.label` **não escreve o "1 ×" da embalagem de peça única** —
"350 ml", não "1 × 350 ml" —, porque é esse o nome da prateleira que se procura no
lançamento, e é o que o wireframe da Tela 4 desenha. Com duas peças ou mais ele volta:
"12 × 350 ml".
