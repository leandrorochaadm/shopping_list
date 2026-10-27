---
name: glossary
description: O glossário pt-BR → inglês da linguagem ubíqua do projeto — obrigatório e acumulativo
quando-ler: OBRIGATÓRIO antes de traduzir qualquer termo novo de negócio; acrescente o termo depois de escolher
---

# Glossário pt-BR → inglês

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
| medida da peça | `pieceSize` | inteiro na unidade base do tipo. Uma forma só — a digitada É a gravada |
| conteúdo total | `totalContent` | na unidade base. **Calculado, nunca digitado** |
| unidade base | `BaseUnit` | enum: `gram`, `milliliter`, `unit`, `centimeter`. É a unidade **pequena e inteira** de cada grandeza, e a única — não existe mais escolher entre "g" e "kg" |
| grandeza | `magnitude` | Peso, Volume, Contagem e **Tamanho**. Uma por `BaseUnit`, e é o que o cadastro do tipo escolhe |
| unidade de leitura e de preço | `priceLabel` / `unitsPerLargeUnit` | `kg`, `L`, `un`, `m`. O preço é sempre nela; a quantidade só sobe para ela quando alcança o fator |
| vendido a peso / por peça | `SellingMode.byWeight` / `.byPiece` | decide o que o lançamento pergunta |
| as quatro palavras do campo **Vendido** | `SellingChoice` | `Peso`, `Unidade`, `Volume` e `Tamanho`. Peso, Volume e Tamanho são o **mesmo** `by_weight`, e quem os separa é a unidade base do tipo. O único lugar onde o par (`SellingMode`, `BaseUnit`) vira UMA escolha. O campo oferece **só as palavras da grandeza** — as quatro não cabem nos 390 pt do iPhone 12 |
| valor por kg (o da etiqueta) | `pricePerLargeUnit` | o preço de UMA unidade de leitura, DIGITÁVEL na Tela 3. `pricePerLargeUnitOf` e `paidAtPricePerLargeUnit` são os dois sentidos da conversão com o valor total pago; o campo só existe no vendido a peso |
| quem foi digitado por último | `PriceSource` | `none`/`total`/`unitPrice`. Diz qual dos dois campos de dinheiro da Tela 3 é a FONTE, e por consequência qual dos dois a quantidade recalcula |
| custo proporcional / preço por unidade base | `costPerBaseUnit` | preço ÷ conteúdo total |
| melhor custo | `bestCost` | o menor `costPerBaseUnit`, não o menor preço |
| mercado | `Store` | supermercado, feira, açougue, hortifrúti |
| lista de compras | `ShoppingList` / `ShoppingListItem` | o item guarda a **data em que entrou** |
| preferência da lista | `listPreference` | era marca + embalagem. Desde a **M-a** é o **produto** pedido (`preferredRegistration`), e ele **manda na baixa** |
| produto pedido pela linha | `preferredRegistration` / `preferredRegistrationBrand` | o cadastro (tipo + marca + descrição) que a linha pede, mais a marca dele para o rótulo. **A embalagem não entra** |
| a linha aceita esta compra? | `acceptsRegistration` | a pergunta que `planWriteOffs` faz à linha. Sem produto efetivo, aceita qualquer cadastro do tipo |
| rótulo de um cadastro | `labelWith` | `Italac integral`, `Italac`, `integral` ou `Sem marca`. Recebe a `Brand`, que o cadastro só guarda por id |
| produtos já pedidos de um tipo | `takenRegistrationsOfType` | o que o diálogo desabilita. **`null` no conjunto é "Qualquer um"**, que também ocupa vaga |
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
| o que se pede à Tela 4 | `NewProductRequest` | `returnsSelection` (Tela 3), `registrationId` (manutenção) e `initialBarcode` (código lido que ninguém tem). Era um `bool` até a H10 |
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
| passo do arredondamento | `averageStepOf` / `roundToAverageStep` | uma casa decimal da unidade de **leitura** — 100 g, 100 ml, 1 un, 10 cm. **Nunca transforma positivo em zero** |
| a sub-linha da Tela 6 | `listStatusLabel` | as quatro formas de "o que a lista está pedindo", mais o sufixo do "não encontrei" |
| o item aberto de um tipo | `findOpenItemOfType` | o mais antigo quando há mais de um. É onde "editando o item que já existe, nunca criando um segundo" é decidido |
| calculadora de custo proporcional | `proportional_cost.dart` | o painel `#3a`. **Não** `CostCalculator`: o que existe é a regra, e ela não é um objeto que calcula |
| linha da calculadora | `CostLine` | folha + marcada + preço + custo + diferença + `★`. **Não confundir com `ComparisonLine`**, que é a linha de MERCADO da H16 |
| as duas listas do painel | `CostCandidates` | o recorte da janela **mais a folha em lançamento e as folhas lidas** (`shown`) e o tipo inteiro (`all`). `canCompare` é a regra do botão da Tela 3 |
| a folha que está sendo lançada | `launching` | o parâmetro de `costCandidatesOf` e do painel. Abre marcada e entra em `shown` sem preço (F-j) — e, desde a M-e, a folha **lida** pelo `[ ▥ Ler outro ]` também (`CostCandidates.withShown`) |
| resposta da calculadora | `CostRanking` | as linhas ordenadas, o `★`, para onde o `[ Adicionar … à compra ]` aponta (M-e: a linha tocada, `pickedId`, quando ela concorre; senão o `★`) e a frase do rodapé |
| empate técnico | `costTieThreshold` | 1%. `const` no domínio, e **o único lugar onde o número existe** |
| conteúdo que um preço compra | `contentPricedOf` | o `totalContent` da embalagem, ou **uma unidade de preço** (1000 g, 100 cm) no vendido a peso |
| conteúdo digitado na comparação | `typedContent` | o conteúdo que o `#3a` deixa digitar **só na folha sem embalagem** (`acceptsTypedContentOf`). No mapa que chega a `rankCosts`, `null` é "campo apagado" e a **ausência** da chave é outra coisa: ninguém digitou |
| preço de abertura da linha | `openingPriceOf` | o pago por **uma** embalagem na última compra. `null` é a embalagem nunca comprada na janela |
| máscara de um campo digitável | `UnitSpec` | vem do `tekton_core`. Carrega as casas decimais, o prefixo e o sufixo — e as casas **não são escolha**: são o expoente entre a unidade digitada e a de leitura |
| tradutor de `BaseUnit` para máscara | `specOf` | mora em `lib/ui/core/unit_specs.dart`, e **não** em `domain/`: `UnitSpec` importa `flutter/services.dart` (regra 1). Grama → `UnitSpec.weight`, mililitro → `.volume`, centímetro → `.length`, unidade → `unitCountSpec` |
| a máscara de quem conta peças | `countSpec` | inteiro **sem sufixo**, e serve a um campo só: o `pieceCount` da embalagem ("Quantas peças?"). **Não confundir com `unitCountSpec`**, que é a grandeza Contagem de um tipo e escreve `un` |
| versão do app | `AppVersion` | as três informações que identificam um build: versão, build e commit. Dart puro — não conhece a palavra "Versão" |
| número do build | `buildNumber` | o contador de execuções do CI (`github.run_number`), **não** o `+N` do `pubspec.yaml`. `null` é o build local |
| commit do build | `commit` | os 7 primeiros caracteres do hash, sem tradução. `null` é o build local |
| conferir despensa | `PantryCheck` | a Tela 2 desde 25/09/2026: marcar o que acabou em casa e jogar na lista **sem quantidade**. A rota continua `/suggestions` |
| editar o cadastro na Tela 4 | `editRegistration` / `RegistrationEditOutcome` | identidade + embalagens novas num toque (**M-b**). Três desfechos: `RegistrationEdited`, `RegistrationEditFailed`, `PackagingsFailedAfterEdit` |
| a identidade mudou? | `changesIdentityOf` | comparação **crua**; não confundir com `hasSameIdentityAs`, que normaliza. "acem" → "acém" muda, mas não é outro cadastro |
| mover o cadastro de tipo | `checkTypeMove` | a rede embaixo de `typesCompatibleWith`: lança `IncompatibleBaseUnit`. Usada pelos dois ViewModels que movem cadastro |
| código de barras | `Barcode` | sempre em GTIN-14; `label` é o número da tela (EAN-13 ou EAN-8). Uma embalagem tem **zero, um ou vários**, e um código é de **uma embalagem só** no app. Recusas: `InvalidBarcode` e `InStoreBarcode` |
| dono do código | `BarcodeOwner` | folha + cadastro + tipo + marca. `label` é **tipo + marca + descrição + embalagem** (não `labelWith`), e `isActive` olha a folha e o cadastro |
| procurar pelo código | `BarcodeLookupViewModel` / `BarcodeLookupOutcome` | usado pelo `#1a` e pela Despensa. Também mora aqui o `linkScaleCode` |
| etiqueta de balança | `ScaleLabel` | `parse` devolve `itemCode` + `weightInGrams`. Só o formato da foto da tâmara (M-d). A validade e o peso **nunca** são gravados |
| código de balança | `ScaleCode` | `storeId` + `itemCode`. **Preso ao mercado**, ao contrário do `Barcode` |
| o que a leitura significa | `resolveScan` / `ScanResolution` | sete casos, e a tela só faz o `switch` |
| item montado pela calculadora | `CostPick` / `costPickOf` | o que o `[ Adicionar … à compra ]` põe. Por peça, 1 embalagem; a peso, o "Quanto vem" |
| leitura no painel | `admitScan` / `ScanAdmission` | `AlreadyShown`, `AddedToShown` ou `OtherType` |
| modo caixa | `checkoutScan` / `CheckoutStep` | a tela é `CheckoutScreen`, identificada `#3b` no wireframe, e **sem rota** |
| preço anterior | `PriceOrigin.lastPurchase` | vai **só** para o rascunho. `fromApi` sem o campo dá `typed`, e um valor desconhecido dá `values.first` (exceção à regra global do `unknown`, ver **M-f**) |
| conferir o preço | `confirmedPrice` | a transição `lastPurchase → typed` (regra 7) |
| conflito de código | `BarcodeConflict` / `conflictOf` | `RepeatedOnScreen` ou `TakenByActive`. Dono desativado **não** é conflito |
| código preso a produto desativado | `inactiveHoldersOf` | o salvar libera **sem perguntar** |
| embalagem com seus códigos | `PackagingWithBarcodes` | o que a Tela 4 manda ao repository |
| conferir os códigos antes de salvar | `checkBarcodes` / `BarcodeCheckOutcome` | **uma** ida a `findOwners` |
| incluir código na manutenção | `BarcodeAddOutcome` | inclui o `BarcodeAddFailed` |
| código já nesta embalagem | `Product.withBarcode` / `withoutBarcode` / `BarcodeAlreadyOnPackaging` | na manutenção; no cartão da Tela 4 são `PackagingDraft.withBarcode` / `withoutBarcode` |
| quem tem estes códigos | `findOwners` | **uma** ida, só código de embalagem, dono ativo e desativado. Quem decide é `conflictOf` |
| a embalagem aceita código? | `Product.acceptsBarcodes` | a folha a peso não aceita |
| código no cartão da Tela 4 | `packagingCodesWith` / `packagingCodeOf` | |
| código que abre a Tela 4 | `initialBarcode` | campo do `NewProductRequest` |
| código de balança no cadastro | `checkScaleCodes` / `UnexpectedScaleCode` | só no vendido a peso |
| código de balança repetido no produto | `scaleCodesWith` / `ScaleCodeAlreadyOnProduct` | |
| código de balança tirado da etiqueta | `ScaleCode.fromLabel` | a etiqueta **inteira** vira `storeId` + `itemCode` |
| seção dos códigos de balança | `ScaleCodesSection` | Mercado + campo + `[▥]` + `[+]` + lista, na Tela 4 a peso |
| etiqueta fora do formato | `UnknownScaleLabel` | |
| etiqueta lida com o produto já ligado | `ScaleMatch.ofLabel` / `ScaleUnlinked.linkedTo` | o peso só vira Quantidade quando o tipo é em grama |
| produtos que "Qual produto é este?" oferece | `scaleLinkCandidatesOf` | só os vendidos a peso, sem repetir |
| leitor de código | `BarcodeReaderSheet` | é um **painel** e devolve o texto **cru**. Nunca chamar de "folha", palavra que é do produto |
| visor da câmera | `BarcodeCameraView` / `codeGoneGap` | lê sem parar. O mesmo código só vale de novo **depois de sair do visor** |
| frase da leitura | `ScanNotice` | |
| produto já pedido na lista | `isRegistrationTaken` | "Já está na lista." |
| pôr na lista o produto lido | `addWithRegistration` / `categoryOf` | tipo + produto pedido, **sem embalagem**, e a categoria do tipo |
| leitura na despensa | `PantryScan` / `pantryScanOf` | |
| folha lida entra no painel | `CostCandidates.withShown` | |
| linha escolhida no painel | `pickedId` | não confundir com `ShoppingListItem.picked` |
| qual produto é esta etiqueta | `ScaleLinkDialog` / `ScaleLink` | |
| de qual mercado é a etiqueta | `ScaleStoreDialog` | |
| linha sem preço do caixa | `NeedsPrice` / `pricedAt` / `joining` | fica **fora** do rascunho. O preço digitado é o de **uma** embalagem |
| o que passou agora no caixa | `QuantityIncreased.addedPaid` | |
| mercado que vem da etiqueta | `PurchaseDraft.storeAdoptedFrom` | |
| bipe | `Beep` / `beepProvider` | pacote `web`, atrás de *conditional import* |
| há preço a conferir? | `hasUnconfirmedPrices` / `unconfirmedPrices` / `PurchaseItem.isPriceUnconfirmed` | |
| conferir um preço ou todos | `withPriceConfirmed` / `allPricesConfirmed` / `confirmPrice` / `confirmAllPrices` | os dois primeiros no rascunho, os dois últimos no ViewModel |
| linha escolhida sem preço | `CostRanking.missingPriceOf` | "Digite o preço do {label}." acima do botão travado |
| id de registro | `newRecordId` / `isRecordId` | 15 caracteres `[a-z0-9]`, o formato do PocketBase. Nasce no app, antes da gravação |
| data guardada | `encodeStoredDay` / `decodeStoredDay` | dia de calendário à meia-noite UTC, `'YYYY-MM-DD 00:00:00.000Z'`. Lê só os 10 primeiros caracteres |
| instante guardado | `encodeInstant` / `decodeInstant` | sempre UTC. `created_at` da compra e `warned_*_at` |
| plano de escrita da compra | `PurchaseWritePlan` | `forCreate`/`forCorrection`/`forDeletion`: o que as três RPCs faziam, calculado no domain |
| mudança numa linha da lista | `ListItemChange` | estado final de `fulfilled_on` e `not_found`; `notFound` nulo é "não mexe" |
| o que acontece com fulfilled_on | `FulfillmentChange` | `KeepFulfillment`, `SetFulfilled`, `ReopenItem`; reabrir ≠ não mexer |
| etapa da escrita | `PurchaseWriteStep` | a ordem do lote: pai antes do filho, inversa na exclusão |

**`ProductRegistration` e `Packaging` foram escolhidos aqui, não pelo cliente** — os dois
termos são ambíguos em inglês. Confirme na H2, antes de a entidade existir; depois disso
renomear custa caro. Todo termo novo ambíguo é decisão do usuário: **pergunte** e
registre nesta tabela.
