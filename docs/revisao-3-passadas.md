# Revisão em três passadas — 26/08/2026

_Aberto em 26/08/2026 com 16 achados · **fechado no mesmo dia, com os 16
resolvidos** — sete por decisão dele, nove sem consultar ninguém · mais **seis de
uma quarta passada**, feita sobre o texto já corrigido e registrada no fim ·
aplicado em `requisitos-lista-de-compras.md` e em
`wireframes-lista-de-compras.md`, que subiu para a **versão 2.0**_

Três varreduras dos dois documentos-fonte depois da sessão de fechamento de
26/08, que declarou "não resta suposição nem pergunta em aberto em nenhum dos
dois documentos". **Os dois arquivos são a fonte da verdade**; o que segue vale
como registro de _o que foi achado, o que foi decidido e por quê_, para ninguém
reabrir a discussão sem saber o que já foi resolvido.

**As sete decisões dele, em uma linha cada:**

1. **A1** — o rótulo do campo do lançamento, no produto vendido a peso, vem da
   **unidade base do tipo**: "Peso (kg)", "Volume (L)", "Quantidade (un)".
2. **A2** — **tipo e categoria ganharam trava de duplicidade**, ignorando
   maiúsculas, espaço sobrando **e acento**; o desativado aparece na busca com
   opção de reativar.
3. **A3** — **Categoria e Tipo ganharam `[+Novo]↻` na Tela 4**, como a Marca já
   tinha; o Tipo abre o mesmo mini-cadastro do `#1a`.
4. **A4** — preferência da lista apontando para cadastro desativado **cai em
   silêncio**, e o item continua só com o tipo.
5. **A5** — alterar o teto **zera os dois avisos do mês e reavalia na hora**.
6. **A6** — apagar ou corrigir a compra **devolve também a marcação "não
   encontrei"** que ela derrubou.
7. **A7** — a lista se atualiza sozinha, mas o que chega do outro celular entra
   por uma **faixa no topo** ("2 itens novos — atualizar"), nunca debaixo do
   dedo.

Os nove da Faixa B e C foram corrigidos direto, como escrito em cada um.

**Nada continua em aberto.**

---

- **1ª passada** — leitura completa dos dois arquivos, um contra o outro,
  refazendo na mão todas as contas dos exemplos.
- **2ª passada** — verificação item a item dos candidatos, por busca no texto,
  para separar o que é achado real do que só parecia.
- **3ª passada** — descarte dos falsos positivos e ordenação por quanto cada um
  trava a construção.

**Resultado: 16 achados.** Nenhum invalidou decisão já tomada; todos eram
buracos que as decisões de 26/08 abriram ou deixaram de fechar. **Sete pediam
decisão dele** — todas tomadas no mesmo dia, resumidas acima. As contas dos exemplos, essas, fecham todas — os R$ 72,00 da
Tela 3, os 28% do `#3a`, os R$ 32/kg do acém, os 6,8 kg de sabão em pó, os 18%
do alerta e as duas datas do requisito 6 batem entre as telas e os requisitos.

---

# Faixa A — precisam da decisão dele

## A1 · "Vendido a peso" não está preso à unidade base do tipo
`wireframes:618` (o campo) · `requisitos:1023` (a marcação) · `requisitos:1496`
(o glossário)

O lançamento troca o campo "Quantidade" por **"Peso (kg)"** sempre que o produto
é marcado como vendido a peso — em três lugares do rascunho, sempre com o "kg"
escrito por extenso. Só que nada no documento impede marcar "a peso" num tipo
medido em **litro** ou em **unidade**. O cadastro (Tela 4) oferece o rádio
"( ) A peso  (•) Por peça" antes de qualquer checagem de unidade, e marcar "a
peso" **faz a lista de embalagens sumir da tela inteira** — que é justamente o
único lugar onde a medida seria informada.

O resultado é o erro que o documento persegue em todo o resto: um produto de um
tipo medido em litro entrando no histórico em quilos, e o total do tipo somando
peso com volume. É a mesma família do "creme de leite em 200 g num tipo medido
em litro" de "Quando dá errado" e da reclassificação entre grandezas
incompatíveis fechada em 26/08 — as duas foram tampadas, esta não.

O glossário chega perto de resolver sozinho, ao definir *a peso* como "o que vai
na balança e sai no cupom **em quilos**". Mas isso é a definição de uma palavra,
não uma regra de cadastro: nada na Tela 4 recusa a combinação, e nada diz o que
fazer com azeite ou leite vendidos no balcão.

**A decidir:** ou "vendido a peso" só é oferecido em tipo medido em quilo (e a
Tela 4 esconde o rádio nos outros), ou o rótulo do campo passa a vir da unidade
base — "Peso (kg)", "Volume (L)", "Quantidade (un)" —, como já acontece no
título do `#3a` ("custo por kg / por litro / por unidade").

## A2 · Tipo e categoria são os únicos cadastros sem trava de duplicidade
`wireframes:472` (criar tipo na busca) · `wireframes:483` (criar categoria) ·
`requisitos:994` (a trava do produto)

O documento fechou, uma a uma, todas as portas por onde um cadastro nasceria em
duplicidade: **mercado** virou cadastro escolhido de lista, **marca** também,
**embalagem** é comparada pelo conteúdo e não pelo texto, e o **produto** ficou
único por tipo + marca + descrição, com o salvar barrado. O motivo é sempre o
mesmo, e está escrito em cada uma delas: nome escrito de dois jeitos parte o
histórico em dois, e nenhum rename posterior junta o que nasceu separado.

**O tipo do produto não tem essa trava** — e ele é *o nível que soma*. Nem a
categoria tem.

O buraco piorou em 26/08, quando o `#1a` ganhou o "Criar '…'": agora existem
duas portas para criar tipo (a busca da lista e a Tela 4) e o mini-cadastro é
uma caixa de texto livre. A busca filtra pelo que ele digitou, então basta
digitar "leite em po" sem acento, ou "achocolatados" no plural, para a última
linha oferecer criar um segundo tipo — e a partir daí a lista agrupa em dois
lugares, a média se divide, o relatório soma metade em cada um e a baixa da
compra deixa de casar com o item.

Some-se a isso que o `#1a` **não diz o que faz com tipo desativado**. O `#3a`
declara em letras próprias que "produto desativado não aparece em nenhuma das
duas listas"; a busca do `#1a` não declara nada. Se o desativado não aparece,
quem der falta dele vai criar um tipo novo com o mesmo nome — e o histórico que
o desativar existia para preservar racha assim mesmo.

**A decidir:** que trava vale para tipo e categoria. O mais barato é a mesma do
produto — comparar ignorando maiúsculas e espaço sobrando, e barrar o "Criar"
quando bater com um existente, ativo ou desativado, oferecendo reativar.

## A3 · Não há como criar categoria ou tipo novo na Tela 4
`wireframes:837-838` (os campos) · `wireframes:862` (a nota) ·
`wireframes:937` (o estado de sistema vazio)

Na Tela 4, **Marca** tem `[+Novo]↻` ao lado. **Categoria** e **Tipo do produto**
são só `▼`, sem botão nenhum. E o requisito 1 promete o contrário: produto novo
é cadastrado na hora, "categoria e tipo sempre".

A própria tela sabe que falta alguma coisa: a nota da unidade diz que "só quando
o **tipo digitado** é novo o campo vira `▼ quilo / litro / unidade`" — fala em
digitar num campo que está desenhado como lista suspensa. E o estado de sistema
vazio resolve o caso só das primeiras semanas: "sem nenhuma categoria, nenhum
tipo e nenhuma marca cadastrados, esses campos abrem direto no modo 'nova'".
Depois do primeiro cadastro salvo, o modo "nova" some e não volta.

O efeito prático aparece no primeiro produto de uma categoria nova — o primeiro
item de "Pet", de "Bebês", de "Padaria". Ele está no lançamento, com o cupom na
mão, e não tem por onde seguir. É exatamente o beco que o `#1a` evitou na lista,
com o `[+Novo]↻` da categoria dentro do mini-cadastro.

**A decidir:** se Categoria e Tipo ganham `[+Novo]↻` como a Marca (e o Tipo abre
o mesmo mini-cadastro do `#1a`, que já pede nome, categoria e unidade base), ou
se o caminho é outro.

## A4 · Preferência da lista apontando para marca ou produto desativado
`requisitos:603` e `requisitos:1335` (a regra que existe)

Em 26/08 ficou decidido que **desativar um tipo que está na lista avisa antes e
remove o item**. A regra cobre o tipo — e só ele. O item da lista, porém, guarda
mais duas coisas: a **marca** e a **embalagem preferidas** ("leite Italac 1 L").

Nada diz o que acontece com um item cuja marca preferida foi desativada, ou cuja
embalagem preferida foi desativada, ou cujo produto (a folha) foi desativado. É
estado alcançável na primeira faxina de cadastro, e o item continua na lista
apontando para um cadastro que sumiu do lançamento — o mesmo problema que a
decisão do tipo fechou, um nível abaixo.

A boa notícia é que aqui a resposta é bem mais barata que a do tipo: a
preferência **não manda na baixa**, é lembrete. Cair em silêncio, deixando o
item com o tipo e sem a preferência, não quebra nada — mas precisa estar escrito,
porque hoje o comportamento é indefinido e o aviso do tipo cria a expectativa
oposta.

**A decidir:** a preferência morta cai sozinha e o item fica só com o tipo, ou o
desativar avisa como avisa no tipo.

## A5 · Subir o teto no meio do mês não rearma o aviso já dado
`requisitos:1215` (o rearme) · `requisitos:1207` (as três coisas que avaliam)

A regra do rearme está escrita assim: "se uma **correção ou exclusão de compra**
derrubar o mês para baixo de um dos cortes, aquele aviso volta a ficar disponível
e dispara de novo quando o corte for cruzado outra vez".

Só que existe uma quarta coisa que derruba o mês para baixo de um corte: **subir
o teto**. Teto de R$ 1.500, gasto de R$ 1.300, aviso dos 80% já dado. Ele sobe o
teto para R$ 1.800 — o mês volta a 72%, abaixo do corte. As compras seguintes
levam o mês a R$ 1.500 (83% do teto novo) e **nenhum aviso dispara**, porque o
dos 80% já foi consumido contra o teto antigo.

É a imagem espelhada da decisão (5) de 26/08, que fez a **configuração do teto**
avaliar os cortes justamente para o mês em que o teto nasce não ficar sem aviso.
A configuração passou a ligar o aviso; falta ela poder desligá-lo de volta.

**A decidir:** se alterar o teto rearma os cortes que o mês deixou de cruzar —
que é o simétrico do que já foi decidido — ou se o aviso continua sendo uma vez
por mês, doa o que doer.

## A6 · Apagar a compra devolve o item, mas não se sabe o que faz com o "não encontrei"
`requisitos:1188` (a marcação cai na compra) · `requisitos:1292` (apagar desfaz)

Duas regras de 26/08 se cruzam sem que ninguém tenha escrito o que sai do
cruzamento:

- a marcação "não encontrei" **cai sozinha na primeira compra daquele tipo,
  mesmo parcial**, porque comprar prova que ele achou o produto;
- apagar a compra **desfaz o efeito dela sobre a lista** — os itens voltam, o
  saldo abatido é devolvido —, e corrigir faz o mesmo, "como se a compra
  tivesse sido lançada já corrigida".

Ela marcou o detergente como "não encontrei". Ele lança uma compra com
detergente e a marcação cai. A compra estava errada e é apagada. **A marcação
volta?** Pela lógica de "a lista fica como estaria se a compra nunca tivesse
sido lançada", sim. Pela letra das duas regras, nada diz. O mesmo vale para a
correção que remove o detergente da compra.

Não é caso raro: a marcação "não encontrei" é o recado que o outro lê na volta,
e derrubá-lo por engano manda a pessoa ao mercado atrás de algo que continua não
tendo lá.

**A decidir:** se o desfazer da compra alcança a marcação ou para no item e no
saldo.

## A7 · A lista comum não tem regra de atualização
`requisitos:199` (o requisito 2) · `wireframes:404-410` (os estados da Tela 1)

O requisito 2 é escrito como se fosse instantâneo: "ela adiciona 'leite' pelo
celular dela e **ele vê** 'leite' na lista dele; ele marca como pego e **ela vê**
que ele já pegou". O rascunho, porém, só tem estado de **carregando na
abertura** — "a lista vem de fora do celular, então sempre há espera na
abertura". Nada diz o que acontece com a lista **aberta na mão dele, no
corredor**, quando ela mexe na lista de casa.

Isso importa mais neste sistema do que importaria em outro, porque o app inteiro
foi desenhado em cima de os dois estarem no mercado em momentos diferentes — é a
razão de existir do aviso de item repetido. Se a lista só se atualiza ao abrir a
tela, o caso de uso principal ("um não sabe o que o outro já comprou") continua
de pé com o app na mão.

E há o outro lado: os dois tocando no mesmo item ao mesmo tempo, ou ela apagando
o item que ele acabou de marcar. Nada no documento diz quem ganha.

**A decidir:** se a lista se atualiza sozinha enquanto está aberta (e com que
frequência), ou se atualizar é um gesto dele — puxar para baixo, um botão. É
decisão de negócio, não de tecnologia: muda o que ele vê no corredor.

---

# Faixa B — decisão já tomada, falta escrever

## B1 · O requisito 17 ainda fala em "embalagens" onde o rascunho já fala em "produtos"
`requisitos:655` × `wireframes:755`

Uma revisão de 21/08 já achou e corrigiu exatamente isto — está no histórico:
"o texto dizia 'a lista traz as embalagens do tipo', o que **excluía o vendido a
peso**, que não tem embalagem nenhuma e mesmo assim é uma das linhas — passou a
dizer 'os produtos do tipo'". **A correção foi aplicada só no rascunho de
telas.** O requisito 17 continua dizendo "só as **embalagens** compradas nos
últimos 3 meses" e "entre as **embalagens** do mesmo tipo de produto".

Fica pior por contradizer a decisão (11) de 26/08, que promoveu o produto
vendido a peso a opção da calculadora — e por se contradizer dentro do próprio
parágrafo, que duas linhas abaixo diz "produto vendido a peso entra como mais
uma linha".

**Correção:** trocar "embalagens" por "produtos do tipo" nos dois pontos do
requisito 17, mantendo "embalagens" só onde o exemplo é de produto embalado.

## B2 · O mini-cadastro de tipo abre com "kg" já marcado, contra a própria nota
`wireframes:455` (o quadro) × `wireframes:485` (a nota)

A nota do `#1a` é categórica: "**A unidade base é obrigatória e não tem padrão
adivinhado.** É ela que decide se a quantidade da lista é em quilos, litros ou
unidades, e trocá-la depois é o único caminho sem volta do cadastro".

O quadro logo acima desenha `Medido em: (•) kg ( ) L ( ) un` — com o quilo já
marcado. É um padrão adivinhado, e no campo que a própria nota chama de único
caminho sem volta. Quem criar "achocolatado" às pressas e não olhar sai com um
tipo medido em quilo.

**Correção:** as três opções em branco no quadro — `( ) kg ( ) L ( ) un` — e o
`[ Criar e adicionar ]` travado até uma ser escolhida.

---

# Faixa C — texto, exemplos e notação

## C1 · A Tela 2 ainda chama a janela fechada de suposição
`wireframes:549` × `wireframes:1253` e `wireframes:1292`

A nota da Tela 2 diz que o mês em curso fica de fora da janela "(**suposição
declarada na Tela 6**)". A Tela 6, no rodapé, diz o contrário desde a 1.8:
"**Confirmado por ele em 26/08/2026** (era suposição até a 1.7)". E o checklist
da 1.9 afirma que "**nenhuma suposição em aberto no arquivo**".

É o único resto da confirmação da janela fechada, e é o tipo de linha que faz
quem for construir achar que ainda há o que perguntar.

**Correção:** trocar o parêntese por "(janela fechada — ver a Tela 6)".

## C2 · O checklist promete "carregando" em telas que não têm
`wireframes:1279`

O item diz: "Estados de carregando e erro descritos **nas seis telas e nos dois
painéis** (`#1a` e `#3a`)". O estado de carregando existe em cinco lugares —
Tela 1, `#1a`, Tela 2, Tela 5 e Tela 6. **Telas 3, 4 e o painel `#3a` não têm.**

E as três carregam dados de fora do celular: a Tela 3 busca mercados e produtos,
a Tela 4 busca categorias, tipos e marcas, e o `#3a` busca os produtos do tipo
com o preço da última compra de cada um. Numa lista que "vem de fora do celular,
então sempre há espera na abertura", elas são as que mais esperam.

**Correção:** ou os três estados são escritos, ou o checklist passa a dizer onde
o carregando existe — mas não pode ficar afirmando o que não está lá.

## C3 · A cobertura do PWA conta cinco diálogos e são seis
`wireframes:1314`

A lista nomeia: adicionar item (`#1a`, com o mini-cadastro de tipo dentro),
edição de item da lista, mercado novo, marca nova e comparar custo. Falta o
**diálogo de categoria nova**, que a nota do `#1a` descreve com todas as letras
— "Categoria também é criável na hora, pelo `[+Novo]↻`, num diálogo de um campo
só" — e que quem for montar o PWA precisa desenhar como desenha o do mercado e o
da marca.

**Correção:** "seis diálogos", com o de categoria nova na lista. Se A3 for
decidido a favor de dar `[+Novo]` a Categoria e Tipo na Tela 4, o mesmo diálogo
serve nos dois lugares.

## C4 · O `👤` não está na tabela de notação
`wireframes:328`, `1007`, `1070`, `1135` (o uso) · `wireframes:213-234` (a tabela)

O `👤 Leandro ↻` aparece no cabeçalho de quatro quadros e tem regra de negócio
própria — mostra quem está usando o aparelho e troca com um toque, sem senha. A
tabela de convenções lista `≡`, `⚠`, `★`, `══`, `░░░` e `↕`, mas não ele.

Vale conferir de quebra contra a regra "sem ícone decorativo, só estrutura": o
`👤` não é decorativo, mas é o único emoji do arquivo e o único elemento com
`↻` fora de colchetes.

**Correção:** uma linha na tabela — `👤 Nome ↻ | Quem está usando este aparelho;
toca para trocar | botão de perfil`.

## C5 · O `[–]` é escrito de dois jeitos
`wireframes:223` (a tabela) × `wireframes:976` e `978` (os quadros)

A tabela define `[–] Opção` — o traço **dentro** do colchete, antes do texto, que
é como o `#1a` escreve o tipo travado (`[–] Leite (já está na lista)`). Os
quadros da Tela 4 escrevem o oposto: `[ + Adicionar embalagem ][–]` e
`[ Salvar 1 produto ][–]`, com o traço **depois** do botão.

A notação foi corrigida na 1.8 justamente para o `[–]` valer para item e botão;
o que ficou faltando é escrever os dois na mesma forma.

**Correção:** escolher uma — `[–]` colado depois do botão é o mais legível em
botão comprido — e ajustar a tabela e os três usos.

## C6 · O botão "Comparar custo" tem duas posições registradas
`wireframes:113` e `requisitos:1753` × `requisitos:630` e `requisitos:1779`

O requisito 17 e o quadro da Tela 3 dizem que o botão fica **"logo abaixo do
campo Produto"**, em linha própria. O changelog da 1.5 e o histórico de 21/08
dizem que ele nasceu **"ao lado do campo Produto"**.

O curioso é que o mesmo parágrafo do histórico se desmente sozinho: começa com
"aberta por um atalho ao lado do campo 'Produto'" e, mais abaixo, registra a
decisão dele — "o gatilho é um **botão em linha própria abaixo do campo
'Produto'**" — e o descarte explícito do "atalho colado no campo, porque a linha
ficaria com três alvos de toque".

**Correção:** trocar "ao lado" por "abaixo" nos dois pontos. O que vale é a
decisão registrada logo adiante, no mesmo parágrafo.

## C7 · A Tela 2 abre com um item já marcado e não diz por quê
`wireframes:518`

O quadro mostra `{x} Papel higiênico — 12 un` marcado, junto com `{ } Arroz` e
`{ } Café` desmarcados. Nenhuma nota diz se a sugestão vem com alguma coisa
pré-selecionada ou se o quadro mostra o estado depois de ele marcar.

O `#3a` teve esse cuidado — "**só a linha do produto que estava sendo lançado
abre marcada**; o quadro acima mostra o estado **depois** de ele marcar a
segunda". A Tela 2 não tem a frase equivalente, e a diferença muda o
comportamento: pré-marcar tudo faria "Adicionar selecionados" despejar a
sugestão inteira na lista com um toque.

**Correção:** uma nota dizendo que a tela abre com tudo desmarcado e que o
quadro é o estado depois da escolha.

## C8 · O exemplo da Tela 6 perdeu dois itens da Tela 1
`wireframes:1155` (a contagem) · `wireframes:1223` (a nota do "não encontrei")

A Tela 1 tem cinco itens: acém moído, frango, sabão em pó, detergente e leite. A
Tela 6 mostra quatro com saldo (acém, leite, sabão em pó e café) e o botão
`[ Ver todos (4 sem faltar) ]`, que abre com exatamente quatro (refrigerante,
mussarela, iogurte, ovo). **Frango e detergente não aparecem em nenhuma das duas
faixas** — e o frango tem histórico, aparece no relatório da Tela 5 com 8 kg.

O quadro se declara recorte, o que salva a primeira faixa. Mas a contagem "(4
sem faltar)" é um número exato que afirma completude, e o `[ Ver todos ]` mostra
os quatro sem reticências. Pior: a nota logo abaixo promete justamente o caso do
detergente — "aparece todo tipo com saldo no mês, **inclusive o que está na
lista marcado como 'não encontrei'** — para esse, faltar continua faltando" — e
o detergente é o único item marcado assim no rascunho inteiro, sem aparecer aqui.

É a mesma classe de achado que a revisão de 21/08 já corrigiu uma vez nesta
tela, quando os exemplos da Tela 6 não fechavam com os das Telas 1 e 2.

**Correção:** pôr o detergente na faixa de cima (é o que a nota promete) e o
frango numa das duas, ou trocar a contagem exata por reticências, que é como o
resto do arquivo marca recorte.

---

# O que foi verificado e está certo

Registrado para não ser revisitado:

- **Todas as contas dos exemplos fecham.** Tela 3: R$ 62 + R$ 10 = R$ 72,00 de
  total; 1 fardo a R$ 56,70 dá R$ 13,50 o litro contra R$ 11,43 de média, os 18%
  do aviso. `#3a`: R$ 33,00 ÷ 2,3 kg = R$ 14,3478, contra R$ 20,00 do 500 g, dá
  os 28%. Requisito 17: a garrafa de 2 L a R$ 5,00 o litro sai 56% mais barata
  que a lata e 50% mais barata que o fardo. Tela 5: acém 6 kg / R$ 32 o quilo /
  R$ 192; sabão em pó 6,8 kg / R$ 136, com Omo 4,3 kg / R$ 86 e Tixan 2,5 kg /
  R$ 50 somando exatamente o tipo; Carnes 40% de R$ 1.200 = R$ 480, com os dois
  tipos mostrados somando os R$ 336 que a nota declara.
- **Os preços do Omo são os mesmos nas três telas** onde aparecem — R$ 10,00 no
  500 g, R$ 20,00 o quilo —, que era uma pendência fechada na 1.8.
- **As duas janelas estão certas em todos os pontos de uso:** rolante no alerta
  de alta (Tela 3), na comparação entre mercados (Tela 5) e na lista curta do
  `#3a`; fechada na sugestão (Tela 2), na média e na Tela 6. Não sobrou nenhum
  "últimos 3 meses" no lado errado.
- **O divisor proporcional conta igual nos dois documentos e nas duas telas**,
  incluindo a exceção do produto nascido no mês em curso — o iogurte da Tela 6
  ("3 de 3 L") e o café ("0,7 kg") batem com os critérios de aceite do
  requisito 8.
- **As datas do requisito 6 batem com o quadro da Tela 5**: 03/07 no mais barato
  e 12/08 e 18/08 nos dois mais caros, com a ordenação por preço.
- **A ordem de construção cobre os 18 requisitos**, sem repetir nem faltar
  nenhum, e respeita as dependências declaradas (14 primeiro, 17 por último).
- **A barra inferior é coerente nas três telas** que a têm, com o destino da
  própria tela sem seta.
- **`faltam` (Tela 6) e `restam` (Tela 1) nunca trocam de lugar** em nenhum dos
  dois documentos.

---

# Quarta passada — sobre o texto já corrigido

Uma releitura das próprias correções, feita depois de tudo aplicado. **Seis
achados, todos fechados.** Três eram resíduo das correções do dia — o preço a
pagar por mexer em dois documentos ao mesmo tempo —, um era achado velho que as
três passadas não tinham visto, e dois eram redação.

## Q1 · A decisão do rótulo não chegou na calculadora
`requisitos:715` · `wireframes:897`

A decisão **A1** trocou "Peso (kg)" fixo pelo rótulo vindo da unidade base — e
ficou nas duas telas onde o lançamento pede a quantidade. A calculadora, que tem
regra própria para o produto vendido a peso, continuou dizendo que a linha dele
abre **"com o preço do quilo"**. Num tipo medido em litro, a mesma linha teria de
abrir com o preço do litro.

**Corrigido:** "o preço da unidade base do tipo — o quilo da mussarela do balcão,
o litro do azeite a granel". Os dois documentos.

## Q2 · Marca e mercado continuavam sem trava de duplicidade
`requisitos:585` (o critério que já prometia) · `requisitos:102` e `1144`

Este escapou das três passadas, e ficou à vista justamente porque a decisão
**A2** travou tipo e categoria. O documento inteiro se apoia em duas afirmações
que nenhuma regra entregava:

- o critério de aceite do requisito 15 — "não existe jeito de o mesmo mercado
  virar dois por causa de diferença de escrita";
- a razão de a marca ter virado cadastro — "'Omo' e 'OMO' digitados em dias
  diferentes partiriam o histórico de preço da marca em dois".

Escolher de uma lista resolve **metade** do problema: evita o erro de digitação
na hora de usar. A outra metade é o `[+Novo]` recusar o que já existe — e era
essa que faltava, nos dois. Com ela faltando, a proteção que fez marca e mercado
virarem cadastro podia ser furada pela porta por onde eles nascem.

**Corrigido:** os quatro cadastros que sustentam soma, agrupamento ou comparação
de preço — tipo, categoria, marca e mercado — passam a usar **a mesma
comparação**: ignorando maiúsculas, espaço sobrando e acento. Requisitos 1 e 15,
regras de negócio, Tela 3 e Tela 4.

## Q3 · A descrição comparava por uma régua diferente
`requisitos:120`, `1018`, `1091`, `1611` · `wireframes:62`

Com tipo, categoria, marca e mercado ignorando acento, a **descrição** ficou
sendo a única comparação do documento que não ignora — e é ela que separa
"Coca-Cola zero" de "Coca-Cola original", barrando ou liberando um cadastro
novo. Duas réguas para a mesma pergunta ("isto já existe?") é o tipo de coisa que
quem for construir implementa de dois jeitos.

**Corrigido:** a descrição passa a ignorar maiúsculas, espaço sobrando **e**
acento, como as outras quatro. Vale a pena saber o que isso muda: "limão" e
"limao" deixam de ser dois produtos. Se ele preferir manter a régua antiga só
para a descrição, é uma palavra a tirar em cinco lugares.

## Q4 · Um estado da Tela 4 descrevia um caso que deixou de existir
`wireframes:1073`

O estado "antes da unidade base estar definida" citava "um tipo novo cuja unidade
ele ainda não escolheu". Com **A3**, o tipo novo passa a nascer no mini-cadastro,
que **exige** a unidade — o caso não existe mais.

**Corrigido:** o estado virou "antes do tipo estar escolhido", com o caso
eliminado declarado.

## Q5 · "O toque dela" lia-se como a esposa
`requisitos:224`

Na regra nova da faixa de atualização, "é o toque dela que refaz a lista" queria
dizer o toque na faixa. Neste documento, "ela" é sempre a esposa.

**Corrigido:** "o toque na faixa".

## Q6 · Um parágrafo emendado nos Pontos em aberto
`requisitos:1508`

A frase acrescentada colou no parágrafo antigo e deixou um "No mesmo dia" sem a
frase que o sustentava, além de uma linha fora da largura do arquivo.

**Corrigido:** o parágrafo foi reescrito inteiro.
