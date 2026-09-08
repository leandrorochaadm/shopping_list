# Wireframes (rascunho) — Lista de compras de supermercado

Versão: 2.1 | Data: 04/09/2026

**O que mudou na 2.1** (sobre a 2.0) — o arquivo passou a declarar **o tamanho
da tela em que ele é lido**, e uma das ordens desenhadas contrariava isso:

- **As Convenções de notação ganharam a subseção "O tamanho da tela"**: o alvo é
  o PWA instalado num iPhone 12, 390 × 844 pontos, e com o teclado aberto sobram
  cerca de 500. Daí a regra — **todo campo digitável é desenhado acima de
  qualquer lista, resumo, total ou botão**, em tela e em diálogo —, mais as duas
  exceções: o campo dentro de linha repetível e a frase que explica o campo
  vazio.
- **A Tela 3 mudou de ordem:** "Itens desta compra" desceu para **depois** do
  `[ + Adicionar à compra ]↻`. Estava entre o Mercado e o Produto, e cada item
  lançado empurrava Produto, Quantidade e Valor — os três campos do caminho
  normal — para debaixo do teclado. Nota nova explicando o porquê.
- **A Tela 4 ganhou a nota do estado da manutenção:** as embalagens **já
  cadastradas** aparecem abaixo das linhas editáveis e do
  `[ + Adicionar embalagem ]↻`, nunca acima. O quadro não muda — esse estado
  nunca foi desenhado, porque a tela do quadro parte de um cadastro em branco.
- **O checklist ganhou o item** que confere a regra nas seis telas e nos dois
  painéis.

**O que mudou na 2.0** (sobre o rascunho 1.9) — os **16 achados da revisão em
três passadas**, feita depois de os dois documentos se declararem fechados
(`revisao-3-passadas.md`). Sete foram decididos por ele no mesmo dia; os outros
nove eram redação, exemplo e notação:

- **O campo do lançamento, no produto vendido a peso, deixou de ser sempre
  "Peso (kg)"** (Tela 3). O rótulo vem da **unidade base do tipo** — "Peso (kg)",
  "Volume (L)", "Quantidade (un)". Preso ao quilo, o azeite a granel não tinha
  caminho: não tem embalagem para cadastrar e não cabe num tipo de outra
  grandeza.
- **Tipo e categoria ganharam trava de duplicidade** (`#1a` e Tela 4), e ela
  **ignora maiúsculas, espaço sobrando e acento**: "acem moido" encontra "acém
  moído" e o `[ + Criar "…" ]` some. Eram os dois últimos cadastros sem trava, e
  o tipo é o nível que soma. **Tipo desativado passou a aparecer na busca**, com
  opção de reativar em vez de nascer de novo.
- **Categoria e Tipo ganharam `[+Novo]↻` na Tela 4**, como a Marca já tinha. Sem
  eles, a primeira compra de uma categoria nova travava com o cupom na mão,
  depois que o sistema deixava de estar vazio.
- **A Tela 1 ganhou a faixa de itens novos.** A lista se atualiza sozinha, mas o
  que chega do outro celular entra por uma faixa no topo —
  `[ 2 itens novos — atualizar ]↻` — em vez de se mexer debaixo do dedo de quem
  está no corredor.
- **O mini-cadastro de tipo deixou de abrir com "kg" marcado** (`#1a`), contra a
  própria nota que proíbe padrão adivinhado; o `[ Criar e adicionar ]` fica
  travado até uma unidade ser escolhida.
- **A Tela 6 ganhou o detergente e o frango**, que sumiam das duas faixas embora
  a nota da tela prometesse exatamente o caso do item marcado como "não
  encontrei".
- **Telas 3 e 4 e o painel `#3a` ganharam estado de "carregando"**, que o
  checklist afirmava existir e não existia — e as três são justamente as que mais
  esperam dados de fora do celular.
- **Uma quarta passada, sobre o texto já corrigido, achou mais quatro coisas:**
  a decisão do rótulo pela unidade base não tinha sido propagada para o `#3a`,
  que continuava dizendo que a linha do produto a peso abre "com o preço do
  quilo"; **marca e mercado continuavam sem trava de duplicidade**, embora o
  critério de aceite do requisito 15 já a prometesse e a trava nova de tipo e
  categoria deixasse a falta à vista; a comparação da **descrição** passou a
  ignorar acento também, para as quatro comparações do documento serem a mesma; e
  o estado "antes da unidade base estar definida" da Tela 4 citava um caso — tipo
  novo sem unidade — que o `[+Novo]↻` do Tipo eliminou.
- **Correções de texto e notação:** a Tela 2 deixou de chamar a janela fechada de
  suposição (confirmada duas versões antes) e ganhou a nota de que abre com tudo
  desmarcado; a cobertura do PWA passou de cinco para **seis diálogos**, com o de
  categoria nova; o `👤` entrou na tabela de notação; o `[–]` passou a ser
  escrito de um jeito só; e o changelog da 1.5 deixou de dizer que o botão
  "Comparar custo" fica "ao lado" do campo Produto, quando a decisão registrada é
  em linha própria abaixo dele.

**O que mudou na 1.9** (sobre o rascunho 1.8) — as **duas últimas suposições
marcadas neste arquivo**, mais a data futura do lançamento, que vinha dos
requisitos. Todas decididas por ele em 26/08/2026, e com elas não sobra pergunta
em aberto neste rascunho nem no documento de requisitos:

- **A caixa do item da lista deixou de girar três estados** (Tela 1). Ela alterna
  só vazio ↔ pego, e **"não encontrei" foi para o diálogo** que já abre ao tocar
  no texto do item. O ciclo de três punia o erro mais provável do corredor, o
  toque distraído, com a consequência mais cara: item comprado virava item não
  achado, que é o recado errado para quem lê a lista depois e só cai sozinho na
  próxima compra do tipo.
- **O cadastro de produto virou único por tipo + marca + descrição** (Tela 4).
  Recomeçar do zero o que já existe é **barrado**, com o salvar travado e um
  botão que abre o cadastro existente para acrescentar a embalagem nova — o
  caminho do requisito 16, agora a um toque. A descrição entra na identidade
  (separa "zero" de "original") e em branco conta como valor; a embalagem fica
  de fora, porque é o que se acrescenta depois. Como a descrição passou a separar
  cadastros, o campo agora **sugere as já usadas** naquele tipo e naquela marca, e
  duas descrições são comparadas ignorando maiúsculas, espaço sobrando e acento
  — senão
  "orig." reabriria pela porta dos fundos o buraco que o bloqueio fecha. A Tela 4
  ganhou o estado desenhado desse bloqueio.
- **A data futura do lançamento ficou bloqueada na origem** (Tela 3): o
  calendário não deixa tocar em nenhum dia depois de hoje, em vez de avisar e
  deixar passar.

**O que mudou na 1.8** (sobre o rascunho 1.7) — todas por decisão dele em
26/08/2026, fechando as pendências levantadas na revisão cruzada dos dois
documentos:

- **Nasceu o diálogo `#1a` — Adicionar item**, que o rascunho prometia num botão
  e nunca desenhava. É uma busca sobre os tipos já cadastrados, com **criar o
  tipo na hora** quando nada bate; o item entra só com o tipo, e quantidade,
  marca e embalagem continuam no diálogo de edição.
- **O sistema passou a ter duas janelas de 3 meses, declaradas**: **rolante**
  (com o mês em curso) para alerta de preço, comparação entre mercados e
  calculadora; **fechada** (os três meses fechados anteriores) para sugestão e
  "falta comprar". O cabeçalho da Tela 2 dizia uma coisa e a nota da mesma tela
  dizia outra.
- **O lançamento em andamento ficou guardado no aparelho.** A Tela 3 ganhou
  estado de conexão próprio: cair a internet com 18 itens digitados não perde
  nada.
- **A Tela 6 passou a avisar quando o diálogo muda a regra de baixa** do item
  que está na lista sem quantidade, e a faixa "já atingiram a média" virou
  "nada faltando este mês", que também é verdade para o produto nascido no mês.
- **Correções de exemplo e notação**: os preços do Omo ficaram os mesmos nas
  três telas onde aparecem, o quadro do `#3a` passou a mostrar o que a própria
  nota descreve, a fórmula do recálculo do valor virou *quantidade convertida ×
  preço da unidade base*, o mapa de navegação ganhou o eixo da barra fixa, o
  período do relatório ganhou os dois seletores de data e o `[–]` passou a valer
  para item **e** botão travado.

**O que mudou na 1.7** (sobre o rascunho 1.6):

- **A marca virou cadastro próprio, como o mercado** (decisão dele). Na Tela 4 o
  campo deixou de ser texto livre com sugestão e virou `▼ marca` com `[+Novo]↻`
  ao lado: escolhe da lista ou cadastra na hora, sem sair da tela. O motivo é o
  mesmo do mercado — "Omo" e "OMO" digitados em dias diferentes partiriam o
  histórico de preço da marca em dois, e renomear depois não junta o que nasceu
  separado. A **descrição continua livre**, porque não sustenta conta nenhuma.
- **Telas 2 e 6 passaram a ser agrupadas por categoria**, em ordem alfabética
  dentro de cada uma — a mesma organização da Tela 1. Some o "do mais comprado
  para o menos comprado", que comparava grandezas diferentes: 12 unidades de
  papel higiênico não são "mais" que 5 kg de arroz. O mesmo vale para o seletor
  de produto da aba Comparação de preço.
- **Corrigir uma compra passou a refazer o efeito dela na lista**, e não só os
  relatórios — antes só apagar fazia isso. Baixar o leite de 6 L para 2 L devolve
  4 L ao saldo do item; remover um item da compra devolve o item inteiro.
- **A Tela 5 ganhou o estado "sem teto configurado"**: enquanto o teto não for
  definido, o "Gastou X de Y" não aparece e nenhum aviso dispara. O teto começa a
  valer no mês em que foi configurado, e não retroage.
- **A aritmética do divisor foi corrigida** sem mudar o resultado de nenhum caso:
  o divisor são os **meses fechados** de vida do produto dentro da janela, e o
  produto nascido no mês em curso — que não tem nenhum — fica fora da divisão,
  com a própria compra do mês por média. Antes o texto dizia que ele "divide por
  1", o que aplicado ao literal daria zero, já que ele não tem consumo nenhum
  dentro da janela.

**O que mudou na 1.6** (sobre o rascunho 1.5):

- **Nasceu a Tela 6 — Falta comprar este mês.** Ela responde uma pergunta que
  nenhuma tela respondia: *quanto ainda falta comprar de cada tipo de produto
  neste mês, comparado com o que costumam consumir*. O número é a **média dos
  3 meses menos o que já foi comprado no mês corrente** — "acém moído: média de
  6 kg por mês, 4 kg comprados em agosto, faltam 2 kg".
- **A barra inferior passou a ter três destinos** — `Lista`, `Falta` e
  `Relatórios` —, presentes nas Telas 1, 5 e 6.
- **O divisor da média virou proporcional à vida do produto** (decisão dele na
  mesma sessão, substituindo o "dividido por 3, sempre"): produto que já era
  comprado antes da janela divide por 3, o que nasceu em junho divide por 2, e o
  que apareceu neste mês tem por média a própria compra. Vale para as Telas 2
  e 6, que precisam contar igual.
- **A Tela 6 esconde quem já atingiu a média** e revela o resto num
  `[ Ver todos ]↻` no rodapé, para o caso do produto que acabou antes da hora.
- **Tocar num item da Tela 6 abre o mesmo diálogo de item da Tela 1**, já com a
  quantidade que falta preenchida e editável. A Tela 6 não ganhou seleção
  múltipla: isso continua sendo papel da Tela 2.
- **A Tela 2 não mudou nada**: continua oferecendo todo tipo comprado ao menos
  uma vez nos 3 meses, sem filtrar por saldo. As duas telas respondem perguntas
  diferentes e a nota da Tela 6 declara qual é qual.
- **Corrigida a Tela 2**, que oferecia acém moído e sabão em pó como opção tendo
  os dois na lista da Tela 1 — contra a própria regra do `{–}`. O quadro passou a
  usar dois tipos fora da lista e a mostrar as duas formas de item travado.
- **Ficou escrito na Tela 1 que quem manda na baixa é a quantidade escrita no
  item** — venha ela da sugestão ou digitada à mão. A média dos 3 meses informa,
  nunca segura item na lista.

**O que mudou na 1.5** (sobre o rascunho 1.4):

- **Nasceu o diálogo `#3a` — Comparar custo**, aberto por um botão em linha
  própria abaixo do campo "Produto" da Tela 3. Ele marca **duas ou mais** embalagens do mesmo tipo
  de produto, de qualquer marca, e ajusta os preços; o custo por unidade base
  aparece **ao vivo**, linha a linha, com o `★` no melhor. É o requisito 17.
- **O `#3a` é um painel ancorado na parte de baixo**, não uma sexta tela: o
  lançamento fica visível atrás, e não há animação de entrada — a especificação
  do PWA continua sem transição nenhuma. **Não há botão "Comparar" nem segunda etapa** — a conta
  acontece enquanto ele digita, e o veredito mora num **rodapé fixo** que nunca
  sai da tela, por mais que a lista role. Foi o que resolveu o aperto do celular:
  só a lista rola, e ela abre curta.
- **A lista abre só com as embalagens compradas nos últimos 3 meses**, com um
  `[Ver todas do tipo]↻` no fim. Num tipo com 20 embalagens cadastradas, ele vê
  as 3 ou 4 que de fato usa.
- **A Tela 3 ganhou o botão `[Comparar custo]→3a`**, opcional: quem não abrir
  não perde nada, e a ordem de preenchimento continua produto → quantidade →
  valor.
- **A comparação entre fardo e peça avulsa saiu do "em aberto".** O alerta de
  alta continua sem misturar embalagens; a pergunta "qual sai mais barato o
  litro" passou a ter lugar próprio no `#3a`, sem custar nenhum aviso a mais na
  tela dos 2 minutos.
- Notação ganhou o símbolo **`★`** (melhor custo), usado só no `#3a`.

**O que mudou na 1.4** (sobre o rascunho 1.3):

- **Tela 4 refeita.** O campo "Peso da peça" virou uma **lista de embalagens**:
  cada linha é `peças × medida da peça`, o nome resultante aparece ao lado
  ("12x350ml"), e um cadastro só salva várias — 350ml, 269ml, 2L e 12x350ml de
  uma vez. Um rádio na lista marca **qual embalagem ele está comprando agora**,
  e é ela que volta selecionada na Tela 3.
- **Tela 1: o item da lista pode carregar marca e embalagem preferidas** ("Leite
  Italac 1 L"), as duas opcionais. A quantidade continua na unidade base.
- **Tela 3: item vindo da lista com preferência já chega com o produto
  selecionado**, e o campo de quantidade virou um só — "Quantidade" —, sem
  rótulo variável: quem diz o que está sendo contado é o nome da embalagem
  ("12x350ml"). Produto vendido a peso continua trocando para "Peso (kg)".
- **A medida da peça é digitada em número inteiro, na unidade do tipo** — `g`,
  `ml`, `un` ou `cm` escrito ao lado do campo. Desde 07/09/2026 **não há mais
  seletor de medida** (divergência J-a): a grandeza do tipo já respondeu "g ou
  kg?", e a tela lê de volta na unidade grande quando o número a alcança
  ("1000" digitado aparece como "1 L").
- Onde se lia "mesmo peso" na comparação de preço, passou a ler **"mesma
  embalagem"**; a visão "Tipo inteiro" ganhou o papel de comparar fardo contra
  lata avulsa.
- **O rótulo variável da quantidade foi eliminado.** Não existe "Peças",
  "Pacotes" nem "Fardos": o campo da Tela 3 é só **"Quantidade"**, e quem diz o
  que está sendo contado é o nome da embalagem ("12x350ml"). Produto vendido a
  peso segue sendo a única exceção, com "Peso (kg)".
- **O nome da embalagem virou o formato compacto** — `350ml`, `2L`, `12x350ml`,
  `12un` —, mostrado na Tela 4 ao lado de cada linha e usado em todas as telas.
- **A embalagem deixou de ser "opcional" em bloco:** é obrigatória (ao menos
  uma) no produto vendido por peça e não existe no produto vendido a peso, onde
  a lista some da tela inteira. Sem ao menos uma, não há como converter a compra
  para litro ou quilo.
- Declarado que a **Tela 4 aberta sobre um produto que já existe** — para
  acrescentar embalagem — vem da **manutenção do cadastro** (requisito 16),
  atrás do `≡`, e não do `[+Novo]` da Tela 3, que abre sempre em branco.

**O que mudou na 1.3** (sobre o rascunho 1.2):

- Aba Comparação de preço: cada mercado passa a mostrar também a **data da
  compra** de onde aquele preço veio, no formato `dd/MM`. A ordem da lista
  continua sendo do mais barato para o mais caro — a data informa, não ordena.

**O que mudou na 1.2** (revisão do mesmo dia, sobre o rascunho 1.1):

- Declaradas as **configurações** atrás do `≡` — é lá que o teto do mês é
  definido e alterado, e onde "quem está usando" é trocado. Na 1.1 o teto era
  consumido em dois lugares sem nunca ser informado.
- Notação de **seleção múltipla** (`{ }`, `{x}`, `{–}`) criada para a Tela 2:
  `[ ]`/`[x]` significavam duas coisas diferentes na Tela 1 e na Tela 2.
- Telas 3 e 4 ganharam o estado de **sistema vazio** — nenhum mercado e nenhum
  produto cadastrados, que é o estado das primeiras semanas.
- Tela 3: o valor total passa a ser descrito como **recalculado pela
  quantidade**, a partir do preço da unidade base da última compra.
- Tela 1: o item passa a mostrar o **saldo** da compra parcial ("restam 2 de
  6 kg").
- Alerta de preço: limiar corrigido para **10% ou mais**, e declarado o caso em
  que não há base nos 3 meses — o sistema fica quieto.
- Tela 4: "Unidade" deixou de ser campo livre do produto; ela **vem do tipo**.
- Declarado que "quem lançou cada compra" mora no histórico, atrás do `≡`.
- Números do relatório aberto por tipo passaram a fechar com as reticências.
- Definido o que acontece quando os **dois avisos** disparam na mesma compra.
- Aba Comparação passou a exemplificar com "Omo 500g" — com "acém moído", que
  não tem marca, os dois rádios ficavam indistinguíveis.
- Checklist deixou de afirmar como pronto o que ainda não estava.
- Tela 5 passou a usar a **mesma barra inferior** da Tela 1, em vez de
  `< Voltar`.
- Notação ganhou símbolo próprio para **seletor de data** (`▤`), que antes
  reusava o de lista suspensa.
- O ciclo de três toques do item da lista foi marcado como **suposição**, já que
  não vem dos requisitos.

<!-- USO INTERNO. Este arquivo não vai para o cliente leigo: ASCII quebra
     alinhamento em WhatsApp, e-mail e celular. Ele serve para alinhar a
     estrutura antes de montar o PWA preto e branco, sem efeitos visuais,
     com navegação entre telas — esse PWA sim é o que se aprova. -->

---

## Convenções de notação

| Notação | Significa | Vira no PWA |
|---|---|---|
| `[ Texto ]` | Botão | `<button>` |
| `[ Texto ]→3` | Botão que navega para a tela 3 | `<button>` com navegação |
| `[ Texto ]↻` | Botão que age na própria tela, sem navegar | `<button>` sem rota |
| `[[ Texto ]]` | Aba atualmente selecionada | aba ativa |
| `(•) Opção` / `( ) Opção` | Rádio marcado / desmarcado | `input[type=radio]` |
| `[ ] Opção` | Item da lista ainda não pego | item em estado neutro |
| `[x] Opção` | Item já pego no corredor | item em estado "peguei" |
| `[!] Opção` | Item marcado como "não encontrei" | item em estado "não encontrei" |
| `Opção [–]` / `[ Texto ][–]` | Item **ou botão** travado, não responde ao toque | elemento desabilitado |
| `{ } Opção` / `{x} Opção` | Seleção múltipla: desmarcada / marcada | `input[type=checkbox]` |
| `{–} Opção` | Seleção múltipla travada | checkbox desabilitado |
| `___________` | Campo de texto | `input[type=text]` |
| `Label: ___________` | Campo com rótulo | `label` + `input` |
| `▼ Selecione` | Lista suspensa | `select` |
| `▤ 18/08/2026` | Seletor de data | `input[type=date]` |
| `< Voltar` | Voltar para a tela anterior | botão de voltar |
| `▓▓▓▓▓` | Área de imagem | retângulo cinza com o texto "imagem" |
| `═════` | Divisória | `<hr>` |
| `• item` | Item de lista | `<li>` |
| `#N` | Âncora/ID da tela | rota do PWA |
| `≡` | Menu | botão de menu |
| `👤 Nome ↻` | Quem está usando este aparelho; toca para trocar, sem senha | botão de perfil |
| `⚠` | Aviso não bloqueante | banner/toast |
| `★` | Melhor custo proporcional (só no `#3a`) | item destacado |
| `══` | Alça do painel ancorado embaixo | topo do painel |
| `░░░` | Tela de trás, esmaecida atrás do painel | fundo cinza |
| `↕` | Anotação: essa faixa rola | área com scroll |

### O tamanho da tela

O alvo é **um PWA instalado na tela de início de um iPhone 12: 390 × 844
pontos**. Não é monitor, não é tablet e não é aba de navegador. Todo quadro
deste arquivo é desenhado para essa medida.

Com o teclado aberto sobram cerca de **500 pontos** — o teclado do iPhone leva
perto de 340. Por isso, **todo campo digitável é desenhado
acima de qualquer lista, resumo, total ou botão**, em tela e em diálogo: o que
se digita vem primeiro, o que se lê vem depois e pode descer. Campo no meio da
tela vai parar debaixo do teclado no aparelho, e espaçamento não resolve isso —
o problema é que o espaço deixou de existir, e quem resolve é a **ordem** dos
elementos.

São duas as exceções. A primeira é o campo que mora **dentro de uma linha
repetível** (as embalagens da Tela 4, as linhas do `#3a`): não existe "topo"
para ele, e o que se exige em troca é que a faixa que rola **termine onde o
teclado começa** — é o que o `#3a` já faz. A segunda é a **frase que explica o
campo vazio**, que fica acima dele: explicação abaixo do campo que ela explica
é legenda órfã, e ela só vale onde o campo não chega perto da dobra do
teclado.

**Regras:**
- Larguras fixas em 40 colunas — proporção de tela de celular.
- Sem cor, sem sombra, sem ícone decorativo. Só estrutura.
- Todo botão navega com `→N` ou age na própria tela com `↻`. **Única exceção:**
  o `≡`, que leva a telas deliberadamente não desenhadas aqui e por isso não
  tem destino.
- `[ ]` marca **estado** do item na lista (Tela 1); `{ }` marca **escolha** em
  seleção múltipla (Telas 2 e `#3a`). São coisas diferentes e por isso têm
  símbolos diferentes.
- Elemento com regra de negócio leva `*`, explicada abaixo do quadro.
- O `#3a` é chamado de **painel**, nunca de "folha": no documento de requisitos
  "folha" já tem dono — é a folha da hierarquia, o produto.

---

## Mapa de navegação

```
Barra inferior fixa (as três se alternam, e alternar não é "voltar"):

   1 Lista de compras ←→ 6 Falta comprar este mês ←→ 5 Relatórios
                                                     (aba Resumo /
                                                      aba Comparação de preço)

A partir da Tela 1:

1 Lista de compras ──→ 1a Adicionar item ──→ (volta para 1)
        │
        ├──────────→ 2 Sugestão de itens ──→ (volta para 1)
        │
        └──────────→ 3 Lançar compra ──→ 4 Novo produto ──→ (volta para 3)
                            │
                            └──→ 3a Comparar custo ──→ (volta para 3)
```

A **barra inferior é fixa e tem três destinos** — `Lista`, `Falta` e
`Relatórios` —, repetida igual nas Telas 1, 5 e 6. Alternar entre elas não é
"voltar": são os três lugares onde o app deixa ele parado, e qualquer uma leva
às outras duas. O `< Voltar` só existe nas telas que **saem** desse trio
(Telas 2, 3 e 4) e nos dois painéis (`#1a` e `#3a`), que fecham no `[ X ]`.

**Fora deste rascunho, de propósito.** Quatro coisas moram atrás do menu `≡` da
Tela 1 e não foram desenhadas, para o rascunho ficar nas 6 telas do dia a dia:

- o **histórico de compras lançadas** — é nele que aparece **quem lançou cada
  compra** (requisito 14); os relatórios da Tela 5 somam o casal junto, sem
  separar por pessoa;
- a **correção ou exclusão de uma compra** (requisito 12). Ela bate em duas
  telas deste rascunho: desfazer a compra devolve à Tela 1 os itens que saíram,
  o saldo abatido **e a marcação "não encontrei"** que aquela compra derrubou
  (decisão de 26/08/2026), e pode disparar ou rearmar os avisos de teto da
  Tela 3 e da Tela 5;
- a **manutenção do cadastro** — renomear, reclassificar, desativar **e
  reativar** categoria, tipo, marca, produto e mercado, e **acrescentar embalagem
  a um produto que já existe** (requisito 16). Duas regras dela batem em telas
  deste rascunho: desativar um tipo que está na lista **avisa e remove o item**
  (Tela 1), e a troca de tipo só é oferecida entre tipos da **mesma unidade
  base**. **Desativar marca, produto ou embalagem que é preferência de um item
  da lista não avisa nada** (decisão de 26/08/2026): a preferência cai em
  silêncio e o item continua na Tela 1 só com o tipo — ela nunca mandou na baixa,
  e nenhum item é removido. **Tipo e categoria desativados continuam aparecendo
  na busca do `#1a`**, marcados como desativados e com opção de reativar, para
  que dar falta deles não vire um cadastro novo com o mesmo nome. É a segunda
  porta de entrada da Tela 4, que o mapa
  acima não mostra por ela morar atrás do `≡`: chegando por aqui, a tela abre
  com o produto preenchido; chegando pelo `[+Novo]` da Tela 3, abre em branco.
  Existe uma terceira porta desde a 1.9, e ela é interna: o cadastro **barrado
  por repetição** oferece abrir o produto que já existe sem passar pelo `≡`;
- as **configurações**, onde o **teto de gasto do mês** é definido e alterado
  (requisito 9) e onde "quem está usando" também pode ser trocado. **Salvar um
  teto que o mês já ultrapassou avisa ali mesmo** — "vocês já estão em 87% deste
  teto neste mês" —, e esse aviso conta como o dos 80% do mês (decisão de
  26/08/2026): sem ele, o mês em que o teto nasce seria o único sem aviso
  nenhum antes de estourar. **Alterar o teto zera os dois avisos do mês e
  reavalia na hora** (decisão de 26/08/2026) — teto novo, avisos novos: subir de
  R$ 1.500 para R$ 1.800 com R$ 1.300 gastos não dispara nada agora e devolve os
  80% para quando o mês chegar a R$ 1.440. O teto é
  consumido em duas telas deste rascunho — no aviso ao salvar a compra e no
  "gastou X de Y" do relatório —, e sem essa tela ele nunca teria como ser
  informado.

Não estão esquecidas; estão adiadas para depois de o fluxo principal ser
aprovado.

O **cadastro de mercado novo** também não tem tela própria: acontece em um
diálogo dentro da Tela 3, com um campo só (o nome). O mesmo vale para a **marca
nova** e para a **categoria nova**, os dois de um campo só — a categoria
aparecendo em dois lugares, dentro do `#1a` e dentro da Tela 4 —, e para o
**mini-cadastro de tipo** (nome, categoria e unidade base), que nasceu dentro do
`#1a` e desde a 2.0 é reusado pelo `[+Novo]↻` do Tipo na Tela 4. O mesmo vale
ainda para a
**edição do item da lista**, um diálogo dentro da Tela 1 — reusado pela Tela 6,
que o abre já preenchido —, e para a
**calculadora de custo proporcional** (`#3a`), um **painel ancorado embaixo**
sobre a Tela 3 — desenhada abaixo porque tem regra demais para caber numa nota,
mas não é uma sexta tela: ela não existe fora do lançamento, e o lançamento
continua aparecendo atrás dela.

---

## Tela 1 — Lista de compras (início)  `#1`

```
┌──────────────────────────────────────┐
│ ≡ *            👤 Leandro ↻          │
├──────────────────────────────────────┤
│  [ 2 itens novos — atualizar ]↻   *  │
│  ────────────────────────────        │
│  Carnes                              │
│  [ ] Acém moído — restam 2 de 6 kg * │
│  [x] Frango                       *  │
│  ────────────────────────────        │
│  Limpeza                             │
│  [ ] Sabão em pó                     │
│  [!] Detergente  (não encontrei)  *  │
│  ────────────────────────────        │
│  Laticínios                          │
│  [ ] Leite Italac 1L — 6 L        *  │
│                                      │
│  [    + Adicionar item    ]→1a       │
│                                      │
│  [   Sugerir itens   ]→2             │
│  [     Lançar compra     ]→3 *       │
├──────────────────────────────────────┤
│  Lista     Falta→6     Relatórios→5  │
└──────────────────────────────────────┘
```

**Notas:**
- `*` Item agrupado automaticamente pela categoria do tipo de produto — não é
  ordem de digitação (requisito 11).
- `*` **A caixa alterna dois estados por toque: vazio ↔ peguei (`[x]`)**
  (decisão de 26/08/2026). O terceiro estado, **não encontrei (`[!]`)**, é uma
  opção do diálogo que abre ao tocar no texto do item — não se chega nele pela
  caixa. Pegar é o gesto de quase toda a compra e tem que ser à prova de toque
  distraído; "não encontrei" é raro, é o recado que o outro lê na volta e só cai
  sozinho na próxima compra daquele tipo, então merece um gesto deliberado.
  Girando os três na mesma caixa, o toque a mais transformava item comprado em
  item não achado sem ninguém perceber no corredor. Marcar, em qualquer dos dois
  casos, é só um risco visual: não registra compra e nunca tira o item da lista.
- `*` **A quantidade mostrada é o que ainda falta**, não o que foi pedido. Se a
  lista pedia 6 kg e uma compra lançada trouxe 4, o item continua na lista como
  "restam 2 de 6 kg" — compra parcial abate, não zera. Item sem quantidade
  ("Sabão em pó") sai da lista na primeira compra daquele tipo de produto.
- `*` **O item pode trazer marca e embalagem preferidas** ("Leite Italac 1L").
  As duas são opcionais — "Sabão em pó" não tem nenhuma das duas — e servem para
  lembrar no corredor e para chegar já selecionadas no lançamento. **Elas não
  mandam na baixa:** comprar leite Piracanjuba tira esse item da lista do mesmo
  jeito, porque a marca se decide na prateleira.
- `*` **A quantidade continua sempre na unidade base**, mesmo com a embalagem
  escolhida: "6 L", nunca "6 caixas". Duas medidas na mesma coluna fariam o saldo
  da compra parcial parar de fechar.
- `*` **Tocar no texto do item** (não na caixa) abre um diálogo de edição:
  quantidade, com a unidade base do tipo ao lado do campo — "6 litros",
  "2 quilos" —, **marca e embalagem preferidas** (as duas com "qualquer uma"
  como opção, que é o padrão), **marcar ou desmarcar "não encontrei"** e a opção
  de remover o item da lista à mão. É por aqui que a quantidade vinda da
  sugestão é ajustada (requisitos 8 e 13). O item já marcado mostra o `[!]` na
  linha e volta a ficar limpo pelo mesmo diálogo — ou sozinho, na primeira
  compra daquele tipo.
- `*` **Quem manda na baixa é a quantidade escrita no item**, tenha ela vindo da
  sugestão ou sido digitada à mão. Baixando "6 kg" para "3 kg", o item sai da
  lista assim que 3 kg forem comprados: a sugestão preencheu o campo na entrada e
  não tem voz nenhuma depois disso. O que a média dos 3 meses ainda diria vive na
  **Tela 6**, que informa e não mexe na lista.
- `*` A quantidade **não é editável na própria linha** — ela mora no diálogo. É o
  que mantém dois alvos de toque por linha (caixa e texto): no corredor, com o
  carrinho na mão, um campo numérico na linha abriria o teclado por engano e
  empurraria metade da lista para fora da tela.
- `*` **A faixa de itens novos é como a lista se atualiza** (decisão de
  26/08/2026). A lista se refaz sozinha enquanto está aberta, mas nada entra nem
  se move sozinho: o que chegou do outro celular fica atrás da faixa, e é o toque
  dela que atualiza a tela. Os dois lados pesaram. Sem atualização nenhuma, o caso
  que dá razão ao app inteiro — "um não sabe o que o outro já comprou" —
  continuaria de pé com o aplicativo na mão: ele no corredor, ela adicionando de
  casa. Com a lista se reorganizando sozinha, o item se moveria bem no instante do
  toque e o risco visual cairia no item errado, que é o mesmo motivo pelo qual a
  caixa deixou de girar três estados. A faixa some quando não há nada novo — no
  uso normal, a tela é a do quadro sem essa primeira linha.
- `*` A barra inferior tem **três destinos permanentes**: a lista, `Falta`
  (Tela 6) e os relatórios.
- `*` **`[ + Adicionar item ]→1a` abre o painel de busca de tipo**, com criação
  do tipo na hora quando nada bate. O item entra só com o tipo; quantidade,
  marca e embalagem preferidas ficam para o diálogo de edição, tocando no item
  depois.
- `*` "Lançar compra" é quem de fato dá baixa nos itens.
- `*` O menu `≡` guarda histórico de compras, correção de compra lançada,
  manutenção do cadastro e configurações (teto do mês) — telas não desenhadas
  neste rascunho, e por isso o único botão sem destino marcado.
- 👤 mostra quem está usando este aparelho; toca para trocar, sem senha. É um
  atalho para a mesma troca que existe nas configurações.

**Estados:**
- Primeira abertura do aparelho: tela pede "Quem está usando? ( ) Leandro
  ( ) esposa" antes de mostrar a lista — só uma vez.
- Carregando: lista substituída por "Carregando..." (a lista vem de fora do
  celular, então sempre há espera na abertura).
- **Itens novos do outro celular:** faixa no topo, `[ 2 itens novos —
  atualizar ]↻`, e nada muda na lista até ela ser tocada. Vale para item
  adicionado,
  removido e marcado pelo outro — o texto muda para "a lista mudou — tocar para
  ver" quando não é só adição.
- Vazio: "Sua lista está vazia" + `[ Adicionar item ]→1a` +
  `[ Sugerir itens ]→2`.
- Erro: "Não foi possível carregar a lista" + `[ Tentar de novo ]↻`.
- Sem internet: "Sem conexão — não é possível abrir a lista agora" +
  `[ Tentar de novo ]↻` (o app não funciona sem sinal).

---

## Diálogo `#1a` — Adicionar item  (painel sobre a Tela 1)

```
┌──────────────────────────────────────┐
│ Lista de compras       (fica atrás)  │
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────────────────────────────────┤
│  ══   Adicionar item        [ X ]→1  │
│  Tipo: lei_________________       *  │
│  ────────────────────────────        │
│  Laticínios                          │
│  [–] Leite (já está na lista)     *  │
│  Leite condensado                    │
│  Leite em pó                         │
│         ↕ rola se tiver mais         │
└──────────────────────────────────────┘
```

**Quando nada bate com o que ele digitou:**

```
┌──────────────────────────────────────┐
│  ══   Adicionar item        [ X ]→1  │
│  Tipo: achocolatado________          │
│  ────────────────────────────        │
│  Nenhum tipo com esse nome           │
│                                      │
│  [ + Criar "achocolatado" ]↻      *  │
└──────────────────────────────────────┘
```

**Mini-cadastro de tipo** (abre sobre o painel, no `[ + Criar ]`):

```
┌──────────────────────────────────────┐
│  ══   Novo tipo de produto  [ X ]↻   │
│  Nome: achocolatado________          │
│  Categoria: ▼ Mercearia [+Novo]↻  *  │
│  Medido em: ( ) kg ( ) L ( ) un   *  │
│                                      │
│  [ Criar e adicionar ][–]         *  │
└──────────────────────────────────────┘
```

**Notas:**
- **É o caminho mais usado do app** — mais que lançar compra. Acabou o
  achocolatado no meio da semana, ela pega o celular e o item precisa entrar na
  lista em segundos, sem passar por cadastro de produto nenhum.
- `*` **A busca é sobre os tipos de produto já cadastrados**, não sobre
  produtos: quem entra na lista é "leite", nunca "leite Italac 1L" — marca e
  embalagem são preferências, e moram no diálogo de edição da Tela 1. A lista
  filtra enquanto ele digita e vem **agrupada por categoria**, a mesma ordem das
  Telas 1, 2 e 6.
- `*` **Tipo que já está na lista aparece travado** (`[–]`), pelo mesmo motivo
  do `{–}` da Tela 2: item repetido na lista não ajuda ninguém no corredor.
- `*` **A busca compara ignorando maiúsculas, espaço sobrando e acento**
  (decisão de 26/08/2026), e é por isso que o `[ + Criar "…" ]` só aparece quando
  nada bate **de verdade**: quem digita "acem moido" encontra "acém moído", e não
  cria um segundo tipo. O tipo é o nível que soma — dois "achocolatado" partem a
  lista em dois grupos, dividem a média pela metade e fazem a compra de um não
  abater o item do outro, sem que rename nenhum junte depois. É a mesma proteção
  da marca, do mercado e do cadastro de produto, com o acento a mais porque é o
  que se perde digitando com pressa. **Categoria segue a mesma regra**, no
  `[+Novo]↻` do mini-cadastro.
- `*` **Tipo desativado aparece na busca, marcado como desativado**, com
  `[ Reativar ]↻` no lugar do toque que adiciona. Sem isso, desativar viraria o
  caminho mais curto para rachar o histórico que ele existe para preservar: quem
  desse falta do tipo não o encontraria e criaria outro com o mesmo nome.
- `*` **Quando nada bate, a última linha vira `[ + Criar "…" ]`** com o que ele
  digitou. É o mesmo padrão do mercado novo dentro do lançamento (Tela 3) e da
  marca nova dentro do cadastro (Tela 4): o cadastro que faltou nasce onde deu
  falta, sem sair da tela. Sem isso, lembrar de algo que nunca compraram —
  justamente o que mais se esquece — obrigaria a abrir o cadastro completo de
  produto no meio da semana.
- `*` **O mini-cadastro pede três coisas e para:** nome, categoria e unidade
  base. Não pede marca, descrição nem embalagem, porque **não é cadastro de
  produto** — é o tipo, que é o que a lista precisa para agrupar (requisito 11)
  e para dar baixa quando a compra chegar. O produto de verdade nasce na
  primeira compra, na Tela 4.
- `*` **Categoria também é criável na hora**, pelo `[+Novo]↻`, num diálogo de um
  campo só. Sem ele, o primeiro item de uma categoria nova ficaria sem lugar.
- `*` **A unidade base é obrigatória e não tem padrão adivinhado.** As três
  opções abrem em branco e o `[ Criar e adicionar ]` fica travado (`[–]`) até uma
  ser escolhida — corrigido na 2.0, quando o quadro ainda abria com o "kg" já
  marcado. É ela que decide se a quantidade da lista é em quilos, litros ou
  unidades, e trocá-la depois é o único caminho sem volta do cadastro
  (requisito 16): um padrão adivinhado justamente aqui deixaria quem criou o
  tipo às pressas com um achocolatado medido em quilo para sempre. Três opções,
  um toque.
- **`[ Criar e adicionar ]` faz as duas coisas:** cria o tipo e já põe o item na
  lista, fechando o painel. Ele volta para a Tela 1 com o item lá, dentro do
  grupo da categoria escolhida.
- **O item entra sem quantidade** — e item sem quantidade sai da lista na
  primeira compra daquele tipo (Tela 1). Quem quiser pedir "6 litros" toca no
  item depois. Foi a decisão de 26/08/2026: o caso comum é "acabou o
  achocolatado", que não tem quantidade nenhuma para informar.

**Estados:**
- Busca vazia: mostra os tipos mais comprados por eles, agrupados por categoria
  — abrir o painel já dá o que tocar, sem digitar nada.
- Sistema vazio (primeiras semanas): "Nenhum tipo cadastrado ainda" e o
  `[ + Criar "…" ]` aparece assim que ele digitar a primeira letra.
- **Bateu com um tipo desativado:** a linha aparece com "(desativado)" e
  `[ Reativar ]↻`; o `[ + Criar "…" ]` não aparece, porque o nome já existe.
- Carregando: "Buscando..." no lugar da lista.
- Erro: "Não foi possível buscar os tipos" + `[ Tentar de novo ]↻`. Nada é
  criado sem conexão — o painel não guarda rascunho, ao contrário da Tela 3.

---

## Tela 2 — Sugestão de itens  `#2`

```
┌──────────────────────────────────────┐
│ < Voltar   Sugestão de itens         │
├──────────────────────────────────────┤
│  Baseado no que compraram nos        │
│  três meses fechados anteriores   *  │
│  ────────────────────────────        │
│  Higiene                             │
│  {x} Papel higiênico — 12 un         │
│  ────────────────────────────        │
│  Laticínios                          │
│  {–} Leite (já está na lista)     *  │
│  ────────────────────────────        │
│  Limpeza                             │
│  {–} Detergente (não encontrei)   *  │
│  ────────────────────────────        │
│  Mercearia                           │
│  { } Arroz — 5 kg                    │
│  { } Café — 700 g                 *  │
│                                      │
│  [   Adicionar selecionados   ]→1    │
└──────────────────────────────────────┘
```

**Notas:**
- As caixas aqui são de **escolha** (`{ }`), não de estado: marcar significa
  "este entra na lista", e não "já peguei no corredor".
- **A tela abre com tudo desmarcado**, e o quadro acima mostra o estado **depois**
  de ele marcar o papel higiênico — o mesmo cuidado que o `#3a` tem com as linhas
  dele. Nada vem pré-selecionado de propósito: a sugestão oferece todo tipo
  comprado ao menos uma vez na janela, e abrir com tudo marcado faria
  `[ Adicionar selecionados ]` despejar a sugestão inteira na lista com um toque
  — que é o oposto de "quem decide o que é rotina é ele".
- `*` **A lista é agrupada por categoria**, em ordem alfabética dentro de cada
  uma — a mesma organização da Tela 1, e não "do mais comprado para o menos
  comprado". Cada tipo tem a sua unidade base, então as quantidades não são
  comparáveis entre si: `12 un` de papel higiênico não é "mais" que `5 kg` de
  arroz, e ordenar por elas produziria uma lista sem sentido. Por categoria, ele
  lê a sugestão na mesma ordem em que vai andar no corredor. Nenhum tipo é
  escondido por ser compra rara.
- `*` A janela é a dos **três meses fechados anteriores**, e a sugestão traz
  também o tipo que nasceu **no mês em curso** — ele não tem compra na janela,
  mas é justamente quem mais precisa aparecer.
- `*` Quantidade sugerida é o consumo dos **três meses fechados anteriores**
  dividido pelos **meses fechados de história que aquele produto tem ali
  dentro**, no máximo 3 — o mês em curso fica de fora da janela (é a **janela
  fechada**; ver a Tela 6, onde ela está declarada). O café, que eles já
  compravam antes, divide por 3 e aparece com 700 g mesmo comprado uma vez só;
  um produto cuja primeira compra foi em junho divide por 2; e um que estreou no
  último mês fechado divide por 1. Dentro da vida do produto, mês sem compra
  continua contando zero. **O produto nascido no mês em curso não divide nada:**
  ele não tem mês fechado, o total dele dentro da janela é zero, e a média é o
  que ele comprou neste mês. O ajuste da quantidade é feito depois, na Tela 1,
  tocando no item.
- `*` **Todo item que já está na lista aparece aqui travado**, e o quadro é um
  recorte: dos cinco itens da Tela 1, ele mostra dois — o leite, que está lá
  esperando, e o detergente, marcado como "não encontrei". Acém moído, frango e
  sabão em pó estariam travados do mesmo jeito, fora do recorte.
- `*` Item já presente na lista aparece travado (`{–}`) — não responde ao
  toque e não pode ser adicionado de novo. Vale inclusive para o item marcado
  como "não encontrei", que continua na lista.
- A sugestão trabalha só no **tipo de produto** e nunca propõe marca nem
  embalagem: ela vem do consumo somado dos 3 meses, que junta todas as marcas e
  todos os tamanhos. Quem quiser uma preferência a acrescenta depois, na Tela 1.

**Estados:**
- Carregando: "Calculando o que vocês costumam comprar...".
- Sem histórico suficiente: "Ainda não há compras suficientes para sugerir
  nada" (sem botão de ação).
- Erro: "Não foi possível carregar a sugestão" + `[ Tentar de novo ]↻`.

---

## Tela 3 — Lançar compra  `#3`

```
┌──────────────────────────────────────┐
│ < Voltar   Lançar compra             │
├──────────────────────────────────────┤
│  Data: ▤ 18/08/2026               *  │
│  Mercado: ▼ Selecione   [+Novo]↻ *   │
│  ────────────────────────────        │
│  Produto: ▼ Coca 12x350ml [+Novo]→4  │
│  [ Comparar custo ]→3a            *  │
│  Quantidade: 1   Valor: R$ 56,70  *  │
│  ⚠ Subiu 18% sobre a média        *  │
│  [    + Adicionar à compra    ]↻     │
│  ────────────────────────────        │
│  Itens desta compra               *  │
│  • Leite Italac 1L  12 R$62 [ed]↻    │
│  • Omo 500g          1 R$10,00 [ed]↻ │
│  ────────────────────────────        │
│  Total da compra:        R$ 72,00    │
│                                      │
│  [       Salvar compra       ]→1 *   │
└──────────────────────────────────────┘
```

**Notas:**
- `*` **Data não aceita datas futuras** (confirmado por ele em 26/08/2026): o
  calendário abre no dia de hoje e **os dias posteriores nem podem ser tocados**
  — não é aviso que dá para atropelar. Data anterior é aceita normalmente, para
  lançar compra esquecida. Deixar passar por aviso mandaria o gasto para o mês
  seguinte no primeiro escorregão de dedo, errando o relatório dos dois meses e
  o aviso do teto junto.
- `*` Mercado novo é cadastrado em um diálogo aqui mesmo, com um campo só (o
  nome), sem sair da tela — é o requisito 15. Não existe tela separada de
  mercado. **O diálogo recusa nome repetido**, pela mesma comparação do tipo e da
  marca — ignorando maiúsculas, espaço sobrando e acento —, e aponta o mercado
  que já existe: "Carrefour" e "carrefour" nunca viram dois.
- Cada item já adicionado tem `[ed]↻` (editar), que abre o item para correção
  ou remoção antes de salvar.
- `*` **O campo é um só: "Quantidade".** Não existe rótulo dizendo "fardo",
  "pacote" ou "caixa" — quem informa o que está sendo contado é o **nome da
  embalagem** no campo acima: escolhido "Coca 12x350ml", digitar 2 são duas
  embalagens de 12 latas, e o sistema fecha em 8,4 litros. Um rótulo variável
  seria mais uma palavra para ler em cada item, contra a meta de 2 minutos.
  Produto vendido a peso é a única exceção: ali o campo vira **"Peso (kg)",
  "Volume (L)" ou "Quantidade (un)", conforme a unidade base do tipo** (decisão
  de 26/08/2026), porque o que ele copia do cupom é a quantidade medida, não uma
  contagem de embalagens. O rótulo segue a unidade, e não o quilo, senão "a peso"
  só serviria em tipo medido em quilo: o azeite a granel — sem embalagem para
  cadastrar e sem tipo de outra grandeza onde caber — ficaria sem caminho, e o
  único jeito de lançá-lo seria somar volume dentro de um tipo medido em peso. É
  a mesma régua do título do `#3a`, que já troca entre "custo por kg", "por
  litro" e "por unidade".
- `*` O fardo tem **dois caminhos igualmente válidos**: escolher o produto "Coca
  12x350ml" e digitar 1, ou escolher "Coca 350ml" e digitar 12. Os dois fecham
  em 4,2 litros. O que muda é o histórico de preço, que é separado por produto —
  e é por isso que a comparação entre fardo e lata avulsa mora na visão "Tipo
  inteiro" da Tela 5, nunca no alerta de alta.
- `*` **"Itens desta compra" fica ABAIXO do bloco que se digita**, e não entre
  o Mercado e o Produto como até a 2.0. A lista cresce a cada item lançado, e o
  que cresce empurrava Produto, Quantidade e Valor — os três campos do caminho
  normal, os mesmos da nota seguinte — para debaixo do teclado: numa compra de
  vinte itens o campo Produto nascia fora da tela. Daqui para baixo tudo é
  leitura — a lista já lançada, o total, o botão de salvar — e leitura pode
  descer. É a regra do tamanho da tela, nas Convenções de notação.
- `*` **A ordem de preenchimento é produto → quantidade → valor**, e os três
  campos ficam logo abaixo do Mercado, no topo da tela. Escolhido o
  o produto, o app guarda o **preço da unidade base** da última compra dele em
  qualquer mercado e, a cada mudança na quantidade, recalcula o valor total
  sozinho: **quantidade convertida para a unidade base × preço da unidade
  base**. Doze caixas de leite de 1 L são 12 litros × R$ 5,17 = R$ 62; um fardo
  "Coca 12x350ml" é 4,2 litros × R$ 11,43 = R$ 48. Multiplicar a quantidade de
  embalagens direto pelo preço da unidade base só fecharia por acaso, no caso em
  que a embalagem tem exatamente uma unidade base dentro. O campo que ele de
  fato edita é sempre o **valor total pago no item**; a partir do momento em que
  ele digita esse valor à mão, o recálculo automático para de mexer nele.
- `*` **`[ Comparar custo ]→3a` é opcional e não faz parte do caminho normal.**
  Ele responde "qual embalagem rende mais por real" antes de o produto ser
  escolhido em definitivo — é o requisito 17. Quem nunca tocar nele lança a
  compra exatamente como antes, em produto → quantidade → valor. O botão **só
  aparece quando o tipo do produto tem duas opções ou mais**; com uma só, não há
  o que comparar e ele some da tela. **Opção é qualquer produto ativo do tipo,
  embalado ou vendido a peso**: a mussarela do balcão conta como uma, e é assim
  que ela é confrontada com a fatiada em pacote. Tipo com um único produto a
  peso — acém moído sozinho — continua sem botão, porque não há duas linhas para
  comparar; confrontar o quilo de dois mercados é pergunta da Tela 5. O `#3a` **abre como painel sobre esta
  tela**, sem tirá-la de vista, e fechar devolve o cursor onde ele estava.
- `*` O aviso de alta é o único que aparece **durante** a digitação, porque
  depende só do item que está sendo preenchido: dispara quando o preço da
  unidade base ficar **10% ou mais** acima da média dos últimos 3 meses do
  mesmo produto (ou do tipo, quando o produto não tem marca) — pela **janela
  rolante**, que inclui o mês em curso. **Ele só aparece depois de quantidade e
  valor preenchidos**, que é de onde sai o preço da unidade base: no quadro
  acima, 1 fardo por R$ 56,70 dá R$ 13,50 o litro contra R$ 11,43 de média.
  Campo vazio não tem alerta nenhum.
- `*` Os outros dois avisos — item repetido e teto do mês — só podem ser
  calculados **depois** de salvar, e por isso estão em Estados, não no quadro.

**Estados:**
- **Carregando:** os campos "Mercado" e "Produto" mostram "Carregando..." e não
  abrem até as listas chegarem — as duas vêm de fora do celular. O que já estiver
  digitado na tela, inclusive o rascunho recuperado, continua visível e editável.
- **Sistema vazio (primeiras semanas):** sem nenhum mercado cadastrado, o campo
  "Mercado" mostra "Nenhum mercado ainda — cadastre o primeiro" e o `[+Novo]↻`
  fica em destaque; sem nenhum produto cadastrado, "Produto" mostra "Nenhum
  produto ainda — cadastre o primeiro", apontando para `[+Novo]→4`. É o estado
  do dia 1: o sistema começa vazio e cada produto nasce na primeira compra.
- **Sem base de comparação:** produto sem nenhuma compra nos últimos 3 meses
  não mostra aviso de alta nenhum — o sistema fica quieto em vez de comparar
  com produto parecido. Também não há valor a pré-preencher: o campo "Valor
  total" abre vazio.
- Salvando: botão vira "Salvando..." e desabilita.
- **Sem conexão, com itens digitados:** faixa fixa no topo — "Sem conexão. Esta
  compra está guardada no aparelho e será salva quando o sinal voltar" — e o
  botão vira `[ Salvar quando voltar o sinal ]↻`. **Nada é perdido:** data,
  mercado e todos os itens continuam na tela, e continuam lá depois de fechar o
  app. É a decisão de 26/08/2026, e a única parte do sistema que funciona sem
  sinal.
- **Rascunho recuperado:** abrindo a Tela 3 com um lançamento inacabado no
  aparelho, ela abre com ele — "Compra de 18/08 no Carrefour, 18 itens, não
  salva" — e dois botões: `[ Continuar ]↻` e `[ Descartar ]↻`. O rascunho é
  local e de quem está com o aparelho: não aparece no celular do outro e não
  existe como compra até ser salvo.
- **Salvo com sucesso:** o rascunho é apagado na hora, para não haver como
  salvar a mesma compra duas vezes.
- **Voltando da Tela 4:** vem selecionada no campo "Produto" **a embalagem que
  ele marcou como "comprando agora"** — não a primeira da lista, e não todas.
  As outras embalagens salvas no mesmo cadastro ficam disponíveis no seletor,
  para quando ele levar mais de um tamanho na mesma compra. O cursor já cai na
  quantidade.
- **Item que veio da lista com preferência:** ao escolher um tipo de produto que
  está na lista com marca e embalagem marcadas, o campo "Produto" já abre naquela
  embalagem — ele confirma ou troca ali mesmo, com um toque. Trocar não deixa
  nada pendente: a baixa da lista é pelo tipo do produto.
- **Ao salvar, item repetido:** se algum tipo de produto desta compra também
  foi comprado no mesmo dia pela outra pessoa, mostra "⚠ Vocês dois compraram
  leite hoje" antes de voltar para a Tela 1 — ou "⚠ Vocês dois compraram leite
  no dia 25/08", quando a compra lançada é de ontem. **Só aparece em compra de
  hoje ou de ontem** (decisão de 26/08/2026): em lançamento antigo não há mais
  nada a decidir, e lançar cupons atrasados viraria uma fila de avisos. Texto
  neutro de propósito — o aviso é retroativo e não sabe quem comprou primeiro.
  Informativo: não bloqueia nem desfaz nada.
- **Ao salvar, teto do mês:** se esta compra fizer o mês cruzar 80% do teto,
  mostra "⚠ O gasto do mês passou de 80% do teto"; se cruzar 100%, mostra
  "⚠ O teto do mês estourou". Cada um aparece **uma vez só por mês** — as
  compras seguintes não repetem. Também não bloqueia o salvamento.
- **Os dois avisos na mesma compra:** aparecem **juntos, empilhados na mesma
  tela de confirmação**, o do teto em cima e o de item repetido embaixo, com um
  único botão `[ Entendi ]→1`. Nunca em sequência: dois toques a mais no fim do
  lançamento pesam contra a meta de 2 minutos.
- Erro: "Não foi possível salvar, tente de novo".

---

## Diálogo `#3a` — Comparar custo  (painel sobre a Tela 3)

```
┌──────────────────────────────────────┐
│ Lançar compra          (fica atrás)  │
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────────────────────────────────┤
│  ══   Comparar custo        [ X ]→3  │
│  sabão em pó · custo por kg       *  │
│  ────────────────────────────        │
│      produto       preço    /kg  dif │
│  {x} Omo 500g   R$ 10,00  20,00 −28%*│
│  {x} Omo 2,3kg  R$ 33,00 ★14,35     *│
│  { } Tixan 1kg  R$ 17,00            *│
│  [ Ver todas do tipo ]↻            * │
│         ↕ rola se tiver mais         │
├──────────────────────────────────────┤
│  ★ Omo 2,3kg — 28% mais barato o kg* │
│  [     Usar Omo 2,3kg     ]→3      * │
└──────────────────────────────────────┘
```

**Notas:**
- **É um painel ancorado na parte de baixo da tela, não uma tela nova.** O
  lançamento continua atrás, esmaecido, e fechar devolve o cursor onde ele
  estava. É o que mantém claro que a calculadora é um desvio de dez segundos, não
  um lugar onde se entra. **Ele aparece e some sem animação nenhuma** — a
  especificação do PWA proíbe transição, e aqui ela não faz falta: o que importa
  é o lançamento continuar visível atrás, não o movimento de entrada.
- **A tela é dividida em três faixas, e só a do meio rola:** cabeçalho fixo em
  cima (o tipo e a unidade da conta), lista rolando no meio, **rodapé fixo
  embaixo com o veredito e o botão**. Numa tela de celular pequena, o resultado
  nunca sai de vista por causa da rolagem — que era o risco de pôr uma tabela
  dentro de um aparelho de 5 polegadas.
- `*` **O título diz em que unidade a conta é feita** — "custo por kg", "custo
  por litro", "custo por unidade" —, porque é a unidade base do tipo que manda,
  não o tamanho de nenhuma das embalagens. A coluna `/kg` troca de rótulo junto:
  `/L` no leite, `/un` no ovo.
- **As colunas são fixas e alinhadas**: produto, preço digitado, quantidade,
  custo por unidade base e diferença. É o alinhamento que deixa a comparação ser
  feita com o olho, descendo a coluna, sem ler linha por linha. **A coluna da
  quantidade existe em todas as linhas** — com campo na linha vendida a peso,
  vazia e do mesmo tamanho nas outras (decisão **F-n**): sem essa reserva, o
  custo mudaria de lugar de uma linha para a outra e a coluna deixaria de poder
  ser descida com o olho.
- `*` **Não existe botão "Comparar".** O custo por unidade base de cada linha
  **marcada** aparece **enquanto ele digita**, à direita do preço, e o `★` pula
  sozinho para a linha mais barata a cada mudança. Sem segunda etapa, sem tela de resultado,
  sem toque a mais: trocar um preço já reordena a resposta.
- `*` **A lista abre curta: só os produtos do tipo comprados nos últimos 3
  meses**, pela **janela rolante** (com o mês em curso dentro — a compra da
  semana passada é justamente a que ele quer ver aqui), **todos com preço já
  preenchido**. `[Ver todas do tipo]↻` abre o resto — os produtos cadastrados
  que ele nunca comprou ou não compra há meses, esses sim com o preço vazio. No
  quadro acima, Omo 500g, Omo 2,3kg e Tixan 1kg foram comprados na janela e
  abrem com preço; Tixan 2kg só aparece depois do `[Ver todas do tipo]`.
- `*` **O preço de cada linha é o de _uma_ embalagem** — o valor total daquele
  item na última compra dividido pela quantidade. Três pacotes de Omo 500g
  comprados juntos por R$ 30 abrem a linha com R$ 10,00, nunca com R$ 30. É a
  mesma conta que pré-preenche o lançamento (requisito 3).
- `*` **Só a linha do produto que estava sendo lançado abre marcada**; o quadro
  acima mostra o estado **depois** de ele marcar a segunda — é ele quem monta a
  comparação, de duas linhas para cima. Linha não marcada não concorre ao `★` e
  não mostra `/kg` nem `dif`, mesmo com o preço preenchido: o Tixan 1kg está ali
  para ser marcado com um toque, não para entrar na conta sozinho. **Produto desativado não aparece em nenhuma das duas listas**, pela
  mesma regra do requisito 16: quem sumiu da tela de lançamento não volta por
  aqui. É o que impede um tipo com 20 embalagens de virar uma lista de 20 linhas
  logo na abertura, mostrando as 3 ou 4 que ele de fato usa.
- `*` **Linha marcada sem preço não entra na conta** e não mostra custo nenhum —
  fica esperando ele digitar. **Duas linhas com preço já bastam** para o `★` e o
  rodapé aparecerem.
- **Se a lista curta ficar com menos de duas linhas, ela já abre inteira.**
  Comprou só o Omo 500g nos últimos 3 meses, num tipo que tem quatro embalagens
  cadastradas? O painel abre com as quatro, sem o `[Ver todas do tipo]`. Abrir
  uma calculadora com uma linha só seria abrir sem nada para comparar.
- **A lista traz os produtos do tipo, de qualquer marca**, de propósito: quem
  decide o que é comparável é ele, não o sistema. Diz "produtos", e não
  "embalagens", porque o vendido a peso não tem embalagem nenhuma e mesmo assim
  entra. Produto que não existe no cadastro **não pode ser comparado aqui** — ela vira produto pela Tela 4
  primeiro, como qualquer outra, para a calculadora não criar produto por uma
  porta lateral.
- Produto vendido **a peso** entra como mais uma linha, e ali o preço digitado
  **já é o da unidade base do tipo** — o quilo da mussarela do balcão, o litro do
  azeite a granel —, porque não há conteúdo a dividir. É assim que a mussarela do
  balcão é confrontada com a fatiada em pacote.
- `*` **Essa linha, e só ela, tem um campo de quantidade ao lado do preço**
  (decisão **F-m**), que abre em `1 kg` / `1 L` / `1 un`. Ele existe para o caso
  que sem ele não tem resposta: a bandeja de frango de 800 g e a de 1 kg são a
  **mesma folha** vendida a peso — uma linha só —, e sem dizer quanto a bandeja
  tem não há como confrontar as duas. Enquanto o campo diz `1`, o painel faz
  exatamente a conta que sempre fez.
- `*` **Apagar o campo tira a linha da conta**: ela fica esperando, igual à
  linha marcada sem preço, e **nunca volta a valer 1 kg por baixo do pano**. Um
  custo plausível e errado é o pior desfecho de uma calculadora.
- `*` **O preço e a quantidade são um par.** A linha a peso abre com o preço da
  **unidade base** da última compra — o preço do quilo, não o da bandeja —,
  então quem digita `0,8` na quantidade tem de corrigir o preço junto. O campo é
  um convite a corrigir os dois, não uma pergunta a responder antes de usar.
- `*` **A linha com embalagem cadastrada não tem campo nenhum**: o conteúdo é o
  do cadastro, e digitar outro ali seria dizer que o cadastro está errado — o
  lugar de consertar cadastro é a Tela 4.

O frango, que é o caso que pede o campo:

```
┌──────────────────────────────────────┐
│  ══   Comparar custo        [ X ]→3  │
│  frango · custo por kg            *  │
│  ────────────────────────────        │
│   produto      preço    qtd   /kg dif│
│  {x} Frango (a peso)                 │
│      R$ 12,00 [0,8 kg] 15,00  −3%   *│
│  {x} Frango congelado 1 kg           │
│      R$ 14,50 (      ) ★14,50       *│
├──────────────────────────────────────┤
│  ★ Frango congelado 1 kg — 3% mais   │
│    barato o kg                       │
│  [ Usar Frango congelado 1 kg ]→3    │
└──────────────────────────────────────┘
```
- `*` **Essa linha, e só ela, tem um campo de quantidade ao lado do preço**
  (decisão **F-m**). Ele **abre em `1 kg` / `1 L` / `1 un`**, que é o que a linha
  a peso sempre valeu, e serve para confrontar bandejas de tamanhos diferentes:
  a de frango de 800 g contra o pacote congelado de 1 kg é a **mesma folha**
  vendida a peso, e sem o campo as duas não teriam como ser comparadas.
  **Apagar o campo tira a linha da conta** — ela fica esperando, como a linha
  marcada sem preço, e nunca volta a valer 1 kg por baixo dos panos.
  A coluna existe em **todas** as linhas: nas que têm embalagem ela fica
  **vazia**, e é isso que mantém o custo e o `−%` no mesmo lugar (decisão
  **F-n**) — o quadro do sabão em pó acima é justamente esse caso, com a coluna
  em branco nas três linhas.

  ┌──────────────────────────────────────┐
  │  ══   Comparar custo        [ X ]→3  │
  │  frango · custo por kg               │
  │  ────────────────────────────        │
  │   produto     preço    qtd   /kg dif │
  │  {x} bandeja  R$12,00 [0,8]kg 15,00  │
  │  {x} cong.1kg R$14,50   ( )  ★14,50  │
  ├──────────────────────────────────────┤
  │  ★ cong.1kg — 3% mais barato o kg    │
  │  [      Usar cong.1kg      ]→3       │
  └──────────────────────────────────────┘

- `*` **O rodapé diz quanto o melhor custo sai mais barato** que a pior linha em
  comparação: `(preço da linha − melhor preço) ÷ preço da linha`, os dois na
  unidade base, arredondado para o inteiro. **O mesmo `−%` fica ao lado de cada
  linha perdedora, sempre** — com duas opções ou com dez, sem exceção por
  contagem. O rodapé repete a maior diferença em frase. Uma fórmula só, que
  continua legível com dez linhas na tela: o Omo de 2,3 kg a R$ 14,35 o quilo
  sai **28% mais barato** que o de 500 g a R$ 20,00 o quilo. **A porcentagem é
  calculada sobre os valores cheios, não sobre os arredondados que aparecem na
  tela** — o custo do 2,3 kg é R$ 14,3478, e é ele que entra na conta; arredondar
  antes muda a resposta em um ponto inteiro quando a diferença cai perto do meio
  ponto.
- `*` `[ Usar Omo 2,3kg ]→3` fecha o painel **com aquele produto já selecionado**
  no lançamento e o cursor na quantidade. `[ X ]→3` fecha sem mexer em nada.
  **A calculadora sugere; quem decide é ele** — se cabe no armário, se vence
  antes e se a família prefere a outra marca são coisas que a conta não enxerga.
- **Trocar o produto por aqui é igual a trocá-lo no seletor:** o preço sugerido
  volta a ser o da última compra do produto novo, o **aviso de alta se refaz
  contra o histórico dele**, e item que veio da lista com preferência não fica
  pendente — a baixa continua sendo pelo tipo do produto.
- **Nada digitado aqui vira registro.** Preço corrigido na calculadora não entra
  no histórico, não muda preço médio, não dispara alerta de alta e não sobrevive
  ao fechamento. **Vale igual para a quantidade**: ela não volta pré-preenchida
  para o campo Quantidade da Tela 3, e `[ Usar… ]` devolve só o produto
  escolhido. Quem grava preço é o lançamento.

**Estados:**
- **Carregando:** a faixa do meio mostra "Buscando os preços que vocês
  pagaram..." — a lista e os preços da última compra de cada linha vêm de fora do
  celular. O cabeçalho com o tipo e a unidade já aparece; o rodapé fica vazio até
  haver duas linhas com preço.
- **Menos de duas linhas com preço:** o rodapé mostra "preencha o preço de duas
  opções" e o botão `[Usar…]` fica travado (`[–]`). Nenhum `★` aparece.
- **Empate técnico:** quando a diferença entre a primeira e a segunda for
  **menor que 1%**, nenhuma linha recebe `★` e o rodapé responde "custo
  praticamente igual" — em vez de eleger um vencedor por diferença de centavo.
  **O botão `[Usar…]` continua**, apontando para a de menor custo: o sistema para
  de afirmar vantagem, mas não tira dele a saída de escolher sem fechar o painel.
- **Sem compra nenhuma do tipo nos últimos 3 meses:** a lista já abre com todas
  as embalagens cadastradas, sem o `[Ver todas do tipo]`, e o rodapé mostra
  "digite os preços que você está vendo". A calculadora não depende de compra
  anterior — o histórico só poupa digitação quando existe.
- **Tipo com uma opção só:** o painel não abre — o botão `[Comparar custo]` nem
  aparece na Tela 3.
- Erro: "Não foi possível calcular, tente de novo".

---

## Tela 4 — Novo produto  `#4`

```
┌──────────────────────────────────────┐
│ < Voltar   Novo produto              │
├──────────────────────────────────────┤
│  Categoria: ▼ Bebidas   [+Novo]↻  *  │
│  Tipo: ▼ refrigerante   [+Novo]↻  *  │
│  Unidade: litro (vem do tipo)     *  │
│                                      │
│  Vendido: (Peso)(•Unidade)(Volume)*  │
│                                      │
│  Marca: ▼ Coca-Cola   [+Novo]↻    *  │
│  Descrição: original              *  │
│  ────────────────────────────        │
│  Embalagens deste produto         *  │
│  Peças   Cada unidade   Fica como *  │
│   1 × [ 350 ]▼ml   350ml   (•) [x]↻  │
│   1 × [ 269 ]▼ml   269ml   ( ) [x]↻  │
│   1 × [   2 ]▼L    2L      ( ) [x]↻  │
│  12 × [ 350 ]▼ml  12x350ml ( ) [x]↻  │
│  [   + Adicionar embalagem   ]↻      │
│                                      │
│  [    Salvar 4 produtos    ]→3    *  │
└──────────────────────────────────────┘
```

**Notas:**
- `*` **Categoria e Tipo têm `[+Novo]↻`, como a Marca** (decisão de
  26/08/2026). A categoria abre um diálogo de um campo só, igual ao do mercado e
  ao da marca; o tipo abre o **mesmo mini-cadastro do `#1a`** — nome, categoria e
  unidade base —, e o tipo criado já volta escolhido aqui. Até a 1.9 os dois eram
  só `▼`, e o modo "nova" existia apenas enquanto o sistema estivesse
  inteiramente vazio: depois do primeiro cadastro salvo, a primeira compra de uma
  categoria nova — a primeira fralda, o primeiro item de padaria — travava com o
  cupom na mão, obrigando a sair do lançamento, criar o tipo pela lista e voltar,
  perdendo o que já tinha digitado. Os três campos passam a ter o mesmo padrão:
  escolhe da lista ou cria ali — o rótulo do campo encurtou de "Tipo do produto"
  para "Tipo" só para caber o botão, e a coluna inteira continua se lendo como a
  hierarquia: Categoria, Tipo, Marca, Descrição. **A trava de duplicidade do
  `#1a` vale igual aqui** — comparação ignorando maiúsculas, espaço sobrando e
  acento, e o
  desativado oferecido para reativar em vez de nascer de novo.
- `*` **A unidade base pertence ao tipo do produto, não ao produto.** Ela aparece
  sempre como texto fixo, sem edição — dois produtos do mesmo tipo não podem ter
  unidades diferentes, senão o consumo do tipo para de somar. Quem define a
  unidade de um tipo novo é o mini-cadastro do `[+Novo]↻` do Tipo, e não esta
  tela: é lá que ela é obrigatória e não tem padrão adivinhado.
- `*` **Cada linha da lista de embalagens é `peças × medida da peça`**, e a
  coluna ao lado mostra **como aquela embalagem vai se chamar** em toda tela:
  "350ml" quando é uma peça só, "12x350ml" quando são doze. É esse nome que ele
  procura no lançamento, e é ele que dispensa qualquer rótulo de "fardo" ou
  "pacote". Na embalagem de uma peça só, o "1 ×" é o padrão e não precisa ser
  tocado.
- `*` **A medida tem a unidade escolhida ao lado do número**, e a lista oferece
  só a família do tipo: `▼ g / kg` quando a unidade base é quilo, `▼ ml / L`
  quando é litro. As quatro nunca aparecem juntas — poder digitar "350 ml" num
  tipo medido em quilo faria o total daquele tipo somar volume com peso, e é esse
  total que sustenta todo o relatório. A unidade escolhida na primeira linha já
  vem sugerida nas seguintes, porque quase sempre é a mesma.
- `*` **A tela mostra sempre o que ele digitou.** "350 ml" continua "350 ml" no
  nome do produto e na lista de embalagens; a conversão para litro acontece por
  baixo, só para as contas. É o nome da prateleira que ele procura no lançamento,
  não "0,35 L".
- `*` **Tipo medido em unidade não pede medida.** Em ovo, papel higiênico e sabão
  em barra a linha fica só com a contagem — "12 un", "4 un" —, porque a unidade
  base já é a própria peça. Um campo de medida aparece ao lado, vazio e opcional,
  para ele anotar "30 m cada" se quiser: é lembrete, não entra em conta nenhuma.
- `*` **A linha "12x350ml" é o fardo**, e o sistema fecha nela 4,2 L.
  Cadastrá-la vale quando o cupom traz o fardo como uma linha só, com preço
  fechado; quem compra lata solta lança 12 vezes a linha "350ml" e chega aos
  mesmos 4,2 litros.
- `*` **Cada linha vira um produto próprio ao salvar**, com preço e histórico
  separados — por isso o botão diz quantos produtos vão nascer. É o que resolve
  ter que refazer o cadastro inteiro quatro vezes para o mesmo refrigerante.
- `*` **O rádio marca qual embalagem ele está comprando agora**, e é só ela que
  volta selecionada na Tela 3. Ele já nasce na **primeira linha** e nunca fica
  vazio — parar o lançamento para perguntar "qual delas?" custaria mais do que
  errar e trocar no seletor. Sem isso, salvar quatro embalagens deixaria a
  Tela 3 sem saber qual escolher, e ele perderia na busca o tempo que este
  cadastro economizou.
- `*` **Duas linhas idênticas são recusadas na hora**, com "essa embalagem já
  está na lista" — e **idêntica é pelo conteúdo, não pelo texto**: `1 × 0,35 L`
  bate com `1 × 350 ml` e é recusada, porque a comparação acontece depois da
  conversão. A mesma recusa vale agora **contra o que já está salvo**, quando a
  tela é aberta sobre um produto existente.
- `*` **O cadastro de um produto é único: tipo + marca + descrição** (decisão de
  26/08/2026). Com os três batendo com algo já cadastrado, a tela avisa assim que
  a descrição sai do foco e **trava o salvar**, oferecendo abrir o cadastro que
  já existe (ver o estado abaixo). A descrição entra na identidade porque separa
  "Coca-Cola zero" de "Coca-Cola original", e **em branco também conta como
  valor** — duas Coca-Cola sem descrição no mesmo tipo são o mesmo produto. A
  embalagem fica de fora: ela é o que se acrescenta depois. Sem essa trava, o
  segundo "Coca-Cola 350ml" partiria o histórico de preço em dois, como
  "Carrefur" partiria o do mercado, e nenhum rename depois junta o que nasceu
  separado.
- `*` **O campo tem TRÊS palavras — `Peso`, `Unidade`, `Volume` — e só a
  grandeza do tipo fica clicável ao lado de `Unidade`** (decisão de
  01/09/2026, divergência **H-a**). `Peso` e `Volume` são a mesma marcação de
  produto solto, e quem os separa é a unidade base do tipo: num tipo medido em
  quilo o clicável é `Peso`, num tipo medido em litro é `Volume`, e num tipo
  contado por unidade sobra só `Unidade`. A palavra antiga, "A peso", não
  nomeava o azeite a granel, que é medido em **litro**. No banco continuam
  existindo **dois** modos, não três.
- `*` **`Peso` ou `Volume` faz a lista de embalagens sumir da tela** — não fica
  linha nenhuma, e o botão volta a ser `[ Salvar produto ]`. Quem informa a
  quantidade é o lançamento, não o cadastro. É o caso do acém moído e da
  mussarela do balcão. **A marcação vale em qualquer unidade base** (decisão de
  26/08/2026): ela diz que não há embalagem a contar, não que a grandeza seja o
  quilo. Num tipo medido em litro — azeite a granel —, o lançamento pede
  "Volume (L)"; num medido em unidade, "Quantidade (un)". Presa ao quilo, ela
  deixaria esses produtos sem caminho: sem embalagem para cadastrar e sem tipo de
  outra grandeza onde caber.
- `*` **A marca é escolhida de uma lista das já cadastradas**, com `[+Novo]↻` ao
  lado para cadastrar uma na hora, num diálogo de um campo só — igual ao mercado
  da Tela 3, e pelo mesmo motivo: a marca agrupa e compara preço, e "Omo" e "OMO"
  digitados em dias diferentes partiriam o histórico dela em dois. Não é texto
  livre — e o diálogo do `[+Novo]↻` **recusa nome repetido**, pela mesma
  comparação do tipo e do mercado, senão "Omo" e "OMO" nasceriam como duas
  marcas em dias diferentes, que é o estrago que fez a marca virar cadastro. A
  **descrição**, logo abaixo, continua sendo — mas desde a 1.9 ela
  **separa um cadastro do outro** ("zero" × "original"), então o campo passou a
  **sugerir as descrições já usadas naquele tipo e naquela marca** enquanto ele
  digita. É sugestão, não lista fechada: ela não sustenta conta nenhuma e não
  merece um cadastro próprio, mas "orig." digitado num dia distraído criaria um
  segundo produto do nada.
- `*` **Marca e descrição são opcionais; a embalagem depende de como o produto é
  vendido.** Produto por peça exige pelo menos uma linha — sem ela não há como
  converter a compra para litro ou quilo. Produto a peso não tem nenhuma. O acém
  moído não preenche marca, descrição nem embalagem.
- `*` Ao salvar, volta para a Tela 3 **com a embalagem marcada já selecionada**
  no campo "Produto". As primeiras semanas de uso são feitas quase só de produto
  novo — um passo a mais aqui pesa muito nos 2 minutos.
- `*` **Abrindo esta tela para acrescentar embalagem a um produto que já
  existe** — o caminho da manutenção do cadastro, que o quadro acima não desenha
  porque ele parte de um cadastro em branco —, aparece também a lista do que
  **já está cadastrado**, cada linha com o nome da embalagem e "já cadastrada".
  Essa lista fica **abaixo** das linhas editáveis e do `[ + Adicionar
  embalagem ]↻`, nunca acima: o que se digita não pode descer conforme o produto
  acumula embalagens. É a regra do tamanho da tela, nas Convenções de notação.

**Estados:**
- **Carregando:** Categoria, Tipo e Marca mostram "Carregando..." até as listas
  chegarem — as três vêm de fora do celular. O `[+Novo]↻` de cada uma já funciona
  durante a espera, porque criar não depende da lista.
- **Sistema vazio (primeiras semanas):** sem nenhuma categoria, nenhum tipo e
  nenhuma marca cadastrados, os três campos mostram "cadastre a primeira" e o
  `[+Novo]↻` fica em destaque — é o mesmo caminho de sempre, só sem lista atrás.
- **Antes do tipo estar escolhido:** com o campo Tipo ainda em branco, a lista de
  embalagens aparece desabilitada, com "escolha o tipo do produto primeiro". Sem
  a unidade base não há como saber se o seletor de medida oferece `g / kg` ou
  `ml / L`. Desde a 2.0 não existe mais o caso do "tipo novo sem unidade": quem
  cria o tipo pelo `[+Novo]↻` só sai do mini-cadastro com a unidade escolhida.
- Salvando: botão vira "Salvando..." e desabilita.
- Erro: "Não foi possível salvar o produto" + `[ Tentar de novo ]↻`.

**Estados adicionais:**
- **Produto que já existe, ganhando embalagem nova:** os campos de cima vêm
  preenchidos e travados e a lista de embalagens já mostra as que existem. Ele só
  acrescenta a linha nova — é o caso "comprou o Omo de 2,3 kg tendo só o de
  500 g". Esta tela é aberta pela **manutenção do cadastro (requisito 16), atrás
  do `≡`**, que não faz parte deste rascunho, **e pelo botão do estado abaixo**;
  a Tela 4 chegando pelo `[+Novo]→4` da Tela 3 abre sempre em branco.
- **Cadastro repetido, barrado** (decisão de 26/08/2026) — tipo + marca +
  descrição já existem:

```
┌──────────────────────────────────────┐
│ < Voltar   Novo produto              │
├──────────────────────────────────────┤
│  Categoria: ▼ Bebidas   [+Novo]↻     │
│  Tipo: ▼ refrigerante   [+Novo]↻     │
│  Unidade: litro (vem do tipo)        │
│                                      │
│  Vendido: (Peso)(•Unidade)(Volume)   │
│                                      │
│  Marca: ▼ Coca-Cola   [+Novo]↻       │
│  Descrição: original                 │
│                                      │
│  ⚠ Esse produto já está cadastrado,  │
│    com 4 embalagens.              *  │
│  [ Abrir e acrescentar embalagem ]→4 │
│  ────────────────────────────        │
│  Embalagens deste produto         *  │
│  Peças   Cada unidade   Fica como    │
│   1 × [ 600 ]▼ml   600ml   (•) [x]↻  │
│  [   + Adicionar embalagem   ][–]    │
│                                      │
│  [    Salvar 1 produto     ][–]   *  │
└──────────────────────────────────────┘
```

- `*` O aviso nasce assim que os três campos da identidade estão preenchidos —
  em geral antes de ele listar embalagem nenhuma. O quadro mostra o caso mais
  chato, o de quem já tinha começado a linha — a garrafa de 600ml, que o cadastro
  antigo não tem: é justamente o que o botão de saída leva junto.
  **`[ Salvar ]` fica travado** enquanto a repetição existir; mudar a descrição
  para "zero" destrava na hora, porque aí é outro produto.
- `*` **`[ Abrir e acrescentar embalagem ]` é a saída**, e é o que impede o
  bloqueio de virar beco sem saída: leva ao estado de cima, com os campos
  preenchidos e travados e a lista de embalagens que já existem carregada — o
  caminho do requisito 16, chegando aqui num toque em vez de por dentro do `≡`.
  O que ele digitou não se perde: a embalagem que estava montando desce para a
  lista de lá. **Quem chegou pelo lançamento continua voltando para ele**: salvar
  a embalagem nova devolve à Tela 3 com ela já selecionada, como qualquer
  cadastro feito pelo `[+Novo]→4`.
- `*` `[ + Adicionar embalagem ]` também trava: qualquer linha montada aqui
  nasceria dentro de um cadastro que não vai ser salvo.

---

## Tela 5 — Relatórios  `#5`

### Aba Resumo

```
┌──────────────────────────────────────┐
│ ≡ *            👤 Leandro ↻          │
├──────────────────────────────────────┤
│ [[ Resumo ]] [ Comparação de preço ]↻│
├──────────────────────────────────────┤
│  Período: ▤ 01/03  a  ▤ 31/03        │
│                                      │
│  Gastou R$ 1.200 de R$ 1.500      *  │
│                                      │
│  Carnes         R$ 480    (40%)      │
│  Limpeza        R$ 210    (18%)      │
│  ...                                 │
│  Total do período       R$ 1.200     │
│                                      │
│  [ Ver por tipo de produto ]↻     *  │
├──────────────────────────────────────┤
│  Lista→1     Falta→6     Relatórios  │
└──────────────────────────────────────┘
```

**Aberto por tipo de produto** (na mesma tela, sem navegar):

```
┌──────────────────────────────────────┐
│  Carnes                    R$ 480    │
│   Acém moído                         │
│     6 kg   R$ 32/kg      R$ 192   *  │
│   Frango                             │
│     8 kg   R$ 18/kg      R$ 144      │
│   ...                                │
│  ────────────────────────────        │
│  Limpeza                   R$ 210    │
│   Sabão em pó                        │
│     6,8 kg  R$ 20/kg     R$ 136   *  │
│     └ Omo     4,3 kg      R$ 86   *  │
│     └ Tixan   2,5 kg      R$ 50      │
│   ...                                │
└──────────────────────────────────────┘
```

**Notas:**
- A tela usa a **mesma barra inferior da Tela 1** — Lista e Relatórios são os
  dois destinos permanentes do app, e alternar entre eles não é "voltar".
- `*` "Gastou R$ X de R$ Y" só aparece quando o período escolhido é o mês
  inteiro — em período livre o teto não é mostrado. O R$ Y é o teto que valia
  **naquele mês**, não o teto de hoje. **Mês anterior à configuração do teto não
  tem teto nenhum** e não mostra a linha, mesmo depois de o teto passar a existir:
  o teto começa a valer no mês em que foi configurado e nunca retroage.
- `*` Cada tipo de produto mostra as **três medidas do requisito 4**:
  quantidade consumida na unidade base, preço médio dessa unidade e total
  gasto. O preço médio é o total dividido pela quantidade — 5 kg a R$ 30 mais
  1 kg a R$ 42 dá R$ 32 o quilo, não R$ 36.
- As reticências dentro de cada categoria são os demais tipos, omitidos no
  rascunho: os dois tipos mostrados em "Carnes" somam R$ 336 dos R$ 480 da
  categoria, e o sabão em pó, R$ 136 dos R$ 210 de "Limpeza".
- `*` Abrindo o tipo, aparece a divisão por marca **com quantidade e valor**
  ("Omo 4,3 kg — R$ 86", "Tixan 2,5 kg — R$ 50"), somando o total do tipo. Só
  com os quilos, a pergunta "para onde foi o dinheiro" ficaria sem resposta
  dentro do tipo. A descrição nunca aparece em relatório.

### Aba Comparação de preço

```
┌──────────────────────────────────────┐
│ ≡ *            👤 Leandro ↻          │
├──────────────────────────────────────┤
│ [ Resumo ]↻ [[ Comparação de preço ]]│
├──────────────────────────────────────┤
│  Produto: ▼ Omo 500g              *  │
│  (•) Este produto  ( ) Tipo inteiro *│
│                                      │
│  Carrefour       R$ 20,00 /kg  03/07 │
│  Extra           R$ 22,40 /kg  12/08 │
│  Pão de Açúcar   R$ 25,80 /kg  18/08 │
│                                      │
│  (mercado sem compra desse produto   │
│   nos últimos 3 meses não aparece)  *│
├──────────────────────────────────────┤
│  Lista→1     Falta→6     Relatórios  │
└──────────────────────────────────────┘
```

**Notas:**
- `*` A lista do seletor traz **só os produtos comprados nos últimos 3
  meses**, agrupados por categoria e em ordem alfabética dentro dela — é a mesma
  janela da comparação, e produto fora dela não teria o que mostrar. Tem busca
  por nome, porque a lista cresce.
- `*` A visão padrão é **"Este produto"** — marca com marca, embalagem com
  embalagem, como manda o requisito 6: o Omo 500g de um mercado contra o Omo
  500 g do outro. Trocando para **"Tipo inteiro"**, a mesma tela ignora marca e
  embalagem e responde só onde o quilo do sabão em pó sai mais barato — aí o
  pacote de 500 g de um mercado aparece lado a lado com o de 2,3 kg de outro, e
  o fardo de refrigerante lado a lado com a lata avulsa, os dois por litro. É
  nesta visão, e só nela, que dá para ver se o fardo compensa. O exemplo usa um
  produto **com marca** de propósito: em produto sem marca (acém moído) as duas
  visões dariam o mesmo resultado.
- `*` Comparação usa só os últimos 3 meses — pela **janela rolante**, com o mês
  em curso dentro — e mostra o preço da compra mais recente de cada mercado, não
  a média.
- `*` A **data ao lado do preço** (`dd/MM`) é a da compra de onde aquele preço
  veio. Sem ela, três preços parecem simultâneos quando um é de ontem e outro de
  sete semanas atrás — e o mais barato pode ser só o mais velho. É exatamente o
  caso do quadro: o Carrefour lidera com R$ 20,00/kg, mas aquele preço é de
  03/07, enquanto os dois mais caros são de agosto. A tela responde "onde saiu
  mais barato", e a data é a ressalva. O ano não aparece porque a janela é de
  3 meses e nunca há ambiguidade.
- `*` A ordem continua sendo **do mais barato para o mais caro**: a pergunta da
  tela é onde sai mais barato, e a data entra como ressalva, não como critério
  de ordenação. No exemplo, o preço mais recente (Extra, 18/08) não é o do
  topo.

**Estados:**
- Carregando: "Somando as compras do período...".
- Sem dado no período: "Nenhuma compra lançada nesse período".
- **Sem teto configurado:** a linha "Gastou R$ X de R$ Y" não aparece — no lugar
  dela, nada. O mesmo vale no mês em que o teto ainda não existia. Quem quiser
  definir um vai às configurações, atrás do `≡`; a partir do mês em que ele for
  configurado, a linha passa a aparecer contando o mês inteiro, inclusive o que
  já tinha sido gasto antes.
- Produto sem histórico de 3 meses: "Ainda não há base para comparar esse
  produto".
- Erro: "Não foi possível carregar o relatório" + `[ Tentar de novo ]↻`.

---

## Tela 6 — Falta comprar este mês  `#6`

```
┌──────────────────────────────────────┐
│ ≡ *            👤 Leandro ↻          │
├──────────────────────────────────────┤
│  Falta comprar este mês              │
│  Agosto/2026                      *  │
│  ────────────────────────────        │
│  Carnes                           *  │
│  Acém moído          faltam 2 kg     │
│   └ na lista: restam 2 de 6 kg       │
│  ────────────────────────────        │
│  Laticínios                          │
│  Leite               faltam 8 L      │
│   └ na lista: pedindo 6 L         *  │
│  ────────────────────────────        │
│  Limpeza                             │
│  Sabão em pó         faltam 2 kg     │
│   └ na lista, sem quantidade         │
│  Detergente          faltam 1,5 L    │
│   └ na lista, "não encontrei"     *  │
│  ────────────────────────────        │
│  Mercearia                           │
│  Café                 faltam 700 g   │
│                                      │
│  [ Ver todos (5 sem faltar) ]↻    *  │
├──────────────────────────────────────┤
│  Lista→1     Falta     Relatórios→5  │
└──────────────────────────────────────┘
```

**Com `[ Ver todos ]` aberto** (na mesma tela, sem navegar):

```
┌──────────────────────────────────────┐
│  ... o que falta, como acima ...     │
│  ────────────────────────────        │
│  NADA FALTANDO ESTE MÊS           *  │
│  Bebidas                             │
│  Refrigerante        12 de 10 L      │
│  Carnes                              │
│  Frango              8 de 8 kg       │
│  Frios                               │
│  Mussarela            500 de 400 g   │
│  Laticínios                          │
│  Iogurte             3 de 3 L     *  │
│  Mercearia                           │
│  Ovo                 30 de 24 un     │
│                                      │
│  [ Mostrar só o que falta ]↻         │
└──────────────────────────────────────┘
```

**Notas:**
- **A pergunta desta tela é uma só:** *o que ainda falta comprar neste mês, para
  bater o que vocês costumam consumir?* Ela não é a lista de compras e não é a
  sugestão — as notas seguintes separam as três.
- `*` **A conta é a média mensal menos o já comprado no mês corrente**, no tipo
  do produto e sempre na unidade base. O acém: média de 6 kg por mês, 4 kg
  comprados em agosto, `faltam 2 kg`. A média sai dos três meses fechados
  anteriores, dividida pelos meses de história daquele produto ali dentro, no
  máximo 3 — a mesma conta da Tela 2. O mês fica no topo porque todo número da
  tela é dele: na virada, o comprado volta a zero e cada `faltam` volta a ser a
  média inteira.
- `*` **Item que já está na lista aparece assim mesmo**, com o que a lista está
  pedindo logo abaixo, e os dois números podem divergir de propósito. O leite é
  o caso: a lista pede 6 L, a média diz que costumam consumir 8 L, e é ele quem
  decide qual seguir. Tocar num item desses abre o diálogo **editando** o item
  que já existe, nunca criando um segundo.
- **Tocar num item abre o mesmo diálogo de item da Tela 1**, já com a quantidade
  que falta preenchida e editável — ele confirma, corrige ou cancela. Não há
  seleção múltipla aqui: adicionar vários de uma vez continua sendo papel da
  Tela 2. A opção **"não encontrei"**, que na 1.9 passou a morar nesse diálogo,
  só aparece no item que **já está na lista**: marcar como não encontrado o que
  ainda não foi pedido não quer dizer nada.
- `*` **Item que está na lista _sem_ quantidade ganha um aviso no diálogo**
  (decisão de 26/08/2026). O sabão em pó está na lista sem quantidade, e item
  assim sai da lista na primeira compra daquele tipo; o diálogo abre com os
  2 kg que faltam preenchidos e, logo abaixo do campo, a linha *"este item está
  na lista sem quantidade — confirmar passa a pedir 2 kg"*. Confirmando, a baixa
  daquele item passa a ser por abatimento: comprar 1 kg deixa 1 kg de saldo em
  vez de tirá-lo da lista. Ele mantém, apaga o campo ou cancela — a tela
  continua não agindo sozinha, mas agora não troca a regra em silêncio.
- `*` **Quem não tem saldo no mês some da tela**, e o botão diz quantos são. A
  faixa se chama **"nada faltando este mês"**, e não "já atingiram a média",
  porque nem todos ali atingiram meta nenhuma: o iogurte entrou este mês e a
  média dele *é* a própria compra — não há o que atingir, e mesmo assim não
  falta nada dele. O `[ Ver todos ]↻` revela essa segunda faixa, com o consumido
  sobre a média (`12 de 10 L`) e sem bloquear ninguém: o refrigerante pode acabar no dia 20
  mesmo já tendo batido a média, e nesse dia ele precisa conseguir adicionar.
  Sem essa saída, a tela esconderia justamente o que faltou em casa.
- `*` **Produto nascido neste mês tem por média a própria compra dele.** O
  iogurte, comprado pela primeira vez em agosto, aparece como `3 de 3 L`: não há
  mês fechado para dividir, então nada falta dele hoje. Em setembro ele já tem um
  mês fechado e entra na conta como todos os outros.
- **Aparece todo tipo com saldo no mês, inclusive o que está na lista marcado
  como "não encontrei"** — para esse, faltar continua faltando, e é o caso do
  detergente no quadro. Os dois quadros acima fecham com os das Telas 1 e 5: os
  cinco itens da lista estão aqui, o acém, o leite, o sabão em pó e o detergente
  na faixa de cima e o frango na de baixo, e a contagem do botão bate com o que
  o `[ Ver todos ]` mostra. Corrigido na 2.0, quando o frango e o detergente
  sumiam das duas faixas com a contagem afirmando o contrário. A marcação em si
  não vive aqui: ela **cai sozinha na primeira compra daquele tipo, mesmo
  parcial** (decisão de 26/08/2026), porque comprar prova que ele achou o
  produto. O saldo do mês, esse, continua o que era.
- `*` **A ordem é a mesma da Tela 2 e da Tela 1: agrupada por categoria**, em
  ordem alfabética dentro de cada uma. Não é do maior saldo para o menor nem do
  mais comprado para o menos: `faltam 2 kg` e `faltam 8 L` não são comparáveis
  entre si, e nem a quantidade comprada nem o saldo servem de régua entre tipos
  medidos em grandezas diferentes. As duas faixas — o que falta e o que já
  atingiu — seguem o mesmo agrupamento.
- **Esta tela nunca mexe na lista sozinha.** Não marca item, não dá baixa e não
  tira nada de lugar nenhum: só mostra números e abre o diálogo quando ele toca.
  Quem tira item da lista continua sendo a compra lançada na Tela 3.
- **`faltam` aqui e `restam` na Tela 1 são coisas diferentes**, e por isso as
  duas palavras nunca trocam de lugar: `restam 2 de 6 kg` (Tela 1) é o saldo
  contra o que **ele pediu** na lista, e é ele que tira o item de lá;
  `faltam 2 kg` (Tela 6) é o saldo contra o que vocês **costumam consumir**, e
  não tira nada.

**Estados:**
- Carregando: "Somando o que vocês já compraram este mês...".
- Nada faltando: "Vocês já compraram tudo que costumam comprar em agosto" +
  `[ Ver todos ]↻`, para quem quiser adicionar assim mesmo.
- Sem histórico suficiente: "Ainda não há compras suficientes para calcular a
  média" (sem botão de ação) — é o estado das primeiras semanas.
- Erro: "Não foi possível carregar" + `[ Tentar de novo ]↻`.
- Sem internet: "Sem conexão — não é possível abrir agora" +
  `[ Tentar de novo ]↻`.

> **Confirmado por ele em 26/08/2026 (era suposição até a 1.7):** os 3 meses da
> média são os **três meses fechados anteriores** — em agosto, a média vem de
> maio, junho e julho. É a **janela fechada**, e vale só para as perguntas de
> consumo: média mensal, sugestão (Tela 2) e esta tela. As perguntas de preço —
> alerta de alta, comparação entre mercados e calculadora — usam a **janela
> rolante**, que inclui o mês em curso. O mês corrente fica de fora dela de propósito: se entrasse, cada
> compra de agosto aumentaria a própria média de agosto e o `faltam` nunca
> chegaria a zero. A janela é a mesma da Tela 2 — as duas telas não podem contar
> o mesmo consumo de dois jeitos diferentes. **O que a janela não define é o
> divisor:** ele são os **meses fechados** de vida do produto dentro dela, no
> máximo 3 — três para quem já era comprado antes da janela, dois para quem
> estreou em junho, um para quem estreou no último mês fechado. **Produto nascido
> no mês em curso fica fora dessa divisão:** ele não tem mês fechado nenhum e o
> total dele dentro da janela é zero, então a média é o que ele comprou no
> próprio mês em curso, sem divisor.
---
## Checklist antes de virar PWA

- [x] 6 telas principais desenhadas (não o app inteiro), mais os dois painéis
      que só existem dentro delas: `#1a` (adicionar item, sobre a Tela 1) e
      `#3a` (comparar custo, sobre a Tela 3)
- [x] Todo botão navega com `→N` ou age na própria tela com `↻`, salvo o `≡`,
      cuja exceção está declarada nas convenções
- [x] Todas as telas do mapa de navegação existem no arquivo
- [x] O que ficou fora do rascunho está declarado abaixo do mapa, com o dono de
      cada requisito adiado
- [x] Estados de carregando e erro descritos nas seis telas e nos dois painéis
      (`#1a` e `#3a`) — a Tela 1 ganhou o dela na 1.8, e as **Telas 3 e 4 e o
      `#3a`** na 2.0, que o checklist já dava como prontos sem estarem; são
      justamente as três que mais esperam dados de fora do celular
- [x] O `#3a` cabe em tela de celular pequena sem esconder a resposta: cabeçalho
      e rodapé fixos, só a lista rola, e a lista abre curta
- [x] Todo campo digitável é desenhado acima de lista, resumo, total e botão,
      nas seis telas e nos dois painéis — **390 × 844 é a régua**, com as duas
      exceções declaradas nas convenções: o campo dentro de linha repetível e a
      frase que explica o campo vazio
- [x] Estado de sistema vazio descrito onde ele existe (Telas 1, 3 e 4); as
      Telas 2, 5 e 6 tratam o caso como "sem dado no período"
- [x] Regras marcadas com `*` explicadas
- [x] Nenhum símbolo da notação tem dois significados — `[ ]` é estado do item,
      `{ }` é escolha em seleção múltipla, `★` é melhor custo, `░` é a tela de
      trás esmaecida (nunca área de imagem, que é `▓`). O `[–]` significa
      **travado** tanto no item quanto no botão, que é um significado só: a
      notação foi corrigida na 1.8 para dizer isso, e na 2.0 para escrevê-lo de
      um jeito só — o traço vem sempre depois do elemento. O `👤` entrou na
      tabela na 2.0, depois de quatro versões sendo usado sem estar lá
- [x] Nenhuma decisão de cor, fonte ou efeito foi tomada aqui
- [x] Os **16 achados da revisão em três passadas** foram fechados na 2.0 — os
      sete de regra por decisão dele, os nove de redação, exemplo e notação sem
      consultar ninguém (ver `revisao-3-passadas.md` e o histórico dos requisitos)
- [x] **Nenhuma suposição em aberto no arquivo.** As duas últimas caíram na 1.9:
      o ciclo de três toques da Tela 1 virou caixa de dois estados, com "não
      encontrei" no diálogo do item, e o produto repetido da Tela 4 virou
      cadastro único por tipo + marca + descrição, com o salvar travado. Antes
      delas: o fardo não concorrer com a peça avulsa no alerta de preço **foi
      resolvido na 1.5** (o alerta continua sem misturar embalagens, e a
      comparação ganhou o `#3a`), e a janela dos três meses fechados **foi
      confirmada na 1.8**, junto da decisão de o sistema ter duas janelas de
      referência

---

## Especificação do PWA de entrega

| Aspecto | Regra |
|---|---|
| Formato | PWA simples (HTML/CSS/JS estático), navegável no celular |
| Cor | Preto e branco apenas |
| Efeitos | Nenhum — sem sombra, gradiente, animação, transição. O painel `#3a` **aparece e some sem animação**: ele cobre a parte de baixo da tela, com o lançamento esmaecido atrás |
| Imagem | Nenhuma. Retângulo cinza com o texto "imagem" (não há imagem neste projeto) |
| Fonte | Uma só, tamanho padrão |
| Navegação | Botões clicáveis entre as telas, seguindo os `→N` |
| Cobertura | As mesmas 6 telas deste arquivo, mais os **seis diálogos** descritos nelas: adicionar item (`#1a`, painel sobre a Tela 1), **mini-cadastro de tipo** (dentro do `#1a` e reusado pelo `[+Novo]↻` do Tipo na Tela 4), edição de item da lista (Tela 1, reusado pela Tela 6), **categoria nova** (um campo só, no `#1a` e na Tela 4), mercado novo (Tela 3) e marca nova (Tela 4, um campo só, igual ao mercado) — mais o painel comparar custo (`#3a`, sobre a Tela 3, com cabeçalho e rodapé fixos). Os três de um campo só — categoria, mercado e marca — são a mesma tela com outro rótulo |
| Entrega | Link publicado, não arquivo anexo |

**Por que preto e branco e sem efeito:** se sair polido demais, a conversa vai
para cor de botão e fonte em vez de estrutura e fluxo. Baixa fidelidade é
proposital.
