# Estado atual do projeto

Recortado do `CLAUDE.md` em 03/09/2026, palavra por palavra. **Atualizar a cada entrega.**

**Atualizado em 07/09/2026**, ao fim da Entrega 14
(`temp/plan/plano-unidade-base-tamanho-2026-09-07.md`) — **acréscimo fora das 19
histórias**, pedido pelo usuário em 07/09/2026: **as unidades base passaram de três para
quatro, e cada uma virou a unidade pequena e inteira da sua grandeza** — `gram` (g),
`milliliter` (ml), `unit` (un) e a nova `centimeter` (cm), que é o que faltava para
cadastrar papel-alumínio, filme plástico e barbante. O enum `MeasureUnit` foi **apagado**,
e com ele o seletor "g ou kg?" da Tela 4 e do diálogo de embalagem: a grandeza do tipo já
responde isso. `Packaging.pieceSizeUnit` virou `Packaging.baseUnit` (a chave JSON e a
coluna continuam `piece_size_unit`), `smallestUnits` virou `unitsPerLargeUnit` — **o mesmo
número, e nenhum preço mudou** — e o enum ganhou `priceLabel`, `typedText`,
`magnitudeLabel`, `formatQuantityPair` e `usesLargeUnit`, com `_formatAmount`,
`_largeLabel` e `_largeDecimalPlaces` **privados**, para o compilador impedir uma tela de
escolher entre 'kg' e 'g'. **Todo campo de quantidade e de conteúdo passou a `digitsOnly`**
(os de valor pago continuam decimais), `AmountTooPrecise` virou `AmountMustBeWhole`, e a
leitura ficou **adaptativa**: `900 g`, `1,5 kg`, `1,25 L`, `30 m`. `SellingChoice` ganhou
`length` ("Tamanho") e o `SegmentedButton` do campo **Vendido** passou a montar **só as
palavras da grandeza** — quatro segmentos espremem o rótulo para 35 pt nos 390 pt do
iPhone 12. Uma migration nova (`20260907120000_base_unit_centimeter.sql`) converte os
rótulos gravados e amplia os dois `check`; **nenhum inteiro gravado mudou**. Decisão
congelada **26** e divergências **J-a** a **J-e** registradas.

Antes dela veio a Entrega 13
(`temp/plan/plano-conteudo-digitado-comparar-custo-2026-09-07.md`) — **acréscimo fora das
19 histórias**, pedido pelo usuário em 07/09/2026: o painel `#3a` dividia o preço digitado
por um conteúdo que **só vinha do cadastro**, e por isso a bandeja de frango de 800 g não
tinha como ser confrontada com a de 1 kg — as duas são a **mesma folha** vendida a peso.
A linha **sem embalagem cadastrada**, e só ela, ganhou um **campo de quantidade** ao lado
do preço, que abre em `1 kg` / `1 L` / `1 un` e recalcula custo, `★`, `−%` e rodapé
**enquanto se digita**. **Apagar o campo deixa a linha esperando** — nunca volta a valer
1 kg em silêncio, que seria um custo plausível e errado. No domínio nasceu
`acceptsTypedContentOf` (**o único lugar** que responde quem tem campo),
`contentPricedOf` ganhou `typedContent:`, `CostLine` ganhou o getter
`acceptsTypedContent` (getter, não campo: o `==` não muda) e `rankCosts` passou a receber
`contents: IMap<String, int?>`, onde **`null` é resposta e a ausência da chave é outra
coisa**. No painel, `_controllers` virou `_priceControllers` e ganhou o irmão
`_contentControllers`, criado só para quem o domínio deixa digitar. **Sem migration, sem
repository, sem provider e sem rota**, e **nada digitado sai do painel**: `[ Usar… ]`
continua devolvendo só a folha. Decisões **F-m** e **F-n** registradas.

Antes dela veio a Entrega 12
(`temp/plan/plano-campos-no-topo-iphone-2026-09-04.md`) — **acréscimo fora das 19
histórias**, pedido pelo usuário em 04/09/2026: o alvo é um PWA instalado num **iPhone
12, 390 × 844 pontos**, e com o teclado aberto sobram cerca de 500. A regra nova de
`.claude/rules/ui-conventions.md` — **todo campo digitável fica no topo**, antes de
lista, resumo, total ou botão — foi aplicada onde três telas não a cumpriam. **A Tela 3
foi a maior:** "Itens desta compra" saiu de entre o Mercado e o Produto e desceu para
depois do `[ + Adicionar à compra ]`; era ela que empurrava Produto, Quantidade e Valor
para baixo a cada item lançado. **Na Tela 4**, as embalagens **já cadastradas** desceram
para depois das linhas editáveis e do `[ + Adicionar embalagem ]` — estado que só o
caminho da manutenção (`registrationId`) enxerga. **O `SingleFieldDialog` ganhou
`SingleChildScrollView`**, e com ele os três diálogos de um campo só (categoria, marca,
mercado): era o único dos sete diálogos do app sem rolagem. **Sem migration, sem
repository, sem provider, sem rota e sem domínio** — é reordenação de widget, documento e
teste. O wireframe subiu para a **versão 2.1**, com a subseção "O tamanho da tela" nas
Convenções de notação, o quadro da Tela 3 redesenhado e as **duas exceções** declaradas:
o campo dentro de linha repetível e a frase que explica o campo vazio.

**Duas coisas do plano NÃO foram feitas, e por decisão:** a seção do teto de gasto ficou
como estava — a frase acima do campo é a **explicação do campo vazio**, e abaixo dele
seria legenda órfã (exceção registrada na regra) —, e o `Scrollable.ensureVisible` do
painel `#3a` não entrou porque o achado que o motivava **não se reproduz**: o painel já
se levanta pelo `viewInsets`, e nenhuma linha dele cai sob o teclado. O que entrou no
lugar foi o **teste** que prova isso, e que falha se aquele `padding` for removido.

Antes dela veio a Entrega 11
(`temp/plan/plano-porta-lancar-compra-no-menu-2026-09-01.md`, os 6 passos) — **acréscimo
fora das 19 histórias**, pedido pelo usuário em 01/09/2026: *"quero lançar uma compra, sem
precisar ter o produto na lista de compras"*. **Lançar compra nunca exigiu o produto na
lista** — `fetchProductOptions` traz o catálogo inteiro e `planWriteOffs` só dá baixa no
que por acaso estiver lá. O que faltava era a **porta**: `/purchases/new` só era alcançável
pelo botão do rodapé da Tela 1, então lançar obrigava a passar pela tela da lista. A única
mudança de produção é a **quarta entrada de `MainMenu._entries`**, na primeira posição, que
chega de uma vez às três telas que montam o `≡` — Telas 1, 5 e 6. A **barra de baixo
continua com três destinos** (decisão **I-a**) e continuam **onze** telas: nenhuma rota
nasceu. Sem migration, sem repository, sem provider, sem rota e sem domínio. Os testes
crescem **dois** casos: a **ordem** das quatro portas em `main_menu_test.dart`, que é a
decisão I-a virando teste, e o `≡` da Tela 6 em `remaining_screen_test.dart`, que nunca
tinha prova de fora. A armadilha desta entrega mora na Tela 1, que com o menu aberto
escreve "Lançar compra" **duas** vezes — o `OutlinedButton` do rodapé e o `ListTile` do
menu —, e a desambiguação é `find.widgetWithText(ListTile, …)`, nunca um `findsWidgets`
que o rodapé sozinho satisfaria. E o conjunto de verificação **não** é
`grep -rl 'MainMenu' test/`, que devolve um arquivo só: os dois testes que a entrega
quebra abrem o menu por `find.byTooltip('Menu')`. O padrão que fecha o conjunto é
`grep -rlE "MainMenu|byTooltip\('Menu'\)" test/`, e ele devolve quatro.

Antes dela veio a Entrega 10
(`temp/plan/plano-percentuais-tipo-e-marca-2026-08-31.md`, os 14 passos).
Ao fim dela, `flutter analyze` limpo, **1387 testes verdes**, cobertura de linha **94,1%** — acima do
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
escrita — as **regras 16 e 17** e a seção "A corrente da igualdade" (`.claude/rules/equality-chain.md`) —, os **15
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
  `PurchaseDraftRepositoryLocal.writes` prova em teste. **A Entrega 13 acrescentou a esse
  domínio o `acceptsTypedContentOf`, o `typedContent:` de `contentPricedOf`, o getter
  `CostLine.acceptsTypedContent` e o `contents` de `rankCosts` — o campo de quantidade da
  linha vendida a peso (F-m/F-n).**

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

**O banco local de desenvolvimento é o `postgresql@17` nativo do sistema, não o stack
Docker do Supabase** (decisão de 28/08/2026). É escolha, não limitação: o Docker Desktop
está instalado e funciona. A máquina de então era um Mac Intel i3-8100B de 4 núcleos com
~20 GB de disco livres, o `supabase start` sobe ~10 containers dentro de uma VM, e nada
do trabalho de schema em curso distingue Postgres em container de Postgres nativo.

**A máquina de desenvolvimento passou para Debian 13 (trixie) em 07/09/2026**, e a
decisão acima não mudou — o que mudou foi de onde os binários vêm. Os scripts de
`tool/local_dev/` não assumem mais o Homebrew: `setup.py` e `up.sh` escolhem a frase
("`brew services`", "`systemctl`" ou "`service`") a partir da máquina onde estão
rodando, porque um comando que nomeia o gerenciador de pacotes errado manda o leitor
procurar um `brew` que não existe ali.

| Peça | macOS | Debian 13 |
|---|---|---|
| Postgres 17 | `brew install postgresql@17` | `sudo apt install postgresql-17` |
| Subir o serviço | `brew services start postgresql@17` | `sudo systemctl start postgresql` |
| Caddy | `brew install caddy` | `sudo apt install caddy` |
| PostgREST | `brew install postgrest` | **não está no apt** — o binário estático `postgrest-v16.2-linux-static-x86-64.tar.xz` das releases do GitHub, descompactado em `~/.local/bin` |

O PostgREST do GitHub é a **16.2**, a mesma que o Homebrew instalava — então a ressalva
sobre versão divergente do formato de erro continua valendo igual, nem mais nem menos.

E duas armadilhas que só aparecem no Debian, as duas já corrigidas nas configs geradas:

- **`db-uri` precisa da senha.** O cluster do Homebrew confia em conexão TCP local; o
  do Debian pede `scram-sha-256`, e o PostgREST morre com `fe_sendauth: no password
  supplied` — que parece falta de configuração e é só a senha que o `bootstrap.sql` já
  dá ao `authenticator`. O host também virou `127.0.0.1`: `localhost` resolve para `::1`
  primeiro, que é outra linha do `pg_hba` e outra falha na mesma máquina.
- **O Caddyfile desliga a API de administração** (`admin off`). O pacote do apt deixa um
  `caddy` de serviço rodando, e ele segura a porta padrão 2019 — sem isso o segundo
  `caddy` recusa a subir com `address already in use`, num erro que não tem nada a ver
  com a porta 54321 que se estava tentando usar.

E há um passo que **só o Debian pede, uma vez por máquina**: o pacote do apt inicializa
o cluster como a role `postgres`, enquanto o Homebrew o inicializa como o próprio
desenvolvedor. Sem uma role com o nome do usuário do sistema, todo `psql` e todo
`createdb` do `setup.py` morre com `FATAL: role "<usuário>" does not exist`, que não
diz qual é a correção de uma linha:

```bash
sudo -u postgres createuser --superuser "$USER"
```

O `setup.py` passou a conferir isso logo depois do `pg_isready` e a imprimir esse
comando — pela mesma razão de já conferir se o servidor está de pé.

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
que o `supabase_flutter` monta para a raiz onde o PostgREST serve. Ambos nativos, sem
container.

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
  de subir o serviço **daquela máquina**, em vez de um traceback de `subprocess.py`. O
  `up.sh` faz o mesmo, e ainda confere se `postgrest` e `caddy` existem: sem isso o
  `command not found` acontece dentro de um job em segundo plano, e o que chega ao
  terminal é um código de saída sem frase nenhuma.
- `tool/local_dev/bootstrap.sql` existe porque as migrations assumem um projeto
  Supabase: o schema `extensions` (com `usage` para as roles), as roles `anon`,
  `authenticated` e `service_role`, o `authenticator` que o PostgREST usa para o
  `SET ROLE`, e a publication `supabase_realtime`. Um banco de `createdb` não tem
  nada disso.

**O que este ambiente não cobre: Realtime.** É uma app Elixir sem binário nativo, então
a H5 continua precisando do projeto hospedado ou do Docker. E o PostgREST instalado
localmente era o 16.2, que não é necessariamente a versão que o Supabase roda — o formato de erro pode
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
