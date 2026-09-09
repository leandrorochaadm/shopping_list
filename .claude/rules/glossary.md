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
| passo do arredondamento | `averageStepOf` / `roundToAverageStep` | uma casa decimal da unidade de **leitura** — 100 g, 100 ml, 1 un, 10 cm. **Nunca transforma positivo em zero** |
| a sub-linha da Tela 6 | `listStatusLabel` | as quatro formas de "o que a lista está pedindo", mais o sufixo do "não encontrei" |
| o item aberto de um tipo | `findOpenItemOfType` | o mais antigo quando há mais de um. É onde "editando o item que já existe, nunca criando um segundo" é decidido |
| calculadora de custo proporcional | `proportional_cost.dart` | o painel `#3a`. **Não** `CostCalculator`: o que existe é a regra, e ela não é um objeto que calcula |
| linha da calculadora | `CostLine` | folha + marcada + preço + custo + diferença + `★`. **Não confundir com `ComparisonLine`**, que é a linha de MERCADO da H16 |
| as duas listas do painel | `CostCandidates` | o recorte da janela **mais a folha em lançamento** (`shown`) e o tipo inteiro (`all`). `canCompare` é a regra do botão da Tela 3 |
| a folha que está sendo lançada | `launching` | o parâmetro de `costCandidatesOf` e do painel. É a **única que abre marcada**, e a única que entra em `shown` sem preço (F-j) |
| resposta da calculadora | `CostRanking` | as linhas ordenadas, o `★`, para onde o `[ Usar… ]` aponta e a frase do rodapé |
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

**`ProductRegistration` e `Packaging` foram escolhidos aqui, não pelo cliente** — os dois
termos são ambíguos em inglês. Confirme na H2, antes de a entidade existir; depois disso
renomear custa caro. Todo termo novo ambíguo é decisão do usuário: **pergunte** e
registre nesta tabela.
