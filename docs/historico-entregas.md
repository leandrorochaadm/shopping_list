# Histórico das entregas — o que cada uma mudou fora das telas dela

Recortado do `CLAUDE.md` em 03/09/2026, palavra por palavra.

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
