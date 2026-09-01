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
| `web` | só os eventos `online`/`offline` do navegador, atrás de um *conditional import* — **acréscimo à lista congelada**, ver "Divergências" |

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
| as três palavras do campo **Vendido** | `SellingChoice` | `Peso`, `Unidade` e `Volume`. `Peso` e `Volume` são o **mesmo** `by_weight`, e quem os separa é a unidade base do tipo. O único lugar onde o par (`SellingMode`, `BaseUnit`) vira UMA escolha |
| custo proporcional / preço por unidade base | `costPerBaseUnit` | preço ÷ conteúdo total |
| melhor custo | `bestCost` | o menor `costPerBaseUnit`, não o menor preço |
| mercado | `Store` | supermercado, feira, açougue, hortifrúti |
| lista de compras | `ShoppingList` / `ShoppingListItem` | o item guarda a **data em que entrou** |
| preferência da lista | `listPreference` | marca e embalagem desejadas. **Não mandam na baixa** |
| não encontrei | `notFound` | mora no diálogo do item; volta se a compra for apagada |
| lançar a compra | `Purchase` / `PurchaseItem` | produto, quantidade e **valor total pago** |
| dinheiro | `Money` | value object fino sobre `int cents`. **Nunca `double`** (`R15`) |
| opção do seletor de Produto | `ProductOption` | folha + cadastro + tipo + marca, mais a contagem e o preço de referência. Carrega a regra do C1 |
| preço da última compra | `PriceReference` | o **par** (valor pago, quantidade), nunca um preço por unidade arredondado |
| baixa da lista | `ListWriteOff` / `planWriteOffs` | o rastro do que a compra tirou da lista, e a regra pura que o decide |
| rascunho da compra | `PurchaseDraft` | a compra sendo digitada, no Hive. Sobrevive a app fechado |
| compra pendente | `pendingSubmission` | salva sem sinal; sobe sozinha com o app aberto ou na abertura seguinte |
| saldo do item | `remainingQuantity` | "restam 2 de 6 kg" — esse tira o item da lista |
| teto de gasto | `spendingCap` | valor máximo pretendido no mês |
| quem está usando | `deviceUser` | etiqueta local do aparelho. **Não é conta nem login** |
| janela de referência | `ReferenceWindow.rolling` / `.closed` | são duas e **nunca se misturam** |
| média mensal | `monthlyAverage` | consumo na janela fechada ÷ meses fechados de vida |
| falta comprar no mês | `remainingForMonth` | informa e nada mais |
| gasto | `spending` | quanto dinheiro saiu |
| consumo | `consumption` | quanta quantidade entrou, na unidade base |
| alerta de alta de preço | `priceIncreaseThreshold` | o limiar é `static const` no domínio |
| saldo de uma linha da compra | `AvailableAmount` | o que resta de um `PurchaseItem` enquanto `planWriteOffs` distribui a compra pelos itens da lista |
| grupo do painel `#1a` | `ProductTypeGroup` | nome da categoria + os tipos sob ela. A gêmea de `ShoppingListGroup` para o painel de acrescentar |
| porta de saída de uma tela | `MenuEntry` | rota + ícone + rótulo. A barra de baixo e o `≡` da Tela 1 listam as mesmas |
| estado ao qual um item volta | `RestoredListItem` | o que a correção manda em `p_restored`: id, `fulfilled_on` e `not_found`. **Nulo é resposta**, não ausência |
| desfazer a baixa | `undoWriteOffs` / `UndoResult` | a volta de `planWriteOffs`. Devolve os itens já descontados **e** o que vai para o SQL |
| linha do histórico | `PurchaseSummary` | data, mercado, quem lançou e o total já somado. **Não é uma `Purchase`** — não carrega item nenhum |
| a compra aberta para correção | `PurchaseDetail` | compra + itens + **rastro**. Os dois lados do desfazer |
| um dos seis cadastros | `CatalogKind` | o seletor da tela de manutenção. Carrega o rótulo e o artigo da frase de conflito |
| o que se pede à Tela 4 | `NewProductRequest` | `returnsSelection` (Tela 3) e `registrationId` (manutenção). Era um `bool` até a H10 |
| período do relatório | `ReportPeriod` | dois dias de calendário. Carrega o mês em curso, o deslocamento de mês e o teto do `›` |
| relatório do período | `PeriodReport` | as **três** agregações do mesmo intervalo, planas, como a função devolve |
| gasto por categoria | `CategorySpending` | **só dinheiro** — categoria não tem quantidade (divergência D-c) |
| gasto por tipo | `TypeSpending` | o nível que soma: quantidade na unidade base, preço médio e total |
| gasto por marca | `BrandSpending` | dentro do tipo. `brandId`/`name` **nulos** são o grupo sem marca, que o C2 descarta |
| seção do relatório | `ReportSection` / `ReportTypeLine` | a árvore que a Tela 5 desenha, montada por `buildReportSections` |
| linha de marca do relatório | `ReportBrandLine` | marca + a fatia que ela levou **do tipo**. A soma das linhas pode dar menos de 100%, e isso é o C2 |
| fatia de um nível no nível acima | `spendingShareInTenths` / `percentageInTenths` | inteiro em **décimos de ponto percentual**, 0 a 1000. **Nunca `double`**, e o `1000` só existe dentro da função |
| teto de gasto | `SpendingCap` | valor + mês em que passou a valer. Uma linha por **alteração**, nunca por mês |
| os dois cortes | `CapThreshold.approaching` / `.exceeded` | 80% e 100%. **O único lugar onde os dois números existem** |
| aviso de teto já dado | `CapAlerts` | as duas marcas de um mês. `false` é "não está cruzado", que é o que o **rearme** escreve |
| onde o mês está | `MonthCapStatus` | teto vigente + gasto + marcas. É o que `cap_states` responde |
| o que a avaliação produziu | `SpendingCapEvaluation` | o que **gravar** (`alerts`) e o que **mostrar** (`triggered` / `headline`) |
| aviso de item repetido | `SameDayAlert` | o tipo que o outro também comprou no mesmo dia. Nível do **tipo**, nunca da marca |
| janela rolante | `rollingWindowStart` | três meses de calendário terminando hoje, **com o mês em curso dentro**. A **fechada** nasce na H17, no mesmo arquivo |
| média da janela | `PriceBaseline` | o **par** (pago, quantidade) da janela inteira, nunca um preço por unidade arredondado. Ponderada, como o requisito 4 define |
| alerta de alta de preço | `PriceIncrease` | **existir É o alerta**; `null` é o silêncio. O limiar é `priceIncreaseThreshold`, `const` no domínio |
| cotação | `PriceQuote` | uma compra de uma folha em um mercado — a matéria-prima da aba de comparação, plana |
| linha da comparação | `ComparisonLine` | um mercado, o preço por unidade base e o dia. **A data informa, não ordena** |
| visão da comparação | `ComparisonScope.thisProduct` / `.wholeType` | marca com marca, ou o tipo inteiro por unidade base |
| cabeçalho de grupo do seletor | `ProductGroup.header` | o nome do tipo na Tela 3, o da categoria na Tela 5. Era `ProductType` até a H16 |
| consumo de um tipo nas duas janelas | `TypeConsumption` | a linha plana que o SQL devolve. Carrega a **data da primeira compra**, que é o que decide o divisor |
| média mensal | `MonthlyAverage` | já **arredondada**, mais o consumido no mês. É o `T` das duas telas |
| grupo das telas 2 e 6 | `MonthlyAverageGroup` | a terceira gêmea de `ShoppingListGroup` e `ProductTypeGroup` — e a única que serve **duas** telas |
| janela fechada | `closedWindow` | os três meses fechados anteriores. Mora ao lado de `rollingWindowStart`, e as duas **nunca se misturam** |
| meses fechados de vida | `closedMonthsOfLife` | 0 a 3. O **0 é resposta**: é o produto nascido no mês em curso |
| passo do arredondamento | `averageStepOf` / `roundToAverageStep` | uma casa decimal da unidade base. **Nunca transforma positivo em zero** |
| a sub-linha da Tela 6 | `listStatusLabel` | as quatro formas de "o que a lista está pedindo", mais o sufixo do "não encontrei" |
| o item aberto de um tipo | `findOpenItemOfType` | o mais antigo quando há mais de um. É onde "editando o item que já existe, nunca criando um segundo" é decidido |
| calculadora de custo proporcional | `proportional_cost.dart` | o painel `#3a`. **Não** `CostCalculator`: o que existe é a regra, e ela não é um objeto que calcula |
| linha da calculadora | `CostLine` | folha + marcada + preço + custo + diferença + `★`. **Não confundir com `ComparisonLine`**, que é a linha de MERCADO da H16 |
| as duas listas do painel | `CostCandidates` | o recorte da janela **mais a folha em lançamento** (`shown`) e o tipo inteiro (`all`). `canCompare` é a regra do botão da Tela 3 |
| a folha que está sendo lançada | `launching` | o parâmetro de `costCandidatesOf` e do painel. É a **única que abre marcada**, e a única que entra em `shown` sem preço (F-j) |
| resposta da calculadora | `CostRanking` | as linhas ordenadas, o `★`, para onde o `[ Usar… ]` aponta e a frase do rodapé |
| empate técnico | `costTieThreshold` | 1%. `const` no domínio, e **o único lugar onde o número existe** |
| conteúdo que um preço compra | `contentPricedOf` | o `totalContent` da embalagem, ou a unidade base no vendido a peso |
| preço de abertura da linha | `openingPriceOf` | o pago por **uma** embalagem na última compra. `null` é a embalagem nunca comprada na janela |

**`ProductRegistration` e `Packaging` foram escolhidos aqui, não pelo cliente** — os dois
termos são ambíguos em inglês. Confirme na H2, antes de a entidade existir; depois disso
renomear custa caro. Todo termo novo ambíguo é decisão do usuário: **pergunte** e
registre nesta tabela.

## Camadas

- `config/` — `dependencies.dart` (os providers de infraestrutura e **os overrides** de
  todos os repositories) e `environment.dart` (`--dart-define`). O `Provider` de cada
  repository é **declarado no arquivo do contrato**, em `data/`, e sobrescrito aqui.
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

## A corrente da igualdade — quem deve o `==`

A regra 8 exige `==`/`hashCode` cobrindo todos os campos, e a pergunta que sempre volta é
se algum pacote poupa esse trabalho. **Não poupa** — e o motivo é que a igualdade é uma
corrente de três elos, cada um com um dono diferente.

O `==` do `AsyncValue` **já vem pronto do Riverpod**
(`riverpod-3.4.2/lib/src/core/async_value.dart:654-664`): compara `runtimeType`,
`_loading`, `_errorFilled` e o valor — e o valor ele **delega ao `==` do seu `T`**.
`AsyncResult`, `AsyncData` e `AsyncError` herdam esse `==` sem redefinir nada. Ou seja:
**nunca se escreve o `==` de um `AsyncValue`**, e não há o que um gerador faça nele. O
único `==` que pode faltar é o do valor que viaja dentro do envelope.

| Elo | Dono | Já resolvido? |
|---|---|---|
| `AsyncData<T>` / `AsyncError<T>` | Riverpod | **sim**, `async_value.dart:654` |
| `IList<E>` | `fast_immutable_collections` | **sim**, `isDeepEquals: true` é o default |
| `E` — a entidade ou a classe | **nós** | **não**, escrito à mão |

Os dois formatos de `T` que o projeto usa mostram onde cada elo entra:

```
T é a coleção — AsyncNotifier<IList<Store>>
  AsyncData<IList<Store>>.==  ->  IList.==  ->  Store.==
       (Riverpod)                  (FIC)       (À MÃO)

T é uma classe que contém coleções — AsyncNotifier<CatalogOptions>
  AsyncData<CatalogOptions>.==  ->  CatalogOptions.==  ->  IList.==  ->  Category.==
       (Riverpod)                        (À MÃO)          (FIC)       (À MÃO)
```

**O `IList` fecha um elo, nunca a corrente.** Ele garante que uma coleção de mesmo
conteúdo seja `==`, e é por isso que um campo de coleção se compara com
`other.categories == categories`, sem `listEquals` e sem laço. Mas **abaixo** ele apenas
transporta a pergunta para o elemento, que continua devendo o seu `==`; e **acima** ele
não age: uma classe sem `==` compara por referência e a corrente arrebenta no primeiro
elo, sem as `IList` internas chegarem a ser consultadas. É o bug silencioso da regra 8 —
o Riverpod para de filtrar update, a tela repinta a cada refresh e nenhum erro aparece.

**Por que não `freezed` nem `equatable`** (os dois seguem proibidos em "Não fazer sem eu
pedir"):

- **`equatable` não elimina o erro.** O `props` é uma lista escrita à mão: esquecer um
  campo ali é o mesmo esquecimento de deixá-lo fora do `==`. Troca linhas por risco
  idêntico, e o teste campo a campo continua obrigatório do mesmo jeito.
- **`freezed` elimina**, porque o gerador enumera os campos sozinho — mas traz de volta o
  `build_runner` que a Stack recusou, e criaria duas convenções no mesmo repositório: as
  entidades atuais têm `==`, `copyWith` e `fromJson`/`toJson` escritos à mão. Adotá-lo só
  nas classes novas é pior do que qualquer um dos extremos.

Adotar qualquer um dos dois é **alteração de escopo**, não decisão de implementação. Se um
dia o número de classes com `==` manual passar da ordem de 40–50, a conta muda e vale
reabrir; hoje não.

A rede que de fato pega o campo esquecido é o **teste**: duas instâncias de campos iguais
são `==` e têm o mesmo `hashCode`, mais um caso trocando **um** campo por vez.

## Erros — duas categorias

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

**Mandatório:** todo texto de tela é **português do Brasil**, em **linguagem simples e
direta**, escrita para o **usuário leigo** — o casal que usa o app, não um desenvolvedor.
Nada de termo técnico (`token`, `cache`, `payload`, `sincronizar`, `endpoint`), nada de
inglês solto, nada de frase longa ou construção rebuscada. Título, botão, estado vazio e
mensagem de erro traduzida seguem esta regra sem exceção — inclusive as que hoje já
existem: revisar ao tocar na tela.

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

### Como rodar os testes — escopo mínimo, sempre

**Nunca rodar `flutter test` sem caminho.** A suíte inteira leva minutos e enche o
contexto com centenas de linhas que não têm relação com o que está sendo editado.
Rodar **só o arquivo ou a pasta que está sendo mexida**:

```bash
flutter test test/domain/purchase_test.dart          # um arquivo
flutter test test/ui/edit_purchase_screen_test.dart  # um arquivo
flutter test test/domain/                            # uma pasta, quando mexi em várias
flutter test test/ui/catalog_view_model_test.dart --name 'guards against double tap'
```

**`--name` não tem abreviação `-n`** neste Flutter — `flutter test --help` só lista
`--name=<regexp>`, e o `-n` é engolido como caminho.

**Achar o teste do arquivo editado é palpite mais confirmação, não tabela.** O palpite é o
basename (`purchase.dart` → `purchase_test.dart`, `new_product_screen.dart` →
`new_product_screen_test.dart`), e ele acerta na maioria — mas **erra na família do
catálogo**, onde `category.dart`, `brand.dart`, `product_type.dart` e `catalog_entry.dart`
são cobertos por um `test/domain/catalog_test.dart` só. Então confirme antes de rodar:

```bash
find test -name 'purchase_test.dart'   # o palpite existe?
grep -rl 'PurchaseItem' test/          # quem mais toca o que editei
```

O `grep` pelo símbolo é o que vale quando o palpite falha, quando o arquivo é um helper de
`test/helpers/`, ou quando a entidade é montada por várias telas. Para rodar todos de uma
vez, **`xargs -r`** — sem o `-r`, um grep que não acha nada chama `flutter test` sem
argumento nenhum e dispara justamente a suíte inteira que esta seção proíbe:

```bash
grep -rl 'PurchaseItem' test/ | xargs -r flutter test
```

**O mesmo vale para o `flutter analyze`**, que aceita arquivo solto (0,2s de análise,
~3s de relógio com o `pub get` na frente):
`flutter analyze lib/domain/models/purchase.dart` ou `flutter analyze lib/ui/purchase/`,
não o projeto inteiro.

**A cobertura também é medida no escopo mínimo**, com uma ressalva que muda como o número
é lido:

```bash
flutter test --coverage --coverage-path coverage/scoped.info test/domain/purchase_test.dart
awk -F: '/^SF:/{f=$2} /^LF:/{lf=$2} /^LH:/{printf "%6.1f%%  %s\n", lf?100*$2/lf:0, f}' \
  coverage/scoped.info | grep 'models/purchase.dart'
```

**Filtre pelo arquivo editado; não leia a lista inteira.** O relatório parcial traz toda
biblioteca que a cadeia de imports **carregou**, não só a testada: `uuid_test.dart`
sozinho produz 26 entradas, e 25 delas aparecem com 0,0% apenas por terem sido
importadas. Ordenar isso por percentual põe justamente esse ruído no topo e parece um
projeto sem teste nenhum.

**O número parcial é PISO, não a cobertura do arquivo.** Um arquivo de produção costuma
ser exercitado por vários testes — `Purchase` aparece em cinco (`purchase_test`,
`purchase_types_test`, `purchase_repository_remote_test`, `new_purchase_screen_test`,
`edit_purchase_view_model_test`) —, e medir só um deles credita apenas as linhas que
aquele arquivo alcançou. Serve para responder *"o que acabei de escrever tem teste?"*;
**não** serve para dizer que um arquivo está abaixo do piso. Para essa conclusão, o
`grep -rl` acima define o conjunto, e ele inteiro entra na medição.

**O `--coverage-path` não é opcional.** Sem ele o `--coverage` **sobrescreve**
`coverage/lcov.info` com apenas as bibliotecas que aquele teste tocou — o relatório do
projeto inteiro vira o de um arquivo, e a conta dos 90% passa a mentir para menos sem
nenhum aviso. Rodar parcial sempre em `coverage/scoped.info`, que é git-ignored junto com
o resto de `coverage/`.

**A única hora de rodar tudo** — e é o usuário quem pede: antes de um commit que fecha uma
história ou um plano. Aí sim `flutter analyze` sem caminho e `flutter test --coverage` sem
caminho, porque **o piso de 90% do `deploy.yml` é do projeto inteiro** e nenhuma soma
parcial responde por ele.

Fora disso, **peça** antes de rodar a suíte completa.

## Não fazer sem eu pedir

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
| Tratamento de erro | `tecnico §3.11`: `Result<T>` selado atravessando as camadas | **`AsyncValue` + `AppFailure`** | o `Result<T>` do guia oficial existe aqui com outro nome: `AsyncResult<T>`, do próprio Riverpod — `sealed`, `AsyncData \| AsyncError`, dartdoc *"A variant of `AsyncValue` that excludes `AsyncLoading`... only data\|error states"* (`riverpod-3.4.2/lib/src/core/async_value.dart:671`), exportado em `riverpod.dart:25`. O guia manda escrever a classe porque é agnóstico de gerenciador de estado; com Riverpod ela vem pronta. O `AppFailure` cobre o que nenhum dos dois cobre: classificar a falha antes de virar frase — o `Error<T>` do guia carrega `Exception` crua |
| `analysis_options.yaml` | `tecnico §3.13`: o padrão do `flutter_lints` | **mantido o padrão** | a skill sugere 3 lints extras; a decisão congelada vence, e a diferença é irrelevante |
| Detecção de conexão | `tecnico §3`: cinco pacotes, "nada além disso" | **`web` entra**, como 3ª adição | a decisão 22 proíbe `connectivity_plus`, e os eventos `online`/`offline` vêm do `package:web`. Ele já era `transitive`; declará-lo é o que cala o lint `depend_on_referenced_packages`. Fica atrás de um *conditional import*, para a VM do `flutter test` nunca o compilar |
| Valor pré-preenchido na Tela 3 | `handoff §H7`: "quantidade convertida × preço da unidade base da última compra" | **regra de três inteira**: `pago × quantidadeNova ÷ quantidadeAnterior`, meio-para-cima | as duas fórmulas são a mesma **antes** do arredondamento, e só esta não erra: 12 L por R$ 62,00 são R$ 5,1667/L, que arredondados para 517 centavos devolvem **R$ 62,04** para a mesma compra |
| Seletor de período da Tela 5 (**D-b**) | `wireframes §Tela 5`: dois campos de data | **os dois campos + dois atalhos de mês** (`‹ Julho` / `Setembro ›`) | ler o mês anterior é a pergunta mais frequente da tela, e duas voltas de calendário para fazê-la é atrito. Remover é apagar um widget |
| Quantidade por categoria (**D-c**) | `handoff §H11`: "o **total consumido** e o **total gasto** agrupados por **categoria**" | **a categoria só tem dinheiro** | somar 6 kg de carne com 12 L de refrigerante não dá número nenhum, e o `wireframes §Tela 5` desenha "Carnes  R$ 480" sem quantidade ao lado. `CategorySpending` não tem o campo: o erro não é representável |
| O `›` da Tela 5 (**D-d**) | — não estava escrito | **para no mês em curso** (`ReportPeriod.canShiftForward`) | não há relatório de amanhã — e não é enfeite: sem ele o período vai para setembro e o campo de data abre com `initialDate` 01/09 contra `lastDate`, que é o assert `!initialDate.isAfter(lastDate)` de `showDatePicker`. **Crash de tela, não relatório vazio.** O outro lado da mesma regra é `latestSelectableDay`, que é o **fim do mês em curso** e não "hoje": o relatório abre no mês inteiro, então o próprio 31/08 tem de ser um dia que o calendário mostra |
| Onde os cortes são comparados (**D-e**) | `tecnico §5`: a regra fica no domínio | **em Dart, ANTES da escrita**; o SQL recebe o estado desejado das duas marcas e só grava | o que atravessa não é uma ordem de marcar: `true` grava preservando o carimbo, `false` **apaga** — e é o mesmo código nos dois casos, o que torna o rearme uma linha em vez de um ramo |
| Os nomes da H13 (**D-f**) | — não estavam escritos | `SpendingCap`, `CapAlerts`, `CapThreshold`, `MonthCapStatus`, `SameDayAlert` | respondido pelo usuário em 30/08/2026; estão no glossário acima |
| O reenvio automático da H8 (**D-g**) | — não estava escrito | **grava as marcas e não mostra diálogo nenhum** | não há tela aberta para receber um diálogo. Quem quiser ver a situação lê o "Gastou X de Y" do relatório, que é o que o requisito 9 manda |
| Os dois cortes na mesma escrita (**D-h**) | `wireframes §Tela 3` desenha as duas frases | **só a mais grave aparece** — "⚠ O teto do mês estourou." | as **duas marcas são gravadas** assim mesmo, que é o que impede o lançamento seguinte de soltar o estouro sozinho. Dizer "passou de 80%" ao lado de "estourou" é ruído |
| A frase do teto nomeia o mês? (**D-i**) | — não estava escrito | **não nomeia** — "O teto do mês estourou.", palavra por palavra como o `wireframes §Tela 3` escreve | a variante "O teto de agosto/2026 estourou" é mais honesta na compra atrasada (lançada em setembro, cruzando um corte de **agosto**), e foi recusada: divergir de um documento acima do plano para cobrir um caso de borda não paga o preço. O caso de borda **está aceito**, e a volta é uma linha |
| Teto de R$ 0,00 (**D-j**) | o `check` da tabela aceita `>= 0` | **o domínio recusa** (`InvalidSpendingCap`) | um teto zero nasce estourado, e `usagePercent` dividiria por zero |
| O "Gastou R$ X" da Tela 5 (**D-k**) | — não estava escrito | usa o **`PeriodReport.total` que já está na tela**; o `MonthCapStatus` só responde o "de R$ Y" | somar o mês duas vezes por dois caminhos é como um relatório passa a divergir de si mesmo |
| Onde a consulta da H14 roda (**D-l**) | `handoff §H14` não diz | **antes da escrita**, junto das outras duas leituras | dois lançamentos no mesmo instante não se enxergam e aquele aviso se perde. É aceito: a janela é de milissegundos e a compra é registrada normalmente. **É a única corrida desta entrega que não se auto-corrige** |
| Quem semeia o aviso de item repetido (**D-m**) | — não estava escrito | **só o fake**; o `seed.sql` fica como está | as compras do fake têm data fixa e caem fora da janela "hoje ou ontem" em dois dias, e o seed gera **uma pessoa por dia** — nenhum dos dois consegue disparar a H14. No `dev` hospedado ela nunca aparece sozinha: verificá-la lá é lançar duas compras à mão, do mesmo tipo e no mesmo dia, com as duas etiquetas |
| O percentual do teto (`usagePercent`) | o plano da H13 dizia "divisão inteira: 87" | **arredonda para o inteiro mais próximo** | R$ 1.300 de R$ 1.500 é 86,66…%, e `requisitos §9` e `wireframes §Tela E3` escrevem esse caso como **87%**. Truncar responderia 86 e faria a tela contradizer a frase que o cliente lê. Arredondamento **em inteiros** (`+ amount ~/ 2` antes da divisão) — e ele não decide nada: qual corte disparou é `CapThreshold.isCrossedBy`, comparação exata e sem divisão nenhuma |
| Com **um mercado só** na janela (**D-n**) | `handoff §H16` chama isso de estado vazio | a linha **aparece**, e abaixo dela vem *"Comprado em um mercado só nos últimos 3 meses — ainda não há com o que comparar."* | esconder o preço que ele tem é esconder dado. A frase entrega o estado sem apagar a informação |
| A visão **Tipo inteiro** (**D-o**) | — não estava escrito | uma linha por **mercado** — a compra mais recente daquele tipo naquele mercado | é o que o wireframe desenha, e é a pergunta da tela ("**onde** sai mais barato"). Uma linha por mercado × produto viraria uma lista que não responde mais isso |
| Onde o ⚠ da H15 aparece (**D-p**) | — não estava escrito | **só na Tela 3** | `handoff §H15`, "Telas envolvidas: Tela 3 `#3`". Na correção o aviso chega tarde e sem ação possível |
| A consulta da H16 (**D-q**) | `handoff §fronteira SQL`: "preço mais recente por mercado no intervalo" | **nenhuma migration**: `select` do PostgREST + redução em Dart | o precedente é `rankOptions`, que já escolhe a compra mais recente em Dart pelo mesmo motivo (`order` sobre embed ordena os filhos). A visão "Tipo inteiro" sai de graça do mesmo `IList`, e nada disso depende do A1 |
| Onde a janela rolante mora (**D-r**) | `threeMonthsBefore` em `ui/purchase/view_model/` | `rollingWindowStart` em `domain/models/reference_window.dart` | a H16 mora em `ui/report/` e precisaria importar `ui/purchase/` por causa de uma regra de negócio — import cruzado entre features, que é o lugar errado desde sempre |
| Onde o limiar de 10% é comparado (**D-s**) | — não estava escrito | sobre o valor **cheio**; só a exibição arredonda | +9,6% **não** alerta, mesmo arredondando para 10%. É a mesma régua da porcentagem do teto: calculada sobre os valores cheios e só então arredondada |
| O par de radios do `wireframes §Tela 5` (**D-t**) | dois radios | um `SegmentedButton<ComparisonScope>` | é o Material 3 do projeto para escolha binária, e o precedente é o `SegmentedButton<SellingMode>` de `new_product_screen.dart`. Divergência cosmética |
| O cabeçalho do grupo do seletor (**D-u**) | `ProductGroup.type` (`ProductType`) | `ProductGroup.header` (`String`) | o mesmo seletor agrupa por **tipo** na Tela 3 e por **categoria** na Tela 5, e o único leitor lia `group.type.name`. Um parâmetro `groupBy` em vez de dois widgets que divergiriam na primeira mudança |
| "Este produto" na folha **sem marca** (**D-v**) | `handoff §H16`: "um produto sem marca ... sobe para o tipo, pelo mesmo motivo de H15" | **não sobe**: quem sobe é o toque em "Tipo inteiro" | na H15 subir é a única saída — o alerta é uma linha só e não há para onde ir. Aqui há: a subida está a um toque, é o que o wireframe desenha, e é o usuário quem a controla. Subir sozinho daria o **mesmo resultado nas duas visões** para toda folha sem marca — metade do catálogo do casal —, deixando um botão que não faz nada |
| A consulta da H19 (**F-a**) | `handoff §8`: "Último valor pago por embalagem = total do item ÷ quantidade — a escrever" | **nenhuma consulta e nenhuma migration** | `fetchRecentItems` já traz o par (pago, quantidade) de toda linha da janela, e `rankOptions` já escolhe a mais recente por folha. O "total ÷ quantidade" é `PriceReference.estimateFor`, testada desde a H7. Mesmo precedente da **D-q** |
| Os estados "carregando" e "erro" do `#3a` (**F-b**) | `wireframes §#3a Estados` desenha os dois | **não existem** | eram estados do I/O que a F-a eliminou. O painel abre sobre dados que **já estão na tela**; se a carga falhou não há produto escolhido, não há tipo, e o botão nem aparece |
| A ordem das linhas do `#3a` (**F-c**) | `wireframes §#3a` desenha fora da ordem de custo | **do menor para o maior custo por unidade base** | `requisitos §17` — "uma lista ordenada do mais barato para o mais caro" — e o `handoff §1.4` registra a ausência como **defeito do documento**. Requisitos vencem wireframes |
| O `−%` no empate técnico (**F-d**) | — não estava escrito | **continua ao lado de toda linha cuja diferença chegue a 1%**; o que some é o `★` | é uma régua só, por linha. Uma linha 40% mais cara não deixa de ser 40% mais cara porque as duas primeiras empataram |
| "Aparece e some sem animação" (**F-e**) | `wireframes §Efeitos` | **`showModalBottomSheet`**, com a animação padrão do Material | é o que o `#1a` já faz desde a Entrega 2. Tirar a animação exige uma `PageRouteBuilder` própria e leva a barra de arrasto junto |
| Onde mora o estado do painel (**F-f**) | — não estava escrito | **`StatefulWidget` local, sem ViewModel e sem provider** | não há I/O (F-a), então não há carga inicial a proteger nem ação a guardar. O precedente é o `ProductField`, que não recebe `ref` — e é o que deixa o teste rodar sem container |
| O que o fake conta em debug (**F-g**) | — | o seed ganha **duas linhas** (a lata a R$ 4,00 e a garrafa a R$ 10,00); o **fardo não muda** | sem elas o tipo Refrigerante tem uma folha só com preço. O veredito em debug é o do wireframe — a garrafa —, mas as porcentagens não são as do documento, porque o fardo continua nos R$ 62,00 que dois arquivos de teste fixam |
| `[ Usar… ]` no empate técnico (**F-h**) | `wireframes §#3a`: "o botão continua, apontando para a de menor custo" | **igual ao documento** | fica registrado porque é contraintuitivo: o sistema para de **afirmar** vantagem, mas não tira dele a saída de escolher sem fechar o painel |
| Produto cadastrado durante a compra (**F-i**) | — não estava escrito | **entra na lista do painel**, sem preço | o `_justRegistered` da Tela 3 é produto ativo do tipo, que é a definição de "opção" do requisito 17. Conta inclusive para o `>= 2` que faz o botão aparecer |
| A folha em lançamento fora do recorte (**F-j**) | — não estava escrito | **ela SEMPRE aparece em `shown`**, e por isso `costCandidatesOf` recebe `launching` | sem isso o painel abre **sem caixa marcada nenhuma** justamente no caso motivador do requisito 17 — "vale a pena levar o tamanho grande que eu nunca levei" — e no caso da F-i |
| A linha do painel (**F-k**) | `wireframes §#3a` desenha uma tabela de cinco colunas | **duas alturas**: o nome sozinho em cima, caixa + preço + custo + `−%` embaixo | as colunas fixas mais o alvo de toque somam ~220 pt; num iPhone 12 (390 pt) o nome longo quebra em três linhas e desalinha a coluna que o olho percorre. Em duas alturas o alinhamento é **melhor**, não pior |
| O `if case` do `_selected` (**F-l**) | o plano escrevia `if (widget.launching.id case final id?) id` | **o null-aware element `{?widget.launching.id}`** | o `use_null_aware_elements` do `flutter_lints` do projeto acusa a forma do plano, e o checklist exige `flutter analyze` limpo. É a primeira ocorrência da sintaxe em `lib/`, e é o lint do projeto que a pede |
| O `%` do tipo e o da marca (**G-a**) | — não estava escrito | o do **tipo** é sobre o total da **categoria**, e o da **marca** sobre o total do **tipo** — nunca sobre o total do período | é o número escrito na linha imediatamente acima, na mesma tela. Dividir pelo período responderia "que fatia do mês foi Coca-Cola", que é uma pergunta que a tela não faz e que ninguém consegue conferir de cabeça |
| A soma dos `%` das marcas (**G-b**) | — não estava escrito | **pode dar menos de 100%**, e isso é aceito | a regra **C2** descarta o grupo de marca nula do detalhamento, mas o total do tipo continua contando o que ele gastou. Um "soma 66,7%" diz que um terço da compra daquele tipo não tinha marca registrada — e essa é justamente a informação que dividir pela soma das marcas mostradas apagaria. **Escolhido pelo usuário em 31/08/2026** |
| Onde a fórmula do percentual mora (**G-c**) | a conta estava dentro de `PeriodReport.percentageOf` | uma função pura só, `spendingShareInTenths`, e a da H12 **delega a ela** | três cópias do arredondamento meio-para-cima são três lugares para divergirem no meio décimo |
| A casa decimal do percentual (**G-d**) | `requisitos §7` e `wireframes §Tela 5` escrevem "40%" | **uma casa decimal, nos TRÊS níveis** — `(45,1%)`, não `(45%)` | **escolhido pelo usuário em 31/08/2026**, sabendo que alcança a H12. Duas réguas na mesma tela — a categoria inteira e o tipo com decimal, uma linha abaixo da outra — seria pior do que a divergência. A divergência é de exibição, o número é o mesmo com mais precisão, e voltar atrás é trocar o `1000` por `100` num lugar só |
| Como o décimo é representado (**G-e**) | — não estava escrito | um **`int` em décimos de ponto percentual** (0..1000), nunca um `double`, e o nome do campo diz a unidade: `percentageInTenths` | é a decisão 24 / `R15` outra vez, e é a casa da regra 6: `spendingShareInTenths` é o único lugar do projeto onde o `1000` existe. O nome longo é o estilo da casa — `quantityInBaseUnit`, `costPerBaseUnit` |
| Os nomes do campo Vendido (**H-a**) | `wireframes §Tela 4`: `( ) A peso  (•) Por peça`, e o glossário de `requisitos` chama o par de *"vendido a peso / vendido por peça"* | **três palavras — `Peso`, `Unidade`, `Volume` — com só a grandeza do tipo clicável ao lado de `Unidade`** | "A peso" não nomeia o azeite a granel, que é medido em **litro** — e o princípio **já estava aceito nos requisitos desde 26/08/2026**: `§295-300` e `§1133-1142` mandam o rótulo do campo do lançamento vir da unidade base do tipo, e `ProductOption.quantityLabel` já escreve `Peso (kg)` / `Volume (L)` na Tela 3. O campo **Vendido** era o último lugar da Tela 4 que ainda não obedecia. O banco continua com **dois** modos: `Peso` e `Volume` são o mesmo `by_weight`, e `grep -n "SellingChoice" lib/data/` não devolve nada. **Escolhido pelo usuário em 01/09/2026** |
| O solto num tipo contado por unidade (**H-b**) | **estava escrito, e com data.** `requisitos §295-300`: *"o rótulo do campo vem da unidade base do tipo (decisão de 26/08/2026) … **'Quantidade (un)' no que é vendido solto e contado**"*, repetido em `§1133-1142`. E o código implementa: o ramo `BaseUnit.unit` de `ProductOption.quantityLabel` só é alcançável nesse estado, e tem teste próprio — o `looseRolls` de `product_option_test.dart` | **deixa de existir PELA TELA 4**: num tipo de unidade base `unit` só `Unidade` é clicável, e o avulso vira uma embalagem de `1 un`. O domínio continua aceitando o estado; o que some é a porta que o cria | é o preço de a grandeza nomear o botão, e **o usuário decidiu em 01/09/2026 mantê-lo, sabendo que revoga a decisão de 26/08** — `un` e "quantidade" são a mesma medida, então o solto contado não perde grandeza nenhuma, só ganha um passo de cadastro (12 × conteúdo 1 dá 12, igual). Nenhum cadastro **gravado** cai no caso: o fake e o `seed.sql` só têm `by_weight` em tipos de quilo. Se um dia existir, `SellingChoice.of` o mostra como `Unidade` sem tocar no gravado, e `looseNameOf` o chama de "unidade", **nunca de "peso"** — as duas passagens dos `requisitos` foram marcadas como revogadas no mesmo dia |

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

## O tradutor de erro do Supabase — `data/services/supabase_error.dart`

**Todo método de `_remote` fecha seu I/O com `rethrowAsKnownFailure(e, st)`.** Sem isso a
`PostgrestException` sobe crua e o `AppFailure` a joga em `UnexpectedFailure`.

A armadilha que ele resolve: o PostgREST põe o **SQLSTATE** em `code`, não um status HTTP.
`'23505'` (a trava de duplicidade do cadastro) lido como número vira "status 23505", cai
no ramo `>= 500` e o usuário lê *"o servidor está indisponível"* quando o que houve foi
*"esse produto já existe"*. Estado novo mapeado entra em `_httpStatusBySqlState`, com teste.

## Rotas — `routing/routes.dart`

São **11 telas** (`tecnico §3.4`), não as 6 do rascunho, e **desde a Entrega 8 todas as
onze têm tela**. Até ali a que ainda não tinha apontava para uma `UnderConstructionScreen`
que dizia qual história a entregava, e cada história trocava uma entrada do router pela
tela real. Aquela tela e o `pendingDestinations` ao lado dela foram apagados com as duas
últimas entradas.

`/suggestions` é a Tela 2 e a Tela 1 a abre com **`push`**: as rotas são planas, e o
wireframe manda a Tela 2 **voltar** para a lista — tanto pelo Voltar quanto pelo
`[ Adicionar selecionados ]`. `/remaining` é a Tela 6 e é o **terceiro destino
permanente** da barra de baixo, alcançado com `go` e sem Voltar nenhum, pelo mesmo motivo
de `/` e `/reports`.

`/` é a Tela 1. `/purchases/new` é a Tela 3, e é declarada **antes** de
`/purchases/:id/edit`: o `go_router` casa na ordem, e senão `new` viraria um id.

`/products/new` é a única rota que lê `state.extra`, e desde a H10 ele é um
**`NewProductRequest`**, não um `bool`: a Tela 3 a abre com
`extra: const NewProductRequest(returnsSelection: true)` para pedir a folha escolhida **de
volta**, e a manutenção do cadastro a abre com `registrationId` para dizer **qual**
cadastro carregar. Quem chega pelo menu não passa nada e cai no `const
NewProductRequest()`. **`push`, nunca `go`:** `go` trocaria a rota e levaria embora a Tela
3 com a compra digitada nela.

`/purchases` abre a correção com `pushNamed`, pelo mesmo motivo escrito ao contrário: as
rotas são **planas**, sem `routes:` aninhado, então o `go_router` não monta pilha a partir
do path — um `go` deixaria `canPop()` falso e a correção abriria com o ícone de casa em
vez do Voltar, perdendo o histórico de onde a pessoa veio.

`/reports` é o contrário dos dois acima: ela **não carrega Voltar nenhum**, nem empilhada.
É um dos **três destinos permanentes** da barra de baixo, e a nota do wireframe é
explícita — "alternar entre eles não é voltar". A Tela 1 já era assim; a Tela 5 é a
segunda, e `router_test` tem um caso para cada uma, para a próxima tela com barra não
nascer com um botão que navega para ela mesma.

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
**Atualizado em 31/08/2026**, ao fim da Entrega 10
(`temp/plan/plano-percentuais-tipo-e-marca-2026-08-31.md`, os 14 passos).
`flutter analyze` limpo, **1387 testes verdes**, cobertura de linha **94,1%** — acima do
piso de 90% do `deploy.yml`, com a maior margem que o projeto já teve, e **os cinco
arquivos tocados por esta entrega estão em 100%**. **As dezenove histórias estão
fechadas, e com elas os 18 requisitos Essenciais** — a Entrega 10 é **acréscimo fora
delas**, pedido pelo usuário em 31/08/2026: nenhuma H e nenhum requisito pedem o
percentual de **tipo dentro da categoria** e de **marca dentro do tipo**, e a casa
decimal que veio junto (decisão **G-d**) alcança de volta a H12. Sem migration, sem
repository, sem provider e sem rota — a fatia é uma divisão em Dart sobre as três
agregações que a `report_period` já devolve.

Antes dela veio a Entrega 9
(`plano-h19-calculadora-de-custo-2026-08-31.md`, os 15 passos — H19), que fechou a
última história. As onze telas já existiam desde a Entrega 8 — nem a H19 nem a Entrega
10 criam tela: o `#3a` é um painel, e os percentuais são texto nas duas visões da Tela
5. Antes veio a Entrega 8
(`plano-h17-h18-planejar-2026-08-30.md`, os 32 passos), onde morreram
`pending_destinations.dart` e `under_construction_screen.dart`; a Entrega 7
(`plano-h15-h16-estou-pagando-caro-2026-08-30.md`, os 27 passos), a Entrega 6 (`plano-h13-h14-teto-e-item-repetido-2026-08-30.md`, os 30 passos), a
Entrega 5 (`plano-h11-h12-relatorio-do-periodo-2026-08-30.md`, os 27 passos), e antes a
Entrega 1 (`plano-fundacao-e-entrega-1-2026-08-27.md`), a Entrega 2
(`plano-entrega-2-lista-no-corredor-2026-08-28.md`), a Entrega 3
(`plano-h7-h8-lancar-compra-2026-08-28.md`, os 28 passos), a doutrina de erro
(`plano-doutrina-de-erro-e-fim-dos-records-2026-08-29.md`) e a Entrega 4
(`plano-entrega-4-consertar-2026-08-28.md`, os 33 passos).

**O que o plano de 29/08 mudou, e não é feature:** a doutrina de erro passou a estar
escrita — as **regras 16 e 17** e a seção "A corrente da igualdade" acima —, os **15
records** do projeto (11 `typedef` e 4 inline, um deles de tipo inferido) viraram 12
`final class` mais 2 hierarquias `sealed`, o `OnlineStatus` saiu de `data/services/` para
`ui/core/` porque um `Notifier` é estado, `groupTypesByCategory` saiu de dentro do
`add_item_panel` para `domain/models/product_type_group.dart`, e o `AppFailure.from`
ficou idempotente. Junto veio a correção de **um bug de tela**: `CatalogViewModel.save`
devolvia `(error: null, saved: null)` quando a guarda de reentrância disparava, e a Tela 4
lia isso como sucesso — dizia *"Produto salvo."* e saía da tela **sem ter salvo nada**. A
causa foi removida junto com o sintoma: `save` e `addPackagings` ganharam o
`_writingRegistration`, e deixaram de cair na guarda das três criações de cadastro.

**A verificação de que nenhum record voltou** é o grep de **literais**, não o de
`^typedef` — um record de tipo inferido (`final x = [(id: ..., left: ...)]`) não tem
`({...})` escrito em lugar nenhum:

```
grep -rnE "(^|[^A-Za-z0-9_])\(\s*[a-z][A-Za-z0-9_]*:" lib/ \
  | grep -vE "\b[A-Za-z_][A-Za-z0-9_]*\("
```

Ele devolve hoje uma linha só, e ela é falso positivo: `Radio<int>(value: ...)`, cujo
`<int>` é o que engana a segunda metade do comando.

**A cobertura passou o piso de 90% do `deploy.yml` na Entrega 4, e a dívida que a segurava
foi paga.** Era de dois arquivos da Entrega 2 sem teste de widget nenhum —
`ui/shopping_list/widgets/item_dialog.dart` (0 de 140 linhas) e `add_item_panel.dart`
(1 de 130) —, e os dois ganharam o seu na linha 1 daquela entrega, **antes** de qualquer
código dela. Hoje o projeto está em **94,1%**, e **todo arquivo de `ui/report/` está em
100%**. A margem continua estreita: uma tela nova sem teste volta a derrubá-la.

**Existe:** o esqueleto — `pubspec` (com o Flutter 3.44.0 pinado), `config/`, `routing/`
com as 11 rotas mais a 12ª descartável do spike, `ui/core/` (tema Material 3 claro,
`MessageView`, `AppFailure`, tradução de erro, `SingleFieldDialog`, `formatting.dart`,
`MenuEntry`, o `MainMenu` e o `OnlineStatus`), `data/services/` (exceções, o tradutor do
Supabase e a leitura de plataforma do online/offline — o estado que a expõe é
`ui/core/online_status.dart`) — e
**as onze telas**:

- **H1 — `DeviceUser`:** `device_user_repository` (abstract + `_local` + `_hive`),
  `DeviceUserViewModel`, a tela de boas-vindas, uma `/settings` mínima e o **único
  `redirect` do app**.
- **H2 — cadastro de produto em cinco níveis:** o domínio inteiro (`BaseUnit`/
  `MeasureUnit`, `Packaging`, `Category`, `ProductType`, `Brand`, `ProductRegistration`,
  `Product`, `normalizeName`, `findNameConflict`), o `catalog_repository`
  (abstract + `_local` + `_remote`), o **`CatalogViewModel`** (não `NewProductViewModel`,
  como este parágrafo dizia até 30/08), a **Tela 4** e os três diálogos que ela abre
  (categoria, marca e o mini-cadastro de tipo).
- **H3 — mercados:** `Store`, `store_repository` (abstract + `_local` + `_remote`),
  `StoreViewModel` e o `NewStoreDialog`. **Sem tela própria** — o diálogo mora dentro da
  Tela 3, e é ela quem finalmente o abre.
- **H4/H5/H6 — a lista no corredor (Entrega 2):** `ShoppingListItem`, `groupByCategory`,
  `calendar_day.dart`, `uuid.dart`, o `shopping_list_repository` (abstract + `_local` +
  `_remote`, este com o canal Realtime e o descarte do próprio eco), o
  `ShoppingListViewModel`, o `PendingChangesNotifier` e a **Tela 1** com o painel `#1a` e
  o diálogo do item.
- **H7/H8 — lançar a compra (Entrega 3):** o domínio novo (`Money`, `PriceReference`,
  `ProductOption`, `Purchase`, `PurchaseItem`, `ListWriteOff`, `planWriteOffs`,
  `PurchaseDraft`), o `purchase_repository` e o `purchase_draft_repository`, os três
  ViewModels (`NewPurchaseViewModel`, `PurchaseDraftViewModel`,
  `PendingPurchaseSubmitter`) e a **Tela 3** — que é também quem abre o `NewStoreDialog`
  da H3 e quem manda a Tela 4 devolver a folha escolhida.
- **H9/H10 — consertar (Entrega 4):** o domínio novo (`undoWriteOffs`/`UndoResult`/
  `RestoredListItem` em `write_off_undo.dart`, `PurchaseSummary`, `catalog_maintenance.dart`
  com `typesCompatibleWith`, `canChangeBaseUnit` e as três exceções de regra), a leitura e
  a correção no `PurchaseRepository` (`fetchPage`, `fetchDetail`, `correct`, `delete`), os
  três métodos novos da lista (`fetchItemsByIds`, `countOpenItemsOfType`,
  `removeOpenItemsOfType`) mais o `expectEcho` público, os **oito** métodos de manutenção
  do `CatalogRepository` e o `StoreRepository.update`, três ViewModels
  (`PurchaseHistoryViewModel`, `EditPurchaseViewModel` — um `family` —,
  `CatalogMaintenanceViewModel`), o `ProductField` **extraído** da Tela 3 e as **três
  telas atrás do `≡`**: o histórico paginado, a correção e a manutenção do cadastro.
- **H11/H12 — para onde foi o dinheiro (Entrega 5):** o domínio novo (`ReportPeriod` com
  `monthOf`/`shiftedByMonths`/`canShiftForward`/`latestSelectableDay`, `PeriodReport` com
  as três agregações e o `percentageInTenthsOf` da H12, e `buildReportSections` com a ordenação
  de três níveis e a regra C2), o `report_repository` (abstract + `_local` + `_remote`), a
  função `report_period(p_from, p_to)`, dois notifiers (`ReportPeriodNotifier` —
  **onde o relógio entra no sistema** — e `ReportViewModel`) e a **Tela 5, aba Resumo**,
  com a `PeriodBar`, o `ReportSummary` e o `ReportDetail`.
- **H13/H14 — o controle do mês (Entrega 6):** o domínio novo (`CapThreshold` com os
  **dois únicos números da regra**, `SpendingCap` com `usagePercent`, `CapAlerts`,
  `MonthCapStatus`, `SpendingCapEvaluation` e a função pura `evaluateSpendingCap` — a
  regra inteira da H13, chamada pelas **quatro portas**; mais `SameDayAlert` e
  `isWithinRepeatWindow`, e o `ReportPeriod.wholeMonth` e o `firstDayOfMonth` que
  nasceram junto), o `spending_cap_repository` (abstract + `_local` + `_remote`), a
  migration com `apply_cap_alerts`, `cap_states`, `save_spending_cap`, `same_day_types` e
  o `drop`+`create` das três funções de escrita, o `SpendingCapViewModel` (um `family`
  por `ReportPeriod`), o `showWarnings` de `ui/core/widgets/`, a **tela de
  Configurações completa** com a `SpendingCapSection`, e a `SpendingCapLine` da Tela 5.
- **H15/H16 — estou pagando caro? (Entrega 7):** o domínio novo
  (`reference_window.dart` com a **janela rolante**, para onde o `threeMonthsBefore` da
  Tela 3 se mudou; `price_increase.dart` com `priceIncreaseThreshold`, `PriceBaseline`,
  `PriceIncrease`, `evaluatePriceIncrease`, `PriceBaselines` e `buildPriceBaselines` —
  a regra inteira da H15, **em inteiros e sem uma divisão em ponto flutuante**;
  `PriceQuote`; e `price_comparison.dart` com `ComparisonScope`, `ComparisonLine`,
  `buildComparison`, `distinctOptionsOf`, `categoryNamesOf` e `buildComparisonGroups`),
  o `ReportRepository.fetchPriceQuotes` (**sem migration nova** — decisão D-q), o
  `PriceComparisonViewModel`, o `PriceIncreaseWarning` da Tela 3, o `ReportSummaryTab`
  extraído de `reports_screen.dart` e a **Tela 5 com a `TabBar`**, cuja segunda aba é o
  `PriceComparisonTab`.
- **H17/H18 — planejar (Entrega 8):** o domínio novo (`closedWindow` em
  `reference_window.dart`, ao lado da rolante e no arquivo que já reservava o lugar dela;
  `type_consumption.dart` com `TypeConsumption`; e `monthly_average.dart` com
  `averageDecimalPlaces`, `averageStepOf`, `roundToAverageStep`, `closedMonthsOfLife`,
  `monthlyAverageAmount`, `MonthlyAverage`, `MonthlyAverageGroup`, `monthlyAverages` e
  `groupAveragesByCategory` — **a regra inteira do requisito 8, em inteiros e sem uma
  divisão em ponto flutuante**), mais o `listStatusLabel` de `ShoppingListItem` e o
  `findOpenItemOfType` de `shopping_list.dart`; o `consumption_repository`
  (abstract + `_local` + `_remote`), a migration `type_consumption(date,date,date,date)`,
  o `MonthlyAverageViewModel` — **um só para as duas telas** —, o `add(quantity:)` e o
  `addMany` do `ShoppingListViewModel`, os **dois modos** do `ItemDialog`
  (`.editing`/`.creating`), a **Tela 2** e a **Tela 6**.
- **Entrega 10 — os percentuais de tipo e de marca (fora das 19 histórias):**
  `spendingShareInTenths` em `period_report.dart` — a aritmética meio-para-cima **em
  inteiros**, o único lugar do projeto onde o `1000` da G-d existe, e para onde a conta
  da H12 se mudou (`percentageOf` virou `percentageInTenthsOf` e **delega**) —, o
  `ReportBrandLine` e o `percentageInTenths` de `ReportTypeLine` e `ReportSection` em
  `report_section.dart`, e o `formatPercent` de `ui/core/formatting.dart`, que é o
  **único** lugar que escreve a vírgula do percentual. As duas visões da Tela 5 passaram
  a desenhar os três números; nada em `data/` foi tocado.
- **H19 — a calculadora de custo proporcional (Entrega 9):** o domínio novo
  (`proportional_cost.dart` com `costTieThreshold`, `contentPricedOf`, `openingPriceOf`,
  `CostCandidates`/`costCandidatesOf`, `CostLine`, `CostRanking`, `rankCosts` e
  `costHeaderFor` — **a regra inteira do requisito 17, em inteiros e sem uma divisão em
  ponto flutuante**) e o `CostComparisonPanel`, o painel `#3a` que a Tela 3 abre pelo
  `[ Comparar custo ]`. **Sem migration, sem repository, sem provider e sem rota**
  (decisões F-a e F-f): o painel abre sobre o `priceReference` que `rankOptions` já
  anexou a cada folha, e nada digitado nele vira registro — o que
  `PurchaseDraftRepositoryLocal.writes` prova em teste.

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

O `.github/workflows/deploy.yml` **já rodou, e passou** — duas vezes em 31/08/2026, nos
dois últimos pushes de `main`: analisa, testa com cobertura (**piso de 90%**, verificado
em script), constrói com os dois `--dart-define` e publica no Cloudflare Pages, e a
publicação é **pulada, não falhada**, quando as credenciais faltam. O remote existe
(`origin`, `leandrorochaadm/shopping_list`, privado) e `main` é a branch padrão.

**Aquelas duas execuções verdes não provam que a publicação funciona, e o motivo é um bug
que só se corrigiu em 31/08:** o `if:` dos dois últimos steps lia `env.CLOUDFLARE_API_TOKEN`,
mas **o `env:` de um step não é visível ao `if:` daquele mesmo step** — a condição é
avaliada antes de o step ser montado. O `if` do publish dava falso para sempre e o do
"nada foi publicado" dava verdadeiro para sempre, o que com o A3 aberto é indistinguível
do comportamento correto. Hoje quem decide é o step `pick the environment`, que **lê o
próprio env** e devolve `publish=yes|no` como output; os dois steps finais leem esse
output. **A lição vale para todo `if:` de step que dependa de secret.**

A regra escrita no arquivo: **`main` aponta para o `prod`, qualquer outra branch publica
um preview contra o `dev`** — e ela está **suspensa desde 31/08/2026**, com a nota dentro
do próprio workflow: não existe `dev` (A1), então os quatro secrets do Supabase carregam
o **mesmo par**, o do `prod`. Enquanto isso valer, **branch nenhuma protege o banco** —
todo build escreve no `prod`, e o que protege é ele estar vazio. Nada no workflow muda
quando o `dev` nascer: os dois secrets `_DEV` deixam de repetir a produção.

O `supabase/` existe com o `config.toml`, **nove migrations** (a função `normalize_name`
`IMMUTABLE`; as 12 tabelas com a função transacional de cadastro; a RLS permissiva com os
`grant`; a view `product_type_purchase_count`; a escrita da compra com `fulfilled_on`,
`removed_on` e `create_purchase`; a correção com `update_purchase`, `delete_purchase` e
o índice do histórico paginado; a `report_period` da Entrega 5; a `spending_cap` da
Entrega 6; e a `type_consumption` da Entrega 8) e o **seed de 4 meses**,
gerado por `uv run tool/make_seed.py` — reancorar é rodar de novo. Todas elas e o seed
foram **aplicados e verificados** no Postgres 17 local (ver o parágrafo seguinte): as
travas de duplicidade, o `NULLS NOT DISTINCT`, a igualdade de embalagem em inteiros, o
rollback das funções transacionais, os **sete casos de `purchase_correction_cases.sql`**,
os **catorze de `period_report_cases.sql`** e os **dezenove de
`spending_cap_cases.sql`** foram exercitados um a um — estes últimos também **pela chave
anon**, contra o PostgREST local, que é o único jeito de um `grant` perdido no `drop` e a
conversão de `uuid[]` aparecerem.
**As nove migrations foram aplicadas em `prod` em 31/08/2026** (`supabase db push --linked`, projeto `shopping_list` · `sxwyundsrbvbmmacgngs`, sa-east-1, PG 17.6.1). **O seed NÃO foi aplicado lá, e não deve ser** — ele é de desenvolvimento. **Não existe projeto `dev`**: a org está no teto de dois projetos ativos do plano Free, e a decisão de 31/08 foi aplicar direto no `prod` enquanto ele não tem histórico real — divergência consciente da decisão 9, a reabrir assim que o `dev` nascer. **Os seis arquivos de `supabase/checks/` rodaram contra o `prod` em 31/08/2026** (`bash tool/checks.sh`, pelo pooler de sessão) e **todos os casos passaram** — os cinco transacionais terminaram em `rollback`, então o `prod` não guardou linha nenhuma deles. Uma ressalva sobre o que isso prova: o `checks.sh` entra por `psql` como `postgres`, que **passa por cima dos `grant`** — ele confere o corpo das funções, nunca o alcance da role `anon`. Essa é a conferência com a chave anon, feita à mão no mesmo dia, e é ela que continua sendo a única que pega um `grant execute` perdido num `drop`.

**O seed ganhou na Entrega 4 o que a H9 e a H10 mostram** e as quatro linhas de lista
originais não cobriam: um item **fechado por compra** com o rastro correspondente (para
a exclusão ter o que devolver), uma **baixa parcial** (o "restam 4 litros" da tela) e
**um cadastro desativado de cada um dos seis** — sem eles o filtro "mostrar desativados"
abre vazio. Os dois rastros apontam para `purchase_item` reais da última compra gerada,
porque uma FK não perdoa e um rastro de outro dia devolveria a quantidade errada.

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

**O MCP do Supabase é a mesma armadilha com outra interface, e por isso a base é o CLI
mais o `curl`** (decisão de 31/08/2026). O `.mcp.json` do repositório declara o servidor
`mcp.supabase.com` apontando para o `project_ref` do `prod`, mas nada do que se aplicou ou
verificou no hospedado passou por ele. A regra é esta:

| | CLI + `curl` | MCP |
|---|---|---|
| O que aplica | `db push` aplica **os arquivos** de `supabase/migrations/` | `apply_migration` recebe SQL do prompt — o arquivo local não nasce dele |
| Reprodutível no CI | é o que o `deploy.yml` roda | não roda em Action nenhuma |
| Por onde entra | `curl` com a **anon key** passa pelos mesmos `grant` e RLS que o app | credencial de plataforma, que **pula** os grants da role `anon` |
| Rastro | comando e saída no terminal, repetíveis à mão | chamada opaca, uma por vez, consumindo contexto |

A terceira linha é a que decide, e o `drop`+`create` da Entrega 6 é o exemplo: um `grant
execute` perdido ali só aparece para quem bate na porta da role `anon` — pelo MCP a
chamada entra por cima e responde 200 com o grant faltando. Foi assim que as **onze
funções** foram conferidas em 31/08, uma a uma, com a chave anon (as cinco de escrita
chamadas com FK inexistente, que falham e sofrem rollback dentro da própria requisição do
PostgREST, sem gravar linha nenhuma).

**Onde o MCP ganha, e vale ligá-lo em somente-leitura:** `execute_sql` roda SQL **sem a
senha do banco**, `get_logs` e `get_advisors` trazem os avisos de segurança e performance
que nem o CLI nem o `curl` mostram, e `search_docs` evita chute de API. Nada disso
escreve — e escrita por MCP em `prod` continua fora, pelo mesmo motivo do dashboard.

**Uma armadilha do `.env` encontrada em 31/08:** `tool/checks.sh` e
`tool/local_dev/run.sh` leem o arquivo com `source`, que é **shell**, não um parser de
`.env`. Uma senha terminada em `;` chega ao `psql` sem o último caractere — o `;` separa
comandos — e o erro que volta é `password authentication failed`, que manda procurar no
lugar errado. **Aspas SIMPLES**, nunca duplas: dentro de aspas duplas o shell continua
expandindo `$` e crase, então elas resolveriam só o `;`. O jeito de ver o corte é comparar
`${#VAR}` depois do `source` com o comprimento da linha crua lida por outra ferramenta.

**Isso não era a causa do bloqueio daquele dia, e o registro erraria se sugerisse que
era:** com os 9 caracteres chegando inteiros, o pooler seguiu respondendo `password
authentication failed` nas duas portas. A senha guardada não era a do projeto, e o que
destrava é o *Reset database password* do painel. O truncamento era um segundo defeito,
que teria mordido depois.

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

**Os `_remote` continuam cobertos por `mocktail` na suíte**, e o que
`test/data/catalog_repository_remote_test.dart` e os seus dois irmãos fixam é o inviolável
que falha em silêncio: **todo método fecha em `rethrowAsKnownFailure`**, e o SQLSTATE
`23505` vira 409 em vez de "status 23505" lido como `>= 500`. Um teste por método.

No `purchase_repository_remote_test.dart` há uma armadilha a mais, e ela custa meia hora:
**`client.rpc` não devolve um `Future`** — devolve um `PostgrestFilterBuilder`, que apenas
*implementa* um. `thenAnswer((_) async => …)` não compila, e o caminho de sucesso precisa
de um dublê cujo `then` seja o que o `await` alcança. Só os casos de FALHA se resolvem com
`thenThrow`.

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

**O app está publicado desde 31/08/2026, em `https://shopping-list-ci3.pages.dev`** — o
projeto Cloudflare Pages `shopping-list`, criado por
`npx wrangler@3 pages project create`, com o `-ci3` **acrescentado pelo Cloudflare** porque
`shopping-list` já existia globalmente. São três caracteres no lugar do "subdomínio não
adivinhável" do `tecnico §9`, aceitos pelo usuário no dia. **Quem tem essa URL tem o banco**
— sem login, RLS permissiva e a chave anônima dentro do `main.dart.js` que o Pages serve —,
então ela é a barreira inteira do sistema, e é por isso que o repositório é privado. A
publicação é do CI: a **A3 está fechada**, os seis secrets e a variável
`CLOUDFLARE_PROJECT_NAME` estão gravados, e **todo push publica**.

**Não existe ainda:** o schema aplicado em `dev` e a S1 medida — não falta mais tela
nenhuma, e o deploy deixou de faltar. O que trava cada um está em
`docs/pendencias-lista-de-compras.md`: **o bloco B está fechado** (as cinco decisões de
28/08 mais a **B6**, que nasceu na H7), a **C1** e a **D3** foram respondidas na H7, a
**C2** na H11, a **C4 (L4)** na H13 — **America/Porto_Velho (UTC−4)**, que fica registrada
e não vira código —, a **A3** foi fechada em 31/08, e o que resta do **bloco A** são as
contas do Supabase (A1) e a medição no iPhone (A2) — esta **agora desbloqueada**, porque
era o HTTPS que ela esperava.

**Nove migrations esperam um banco hospedado.** As cinco últimas são as das Entregas 3,
4, 5, 6 e 8: a `20260828130000_purchase_write.sql` acrescenta `fulfilled_on` e `removed_on` a
`shopping_list_item`, relaxa o `check` de `list_write_off` para `>= 0` e cria a
`create_purchase`; a `20260828140000_purchase_correction.sql` cria o índice
`purchase_history_idx`, as funções `update_purchase` e `delete_purchase` e — **dentro dela
mesma, nunca no `rls.sql` já aplicado** — os dois `grant execute`; a
`20260830120000_period_report.sql` cria a `report_period(date, date)`, que devolve as
**três agregações do mesmo intervalo** num `jsonb` só; e a
`20260830130000_spending_cap.sql` cria as quatro funções do teto e da H14 **e dropa e
recria as três de escrita** com o `p_cap_alerts` novo; e a
`20260830140000_type_consumption.sql` cria a `type_consumption(date, date, date, date)`,
que responde as **duas janelas mais a data da primeira compra** de cada tipo num `jsonb`
só. Todas foram **aplicadas e conferidas** no `shopping_list_dev` local, com os cinco
arquivos de `supabase/checks/`; **`prod` recebeu as nove em 31/08/2026** e o `dev` continua sem existir.

**O `drop`+`create` da Entrega 6 é a coisa mais perigosa que já entrou numa migration
deste projeto, e vale saber por quê.** Parâmetro novo em Postgres é **assinatura nova**:
`create or replace` não a alcança, e criar sem dropar deixaria duas sobrecargas do mesmo
nome — com o PostgREST escolhendo por nome de parâmetro, o que falha **em silêncio**. Daí
as três serem recriadas inteiras, corpo por corpo. E o `drop` leva junto o `grant execute`
e o `comment on function`: os sete grants e os três comentários são refeitos na mesma
migration, e sem eles a role `anon` passaria a levar `42501` — que o `AppFailure` lê como
`AccessDenied` — numa tela que funcionava ontem. Foi por isso que o passo de verificação
chamou as sete funções **pela chave anon**, e não por `psql`.

**Dois arquivos de `supabase/checks/` estavam quebrados desde que nasceram**, e a Entrega
6 os consertou porque precisava rodá-los: `purchase_write_cases.sql` e
`purchase_correction_cases.sql` usavam ids como `…-0000000000t1` e `…-0000000000r1`, que
**não são hexadecimais** — o Postgres recusa o primeiro `insert` com *"sintaxe de entrada
é inválida para tipo uuid"*. Os oito ids afetados viraram `…b1` a `…b8`. Os dois arquivos
passam hoje, e é o que prova que os corpos copiados não perderam uma linha.

Três armadilhas da `report_period` estão escritas dentro dela e vale saber de cor:
**`::bigint` em cada `sum`** (`sum()` sobre `bigint` devolve `numeric`, que no `jsonb`
pode chegar `19200.00`), **`coalesce(…, '[]'::jsonb)` nas três chaves** (`jsonb_agg` de
zero linhas devolve `NULL`, e o período vazio é um estado a desenhar, não um erro) e
**nenhuma ordenação** (quem ordena é `buildReportSections`, em Dart).

**A rota `/spike` e `lib/ui/spike/` são descartáveis:** existem para a medição S1 no
iPhone 12 e são apagadas junto com o teste delas assim que a pendência A2 estiver
respondida (passo 25 do plano).

**A próxima entrega não tem código de feature nenhum:** o que resta são os passos que
dependem de você — publicar, medir a digitação no iPhone 12 (precisa de A1, A2 e A3) e
aplicar as nove migrations no `dev` (precisa de A1). **Não há mais história em aberto:**
a H19 fechou a última, e com ela o requisito 17.

**Um critério de aceite da H7 ficou deliberadamente de fora**, e está registrado para não
sumir: abrir a Tela 3 **a partir de um item da lista**, com a embalagem preferida já
escolhida (falta só a navegação da Tela 1 para a Tela 3, com o item como `extra`). O
outro — o alerta de alta de preço `⚠` — **foi entregue na Entrega 7**.

**Uma decisão tomada ao escrever a Tela 4, e registrada aqui porque muda texto de
usuário:** `Packaging.label` **não escreve o "1 ×" da embalagem de peça única** —
"350 ml", não "1 × 350 ml" —, porque é esse o nome da prateleira que se procura no
lançamento, e é o que o wireframe da Tela 4 desenha. Com duas peças ou mais ele volta:
"12 × 350 ml".

---

## O que a Entrega 8 mudou fora das telas dela

**`pending_destinations.dart` e `under_construction_screen.dart` foram apagados.** O
dartdoc do mapa já dizia que um mapa vazio era o sinal, e as duas últimas entradas eram
justamente as destas telas. Com eles saíram o ramo de SnackBar da `MainBottomBar`, o
`subtitle` e o cinza do `MainMenu`, e o `_PendingButton` da Tela 1 — cujos **dois** usos
(o rodapé e o estado vazio) viraram `OutlinedButton` de verdade. **A ordem importava e
era um crash se invertida**, a mesma armadilha da Entrega 4: o `_PendingButton` lia o
mapa com `!`.

**O `ItemDialog` ganhou dois construtores, e o de screen 1 não mudou de assinatura.**
`ItemDialog.editing` é a Tela 1 e o caminho "já está na lista" da Tela 6;
`ItemDialog.creating` é a Tela 6 num tipo que ainda não está na lista, e nele **"Não
encontrei" e "Remover da lista" não existem** — não há linha para marcar nem para
remover. O `ItemDialog.show(context, item)` continua igual de propósito, para os
chamadores da Tela 1 não se mexerem. Onze pontos do `State` liam `widget.item`; hoje leem
`widget.type`/`widget.category`, ou `widget.item!` dentro de um ramo já guardado.

**Decisão E-k, registrada porque é um campo que aceita e não grava:** no modo criar os
dois dropdowns de marca e embalagem **aparecem** — esconder divergiria do "o **mesmo**
diálogo de item da Tela 1" que o wireframe manda — e o que for escolhido neles é
**descartado**, porque `ShoppingListViewModel.add` monta o item sem preferências. A volta
são dois nomeados opcionais em `add`, e o `item_dialog_test` fixa o comportamento atual
para que o dia em que isso mudar, mude de propósito.

**`ShoppingListViewModel.add` ganhou `quantity`, e nasceu o `addMany`.** O segundo existe
porque o primeiro **não pode ser chamado em laço**: a guarda de reentrância da regra 14
engoliria toda chamada depois da primeira e devolveria `null`, que se lê como sucesso. A
guarda é **da ação**, e acrescentar cinco itens é uma ação. Numa falha no meio ele para e
devolve a frase, mantendo o que já entrou — e a tela não precisa de contador: as linhas
que passaram voltam travadas por lerem a lista.

**Os dois fakes passaram a contar a mesma história** (decisão E-l).
`ConsumptionRepositoryLocal` guarda as **mesmas compras** de `ReportRepositoryLocal`, mês
a mês e sem preço, e por isso o fake do relatório cresceu **oito linhas** — março, maio,
junho e uma de julho. Sem isso a Tela 5 diria "Acém moído 6 kg em agosto" e a Tela 6
diria "faltam 2 kg de uma média de 6", duas respostas sobre o mesmo tipo no mesmo mês, em
debug. **A sincronia é manual e nenhum teste a defende**: o dartdoc de cada fake aponta
para o outro pelo nome. Custou **um `expect`** — o total de julho, que passou de
`Money(11990)` para `Money(27990)`.

**O catálogo fake ganhou `cat-4 Mercearia` e `type-5 Café`**, exatamente como a Entrega 5
ganhou `type-4` e `brand-4` e pelo mesmo motivo: sem eles a sugestão nomearia, em debug,
um tipo que a Tela 3 não oferece. O custo foram **quatro contagens** em
`catalog_maintenance_view_model_test.dart`.

**O `router_test` perdeu um dos seus dois mapas.** `placeholderTitleByPath` esvaziou e
suas duas entradas migraram para `realTitleByPath`, cujo comprimento passou a ser sozinho
o **onze** que `tecnico §3.4` congelou. E o `main_menu_test` perdeu os três casos que
perguntavam `isPending`: o que os substitui é a propriedade que sobreviveu ao mapa — cada
uma das três portas alcança uma tela.

---

## O que a Entrega 7 mudou fora das telas dela

**`threeMonthsBefore` deixou de morar num ViewModel.** Ela é `rollingWindowStart`, em
`domain/models/reference_window.dart`, e o motivo é o import cruzado: a H16 mora em
`ui/report/` e chamá-la de lá seria importar `ui/purchase/` por causa de uma regra de
negócio (**D-r**). O arquivo já nasce com o dartdoc das **duas** janelas escrito, e é ali
que a fechada da H17 vai nascer — o único jeito de as duas nunca serem escritas em telas
diferentes. O grupo de teste dela mudou de arquivo junto, para
`test/domain/reference_window_test.dart`.

**`PurchaseHistoryEntry` ganhou o `productTypeId`, e ele NÃO vem do catálogo.** Vem do
embed `product!inner ( product_registration!inner ( product_type_id ) )` de
`fetchRecentItems`, **sem filtro de `active`** — porque `fetchProductOptions` filtra
`active = true`, e uma folha desativada no meio da janela tiraria as compras dela da média
do tipo. `requisitos §16` promete o contrário: desativar não reescreve o passado. A
entidade também passou a `implements PurchaseBaselineLine`, que é a interface do domínio
por onde `buildPriceBaselines` a lê sem o domínio importar `data/`.

**`ProductGroup.type` virou `ProductGroup.header`, e `ProductField` ganhou dois
parâmetros** (`groupBy` e `fieldKey`). O mesmo seletor agrupa por **tipo** na Tela 3
(decisão C1, mais comprado primeiro) e por **categoria** na aba de comparação
(alfabético) — são perguntas diferentes, e dois widgets divergiriam na primeira mudança
(**D-u**). O `fieldKey` existe porque as duas abas coexistem na árvore do `TabBarView`:
sem ele, `find.byKey('field-product')` acha dois.

**O corpo de `reports_screen.dart` inteiro mudou de casa.** Ele é `ReportSummaryTab`
agora, e levou junto a `PeriodBar`, os cinco estados e **a linha do teto da H13** — o
`ref.watch` condicional do `spendingCapViewModelProvider` e o `capLine:` que ele
alimenta. É o lugar certo dos dois de qualquer jeito: o teto só existe em período de mês
inteiro, e o período é conceito da aba Resumo, não da tela. O que sobrou em
`reports_screen.dart` é a casca — `TabController` no `State` (**não**
`DefaultTabController`: o `↻` do `AppBar` precisa saber qual aba está na frente, e o
`Default` só entrega o controlador a um descendente), `TabBar`, `TabBarView` e a
`MainBottomBar`.

**O campo Valor da Tela 3 passou a repintar.** Ele fazia `onChanged: (_) => _valueTouched
= true;` **sem `setState`**, de propósito, porque nada na tela dependia do que estava
escrito ali. Agora depende: o ⚠ da H15 sai do valor digitado, e sem repintar ele só
apareceria no próximo toque de outro campo.

**O `ReportRepositoryLocal` ganhou um segundo seed**, de cotações, sobre as **mesmas
folhas de `CatalogRepositoryLocal` e os mesmos mercados de `StoreRepositoryLocal`** — dois
fakes contando histórias diferentes fariam a Tela 3 e a Tela 5 discordarem em debug por um
motivo que é só do fake. A Mercearia do Zé entra **desativada**, que é como ela está no
fake dos mercados: `Store.fromJson` faz `json['active'] as bool? ?? true`, então o `select`
da H16 pede `id, name, active` — sem essa coluna a mesma loja voltaria com um `==`
diferente do banco e do fake, e nenhum teste acusaria, porque a tela só escreve o nome.

**O `_seedHistory` de `PurchaseRepositoryLocal` não mudou de valores**, só ganhou o
`productTypeId`. As duas compras de `prod-4` (R$ 62,00 e R$ 59,90 por 4200 ml) dão uma
média de **R$ 14,51/L**, então digitar `1` fardo por `R$ 70,00` na Tela 3 responde
*"Subiu 15% sobre a média"* em debug. Mexer nos valores para forçar o "18%" do wireframe
quebraria o pré-preenchimento de R$ 62,00 que dois arquivos de teste fixam.

---

## O que a Entrega 6 mudou fora das telas dela

**`/settings` deixou de ser a tela mínima da H1.** Ela ganhou a `SpendingCapSection`
acima da etiqueta, um `RefreshIndicator` sobre um `ListView` que existe em **todos** os
estados — o *loading* e o erro das duas seções vivem **dentro** dele —, e um `_today`
calculado uma vez no campo, que é o que impede o `family` do teto de reler o mês a cada
frame. O teste dela nasceu junto (`test/ui/settings_screen_test.dart`, 13 casos); os três
casos da etiqueta ficaram onde estavam, em `device_user_screens_test.dart`.

**`EditPurchaseViewModel.save` e `.delete` mudaram de forma, e a regra 16 é o motivo.**
Eram `Future<String?>` enquanto uma correção tinha dois desfechos sem carga; a H13 dá
carga ao sucesso — o aviso de teto que ela pode disparar —, então viraram o `sealed
CorrectionOutcome`. Junto com isso, o `'Aguarde a compra carregar.'` deixou de ser um
`String?` de erro e virou `CorrectionFailed`: o `null` ficou **reservado à guarda de
reentrância**, que é o único caso em que nada aconteceu.

**Os fakes ganharam um interruptor, e ele é de teste, não de produção.**
`PurchaseRepositoryLocal.sameDayBuyer` é **nulo por padrão** e responde nada; quem o liga
é o `overridesLocal` de `config/dependencies.dart`, com `'esposa'`. E o
`spendingCapOverride()` de `test/helpers/` monta o fake **sem gasto nenhum no mês**,
enquanto o de debug semeia os R$ 1.300 da história do requisito 9. Sem as duas coisas,
cada um dos ~10 testes que apenas salvam uma compra passaria a receber um diálogo de uma
história que não é a deles — e o diálogo **bloqueia a navegação**, então eles falhariam
por um motivo que não é o que testam.

**`purchaseOverrides()` passou de três overrides para quatro**, e há **seis** pontos de
override no projeto, não um: `new_purchase_view_model_test`,
`pending_purchase_submitter_test` (**dois blocos**), `new_purchase_screen_test`,
`edit_purchase_view_model_test` e `device_user_screens_test` montam a própria lista. O
`spendingCapRepositoryProvider` nasce lançando `UnimplementedError`, então um ponto
esquecido é uma parede de falhas que não são dele.

---

## O que a Entrega 4 mudou fora das telas dela

**O `≡` perdeu uma entrada e o mapa perdeu quatro.** `pendingDestinations` ficou com
`suggestions`, `reports` e `remainingThisMonth`; saíram as três desta entrega e o
`newPurchase`, que a Entrega 3 esqueceu. (**Hoje são duas** — a Entrega 5 tirou o
`reports`; esta seção é o registro daquele momento.) **A ordem importa e é um crash se invertida:** o
`_PendingButton` da Tela 1 lê o mapa com `!` (`shopping_list_screen.dart`), então o
`[ Lançar compra ]` virou um botão de verdade **antes** de a entrada sair. "Corrigir
compra" saiu do menu em vez de ficar habilitada — `/purchases/:id/edit` não navega sem um
id, e quem sabe o id é o histórico, uma linha acima.

**O `[ Reativar ]` deixou de exigir uma viagem até `/catalog`** (decisão de 29/08/2026).
A frase do conflito desativado perdeu o destino — é só *"O cadastro X existe, mas está
desativado."* — e o botão aparece no próprio diálogo, nas **quatro** portas da Tela 4 e
no `NewStoreDialog` da Tela 3. O `SingleFieldDialog` ganhou quatro parâmetros para isso
(`footnote`, `leadingActions`, `findReactivable`, `onReactivate`), e o
`NewProductTypeDialog` — que tem três campos e não usa o shell — escreve o mesmo botão à
mão. Um `grep` por "manutenção do cadastro" em `lib/` não devolve nada.

**O campo Produto saiu da Tela 3 para `ui/purchase/widgets/product_field.dart`**, porque
a correção precisa do mesmo. Ele **não recebe `ref`**: quem o monta já tem as opções na
mão, e é isso que deixa o teste dos dois lados sem container. O caso da busca com
`"coca"`/`"COCA"`/`"cocá"`/`"269"` migrou junto, para `product_field_test.dart`.

**Um bug encontrado ao escrever o teste do `CatalogMaintenanceViewModel`, e vale a
regra:** as quatro escritas de nome faziam `return _writeCategory(...)` **sem `await`**
dentro do `try`. A exceção escapava do `catch` — subia crua para a tela em vez de virar
frase — e o `finally` liberava `_running` antes de a escrita terminar, então o toque duplo
disparava duas requisições. `return await` nos dez pontos resolveu. **`return future;`
dentro de um `try` é `try` nenhum.**

---

## O que a Entrega 5 mudou fora da Tela 5

**O `≡` e o `👤` saíram de `ui/shopping_list/`**, porque o wireframe desenha os dois no
cabeçalho da Tela 5 e a alternativa era uma segunda cópia deles. Foram para lugares
**diferentes**, e a diferença é a regra: `ShoppingListMenu` virou
`ui/core/widgets/main_menu.dart` — `MainMenu` —, que é onde `MainBottomBar` já morava pelo
mesmo motivo; mas o `_askWhoIsUsing` privado da Tela 1 virou
`ui/device_user/widgets/who_is_using_dialog.dart`, e **não** `ui/core/`, porque ele precisa
do `deviceUserViewModelProvider`: nenhum arquivo de `ui/core/widgets/` importa pasta de
feature hoje, e pôr o diálogo ali inverteria a dependência.

**O catálogo fake cresceu um tipo e uma marca** — `type-4` "Sabão em pó" (Limpeza,
`kilogram`) e `brand-4` "Tixan" —, em `catalog_repository_local.dart` e em
`test/helpers/purchase.dart`. Sem eles a fixture do relatório não conta a história escrita
do requisito 4 (6,8 kg somando Omo e Tixan), e inventá-los só dentro do
`ReportRepositoryLocal` faria a Tela 5 nomear, em debug, um tipo que a Tela 3 não oferece.
O custo foi um teste: `catalog_maintenance_view_model_test.dart` conta os cadastros, e os
dois `hasLength(3)` viraram `hasLength(4)`.

**`Routes.reports` saiu do `pendingDestinations`, e a barra de baixo passou a navegar.**
Isso quebrou o teste que afirmava a frase `'Os relatórios chegam na H11.'` — e o
substituto **exige um `GoRouter` na árvore**: o `pumpBar` daquele arquivo monta um
`MaterialApp` sem router, e um destino entregue chama `context.go`, que sem router lança.
A metade que não precisa de router continua valendo sozinha: o ícone deixou de estar em
`disabledColor` e o `tooltip` voltou a ser o rótulo.

**Uma armadilha de teste que "Relatórios" estreou:** ele é ao mesmo tempo o **título da
tela** e o **rótulo do destino na barra**, então há dois `Text('Relatórios')` na mesma
árvore e todo `find.text` sobre ele devolve **dois**. A Tela 1 escapava disso por acidente
— título "Lista de compras", rótulo "Lista". O conserto não é afrouxar para
`findsWidgets`, que deixaria de pegar um título errado: é afirmar onde o título mora
(`find.descendant(of: find.byType(AppBar), …)`) ou pelo widget da tela. A H18 volta a
pisar nisso — "Falta comprar este mês" no título, "Falta" no rótulo.

**Um bug de tela que o teste do `PeriodBar` encontrou, e que o plano não previa:** a
decisão **D-d** guardava só a ponta `from`. Mas o relatório abre no **mês inteiro em
curso**, cujo `to` é 31/08 com um "hoje" de 15/08 — então o segundo campo de data abria com
`initialDate` **depois** do `lastDate` e disparava o assert
`!initialDate.isAfter(lastDate)` de `showDatePicker`. A correção é a outra ponta da mesma
regra, e mora no domínio: **`ReportPeriod.latestSelectableDay(today)` é o fim do mês em
curso**, não "hoje". `canShiftForward` impede o período de sair deste mês; ela torna todo
dia **dentro** dele alcançável.

---

## As armadilhas que a H7 revelou, e uma que a H9 acrescentou

**0. `await` numa chamada de fake ANTES do primeiro `pump` trava o teste por dez
minutos.** É a outra face da armadilha do relógio falso registrada no fim desta seção:
`CatalogRepositoryLocal.updateCategory` faz `Future.delayed(latency)`, e com o relógio
parado ele nunca completa. Preparar um cenário ("esta categoria nasce desativada") **não
se faz chamando o fake**: faz-se com uma subclasse que sobrescreve a LEITURA — é o
`_WithDeactivated` de `new_product_screen_test.dart`. O sintoma é um teste que não falha,
só nunca termina.


**1. O item do rascunho carrega a folha INTEIRA, não o id dela.** `PurchaseItem` guarda o
`ProductOption` completo, e o `toDraftJson` o serializa junto. O motivo é o critério de
aceite da H8: um rascunho recuperado em modo avião tem de **desenhar e reabrir as suas
linhas sem rede nenhuma**, e um id exigiria procurar o produto num catálogo que nunca
carregou. É também o que faz o reenvio automático funcionar com a Tela 3 nunca aberta — o
tipo de cada item já está na mão, então a baixa da lista não depende do catálogo.

**2. "Rascunho recuperado" é uma pergunta sobre a SESSÃO, não sobre a compra.** Ela não
cabe na entidade: o mesmo rascunho gravado tem de ser lido como *"nasceu agora"* pela
sessão que o escreveu e como *"recuperado"* pela seguinte. E não pode ser recalculada do
Hive, porque depois da primeira linha digitada **sempre** há um rascunho lá. Por isso são
duas peças: `recoveredDraftProvider`, respondido uma vez na primeira `build()` do
`PurchaseDraftViewModel` e **consumido** quando a compra é salva ou descartada; e
`PurchaseDraft.bannerDismissed`, **persistido**, porque o ViewModel é recriado toda vez
que a etiqueta do aparelho muda e uma dispensa que vivesse na memória traria a faixa de
volta junto.

**3. `MessageView` dentro de um `ListView` estourava.** O widget mede
`constraints.maxHeight` para preencher a viewport, e um `ListView` entrega altura
**infinita** aos filhos — `BoxConstraints forces an infinite height`. Ele agora detecta o
caso e devolve só o texto: já está dentro de um rolável, e um segundo
`SingleChildScrollView` ali engoliria o pull-to-refresh de fora, que é a razão de ele
existir.

**E uma do `flutter_test`, que trava por dez minutos em vez de falhar:** dentro de
`testWidgets` o relógio é falso, então o `Future.delayed(Duration.zero)` da latência dos
fakes **só dispara quando um frame é bombeado COM duração**. `await repository.add(...)`
antes de um `pump` é um deadlock; `await tester.pump()` sem duração não resolve — precisa
ser `pump(const Duration(milliseconds: 1))`.
