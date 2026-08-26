# Triagem das pendências — 26/08/2026

Releitura dos itens de `revisao-pendencias.md` contra o texto de hoje dos dois
documentos. Nada foi alterado em `requisitos-lista-de-compras.md` nem em
`wireframes-lista-de-compras.md`; os arquivos estão como estavam em 21/08.

**Resultado:** os **23 itens continuam válidos** — nenhum foi resolvido por
tabela. Um (o 18) perdeu quase toda a força e desceu para cosmético; dois (15 e
27) são maiores do que o relatório original dizia. A ordem abaixo é por quanto
cada um trava a construção, não pela numeração antiga.

---

## Faixa A — precisam da sua decisão antes de virar código

São oito. Enquanto não tiverem resposta, quem for construir vai inventar a regra
ou parar.

### A1 · Item 4 — não existe fluxo de adicionar item à lista
`wireframes:273` (o botão) e `wireframes:328` (o estado vazio) — só isso

Confirmado por varredura: "Adicionar item" aparece exatamente duas vezes nos dois
documentos, as duas como botão, nenhuma com diálogo, campo ou regra. É o caminho
mais usado do app e o primeiro da ordem de construção (14 → **1**), então trava
antes de qualquer outra coisa. As duas partes a decidir continuam as do relatório:
como o tipo é escolhido (busca com "criar na hora" é a única opção que atende o
item nunca comprado) e se o diálogo pede algo além do tipo.

### A2 · Item 14 — o lançamento em andamento some se a conexão cair
`wireframes:474` (Estados da Tela 3)

Confirmado: "sem conexão" está descrito em duas das seis telas — Tela 1
(`wireframes:329`) e Tela 6 (`wireframes:968`). A Tela 3 não tem nenhum estado de
conexão; o que ela prevê é só a falha ao salvar. Vinte itens digitados perdidos
atingem o maior risco declarado do projeto, que é o hábito de lançar. E a resposta
muda a construção inteira da tela: guardar o rascunho no aparelho não é um ajuste
de tela, é uma decisão de arquitetura.

### A3 · Item 9 — reclassificar pode cruzar famílias de medida
`requisitos:469-470` (requisito 16) + `requisitos:1097-1100`

Confirmado nos dois pontos. O requisito permite "mudar um produto de tipo ou de
categoria" e a regra diz que a classificação nova vale para **todo o histórico**,
inclusive relatórios de meses anteriores. Nada impede mover um produto medido em
litro para um tipo medido em quilo. É o item mais caro de errar da lista: soma
peso com volume dentro do histórico e não há como desfazer depois.

### A4 · Item 17 — item da lista apontando para tipo desativado
`requisitos:1102-1106`

Confirmado. A regra diz o que desativar faz nas sugestões, no lançamento e nos
relatórios, e não diz o que acontece com um item que já está na lista apontando
para aquele tipo. É estado alcançável em produção na primeira faxina de cadastro.

### A5 · Item 13 — "não encontrei" não tem regra de limpeza
`requisitos:979-980`

Confirmado, e com um agravante que o relatório original não registrou: a Tela 6
já tomou posição sobre a marcação (`wireframes:944-946`, "inclusive o que está na
lista marcado como 'não encontrei' — para esse, faltar continua faltando"), o que
confirma que a marca persiste, mas continua sem dizer o que a apaga. Numa compra
parcial o item fica na lista com saldo **e** com a marca.

### A6 · Item 11 — a Tela 6 abre o diálogo com a quantidade preenchida
`requisitos:600-602` · `wireframes:882-883` e `wireframes:930-933`

Confirmado, com uma correção de leitura: a tela não age sozinha — quem confirma é
ele. O problema real é outro e permanece. O sabão em pó está na lista **sem
quantidade**, e item sem quantidade "sai na primeira compra daquele tipo"
(`requisitos:978`). Confirmar um diálogo que já vem com "2 kg" preenchido troca a
regra de baixa daquele item sem que a tela diga que trocou.

### A7 · Item 12 — aviso de repetição em lançamento retroativo
`requisitos:372-379`

Confirmado. O aviso é retroativo por decisão, compara compras do mesmo dia e o
texto do critério de aceite é "vocês dois compraram leite **hoje**". Lançar hoje
uma compra de três semanas atrás dispara a frase errada.

### A8 · Item 16 — o requisito 16 não cobre mercado
`requisitos:468-471` x `wireframes:230-232`

Confirmado nos dois lados. O requisito lista "categoria, tipo, marca ou produto";
o wireframe promete manutenção de "categoria, tipo, marca, produto **e mercado**".
Mercado é cadastro desde 18/08 (requisito 15) e fecha, muda de nome e é digitado
errado como qualquer outro.

---

## Faixa B — decisão já tomada, falta escrever

Seis itens. Nenhum precisa de você: é aplicar o que o histórico já registra.
O B1 vem primeiro porque é a regra fundadora do modelo de dados.

| # | Onde | O que está errado |
|---|---|---|
| **B1** · item 1 | `requisitos:766-767` | Primeira regra de negócio ainda diz que o 5º nível é "peso"; o resto do documento já diz "embalagem" |
| **B2** · item 2 | `requisitos:224` | "cadastrado completo na hora, com os cinco níveis" — impossível para produto sem marca; já corrigido em "Quando dá errado" |
| **B3** · item 24 | `requisitos:218` | "só digita **quantas caixas** e o valor" — o rótulo variável foi eliminado em 21/08; o campo é "Quantidade" |
| **B4** · item 23 | `requisitos:1226` | "no produto **a granel**" — último resto de "granel" no glossário; o termo é "vendido a peso" |
| **B5** · item 10 | `requisitos:501` · `wireframes:557` | "último preço pago naquela embalagem" sem dizer que é `total ÷ quantidade`; o Omo 500g abriria com R$ 15,00 em vez de R$ 5,00 |
| **B6** · item 15 | `requisitos:231`, `requisitos:239`, `requisitos:741` · `wireframes:780` | Gasto por marca prometido e nunca mostrado |

**O B6 é maior do que estava escrito.** O relatório original apontava só a Tela 5.
Na verdade são três lugares, e um deles é o próprio requisito: o requisito 4 pede
o relatório "agrupado por categoria, por tipo de produto e por marca"
(`requisitos:231`) e diz "abrir o tipo mostra a divisão por marca"
(`requisitos:233`) — mas o **critério de aceite dele** (`requisitos:239`) manda
mostrar "Omo 4,3 kg / Tixan 2,5 kg", sem R$. O requisito se contradiz sozinho, e a
tela só copiou o critério. Corrigir a tela sem corrigir o critério não resolve.

---

## Faixa C — texto e exemplos, não travam ninguém

Nove itens. Confundem quem lê, mas dá para construir com eles como estão.
O **C1 é o único que engana sobre o estado do projeto** e por isso abre a faixa.

**C1 · Item 27 — "Cobertura da entrevista" toda marcada.** `requisitos:1264-1276`
x `requisitos:1148-1173`. Pior do que o relatório dizia: as onze linhas estão
marcadas `[x]`, inclusive "Validação de qualidade dos Essenciais", enquanto
"Pontos em aberto" carrega **três perguntas sem resposta** — data futura no
lançamento, o que acontece ao cadastrar produto que já existe, e se os 3 meses da
média são os três meses fechados anteriores. Quem abrir o documento na Cobertura
conclui que está pronto para aprovação.

**C2 · Item 22 — os preços do Omo divergem entre seções.** `requisitos:782-783`
(2,3 kg por R$ 46 = R$ 20/kg) x calculadora `#3a` (`wireframes:522-523`: 2,3 kg
por R$ 10,00 = R$ 4,35/kg, e 500 g por R$ 5,00 = R$ 10/kg) x `wireframes:814`
(Omo 500g a R$ 20,00/kg). O mesmo produto com o quilo dobrado ou pela metade
conforme a seção. Junto: o critério do requisito 6 (`requisitos:274-275`) descreve
"mais barato 12/08, mais caro 18/08", e a tela (`wireframes:814-816`) tem três
mercados, com o mais caro em 03/07.

**C3 · Item 21 — "6,8 kg de sabão em pó" é trimestre no requisito e mês na tela.**
`requisitos:239` e `requisitos:779` ("no trimestre") x `wireframes:751`, cujo
período é 01/03 a 31/03.

**C4 · Item 20 — o quadro do `#3a` contradiz a própria nota.** `wireframes:524-525`
x `wireframes:557-560`. Tixan 1kg e 2kg aparecem com preço vazio **antes** de
tocar em `[ Ver todas do tipo ]`, e duas linhas vêm `{x}` marcadas quando a nota
justifica só uma.

**C5 · Item 19 — aviso de alta com os campos vazios.** `wireframes:424-425`. O
`⚠ Subiu 18% sobre a média` aparece acima de `Quantidade: __  Valor: R$ ___`.
Estado impossível: o alerta depende do preço por unidade base.

**C6 · Item 25 — o mapa diz que a Tela 6 "volta para 1".** `wireframes:215` x
`wireframes:221-222` ("Alternar entre elas não é 'voltar'") e a barra inferior da
própria Tela 6. O mapa também não mostra o eixo 5↔6.

**C7 · Item 26 — o checklist afirma estado de erro nas seis telas.**
`wireframes:993` x os Estados da Tela 1 (`wireframes:323-330`), que tem primeira
abertura, carregando, vazio e sem internet — nenhum estado de erro.

**C8 · Item 28 — período livre com um seletor de data só.** `wireframes:751`:
`Período: ▤ 01/03 a 31/03` usa um único `▤`, que a notação define como um campo
de data. Período livre precisa de dois.

**C9 · Item 18 — a faixa "já atingiram a média" e o produto novo.**
`wireframes:888` e `wireframes:900`. **Rebaixado.** O relatório de 21/08 tratava
isso como classificação errada, mas a nota em `wireframes:939-942` já explica o
caso por extenso ("produto nascido neste mês tem por média a própria compra
dele... o iogurte aparece como 3 de 3 L"). O que sobra é só o rótulo: a faixa se
chama "JÁ ATINGIRAM A MÉDIA DO MÊS" e o contador diz "(4 já atingiram)" incluindo
quem não atingiu meta nenhuma. Texto, não regra.

---

---

# Varredura nova — 26/08/2026

Leitura completa dos dois documentos, procurando o que a revisão de 21/08 não
catalogou. **Oito achados novos.** Um deles (o V1) é maior do que qualquer item
da lista antiga e muda contas que já estavam sendo tratadas como resolvidas.
Continua sem nenhuma alteração nos documentos.

## V1 · Existem duas janelas de "3 meses" no sistema, e o documento nunca escolhe

`requisitos:904` x `requisitos:1032` — e mais dez lugares

Este é o achado que justifica a varredura. Metade do documento diz **"últimos
3 meses"**, uma janela rolante que inclui o mês em curso. A outra metade diz
**"os três meses fechados anteriores"**, que exclui o mês em curso de propósito.
São coisas diferentes, e ninguém declarou que são duas.

| Onde | Janela que o texto usa |
|---|---|
| Alerta de preço | rolante — `requisitos:242`, `requisitos:908`, `requisitos:917`, `wireframes:472` |
| Comparação entre mercados | rolante — `requisitos:263`, `requisitos:922`, `wireframes:826`, `wireframes:839` |
| Calculadora `#3a` | rolante — `requisitos:505`, `requisitos:558`, `requisitos:566` |
| Sugestão (Tela 2) | **fechada** — `requisitos:320`, `wireframes:377` |
| Falta comprar (Tela 6) | **fechada** — `requisitos:1032`, `wireframes:972` |
| Glossário, "Média mensal" | **fechada** — `requisitos:1248` |

E os dois trechos que costuram tudo tratam as duas como uma só:

> `requisitos:904` — "A janela de referência do sistema é de **3 meses**, usada
> em três lugares: o alerta de preço, a comparação entre mercados e a sugestão da
> lista."

Esses três lugares estão em lados opostos da tabela acima. E `requisitos:895` diz
que a calculadora usa "**a mesma janela de referência do resto do sistema**" —
frase que, com duas janelas em campo, não aponta para nada.

**O que muda na prática.** Hoje é 26/08. Uma compra do dia 20/08:

- pela janela rolante, entra na média do alerta de preço, aparece na comparação
  entre mercados e põe aquela embalagem na lista curta da calculadora;
- pela janela fechada, **não existe** para nenhum dos três: o alerta compararia o
  preço de hoje com a média de maio, junho e julho, ignorando agosto inteiro, e a
  embalagem que ele comprou semana passada sumiria da calculadora — justamente a
  que ele mais quer ver ali.

A decisão de 21/08 que criou a janela fechada (`requisitos:1162-1173`, ainda em
aberto) foi tomada por um motivo que **só vale para sugestão e acompanhamento**:
impedir que a compra do mês eleve a própria meta. Esse motivo não existe no
alerta de preço nem na comparação entre mercados, onde excluir o mês corrente só
faz a resposta envelhecer.

**A decidir:** o sistema assume as duas janelas explicitamente — fechada para
sugestão e acompanhamento, rolante para alerta, mercados e calculadora — ou
unifica numa só? Se assumir as duas, `requisitos:904` e `requisitos:895` precisam
ser reescritos, porque hoje eles afirmam o contrário.

## V2 · Teto configurado no meio do mês nunca dispara o aviso dos 80%

`requisitos:352-356` x `requisitos:990-995` · `wireframes:497-499`

O critério de aceite do requisito 9 descreve o caso: ele configura R$ 1.500 no
dia 20 de agosto **tendo já gastado R$ 1.300** — 86,7% do teto. A regra do aviso
diz que ele aparece "no momento em que o **lançamento** faz o mês cruzar os 80%",
e que são "dois avisos por mês, **cada um uma vez só**".

Configurar o teto não é um lançamento. O mês já nasce acima do corte, então
nenhum lançamento o cruza, e o aviso dos 80% nunca dispara naquele mês. O de 100%
dispara normalmente mais adiante — ou seja, o único aviso que existe para avisar
**antes** de estourar é justamente o que não acontece no mês em que o teto é
criado.

**A decidir:** configurar o teto acima de um corte já ultrapassado dispara o
aviso na hora, ou o mês da configuração fica sem o aviso de 80%?

## V3 · A cobertura do PWA ficou para trás da versão 1.7

`wireframes:1021` x `wireframes:698`

A especificação de entrega diz "as mesmas 6 telas, mais os **três diálogos**
descritos nelas: mercado novo (Tela 3), edição de item da lista (Tela 1) e
comparar custo (`#3a`)". São quatro: a versão 1.7 criou o **diálogo de marca
nova** na Tela 4 (`[+Novo]↻` ao lado do campo Marca, "um campo só — igual ao
mercado da Tela 3"), e ele ficou de fora da lista.

Vale registrar junto o efeito do **item 4** (A1) aqui: sem fluxo de adicionar
item, o PWA que vai ser aprovado não tem por onde adicionar item — e a
especificação nem declara o buraco.

## V4 · O glossário ainda define marca como campo digitado

`requisitos:1193` x `requisitos:100`, `requisitos:701`, `requisitos:772`

> "**Marca**: o fabricante (Omo, Tixan, Tirolez). **Campo digitado, com sugestão
> das marcas já usadas.**"

É exatamente a redação que a versão 1.7 aposentou (`wireframes:6-12`: "o campo
deixou de ser texto livre com sugestão e virou `▼ marca` com `[+Novo]↻`"). O
requisito 1, a seção Informações e a regra de negócio já dizem "escolhida de uma
lista, nunca digitada solta". Sobrou o glossário — que é onde alguém vai
conferir o termo.

Mesma família do B1 e do B4: resíduo de decisão já tomada, correção mecânica.

## V5 · O cabeçalho da Tela 2 contradiz a nota da própria Tela 2

`wireframes:346-347` x `wireframes:377`

O quadro diz "Baseado no que compraram nos **últimos 3 meses**"; a nota da mesma tela diz "A janela é a dos **três meses fechados anteriores**". A contradição
do V1 dentro de uma tela só. Se o V1 for decidido, esta cai junto.

## V6 · A fórmula do recálculo do valor está escrita errada

`wireframes:453-456`

> "a cada mudança na quantidade, recalcula o valor total sozinho (**12 caixas ×
> R$ 5,17 o litro = R$ 62**)"

A conta multiplica **embalagens** por preço da **unidade base**. Só fecha porque a
caixa de leite tem exatamente 1 litro. Com "Coca 12x350ml" (4,2 L, R$ 11,43 o
litro), a fórmula como está escrita daria R$ 11,43 para uma embalagem, quando o
certo é R$ 48. A regra correta está no requisito 3 (`requisitos:200-205`):
**quantidade convertida para a unidade base × preço da unidade base**.

Não trava decisão, mas é texto que vira código direto.

## V7 · O botão "Comparar custo" some no tipo vendido a peso

`wireframes:465-470` x `requisitos:497-500`

O wireframe diz que o botão "só aparece quando o tipo do produto tem **duas
opções ou mais**". O requisito 17 diz que produto vendido a peso "entra como mais
uma linha, com o preço do quilo digitado direto, e é assim que a mussarela do
balcão é confrontada com a fatiada em pacote".

Produto a peso não tem embalagem cadastrada. O documento não diz se ele conta
como "opção" para efeito de mostrar o botão — e num tipo inteiramente vendido a
peso (acém moído) o botão nunca apareceria, embora a calculadora tenha uso ali:
comparar o quilo do açougue com o do supermercado.

**A decidir:** produto vendido a peso conta como opção na contagem que faz o
botão aparecer?

## V8 · `[–]` está documentado como item e usado como botão

`wireframes:172` x `wireframes:605`

A notação define `[–]` como "item travado, não responde ao toque". O único uso
real no arquivo é um **botão** travado (`[Usar…]` quando o custo dá empate). É o
segundo significado que o checklist (`wireframes:999`) jura não existir — mesma
família do item 26.

---

## Retratação da nota "à margem" da triagem

A observação de que o requisito 16 falaria de "um produto com várias embalagens",
contra a embalagem ser a folha da hierarquia, **está resolvida no documento** e
não deveria ter sido levantada. O requisito 1 (`requisitos:135-141`) e a Tela 4
(`wireframes:687-689`) dizem por extenso: um cadastro lista várias embalagens e
**cada linha vira um produto próprio ao salvar**. Reabrir o cadastro para
acrescentar uma linha cria mais um produto, não uma segunda embalagem dentro do
mesmo. O vocabulário do requisito 16 é abreviado, mas não contradiz nada.

---

## Onde os oito entram nas faixas

- **Faixa A (decisão sua):** V1 — **na frente de tudo**, inclusive do item 4:
  ele muda o que três telas calculam, e duas delas (5 e a calculadora) já estão
  descritas como prontas. Depois V2 e V7.
- **Faixa B (mecânico):** V4, V5, V6, V3.
- **Faixa C (cosmético):** V8.
