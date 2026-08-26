# Pendências da revisão de consistência — 21/08/2026

Achados da revisão cruzada de `requisitos-lista-de-compras.md` e
`wireframes-lista-de-compras.md` que **ainda não foram corrigidos**. Os itens 3,
5, 6, 7 e 8 do relatório original já foram decididos e aplicados nos dois
documentos — ver a entrada de 21/08/2026 no Histórico de sessões.

Os números de linha valem para os arquivos como estão hoje, depois das correções
já aplicadas.

---

## Resíduos de decisões já tomadas — correção mecânica, sem consultar ninguém

### 1. A primeira regra de negócio ainda diz que o 5º nível é "peso"
`requisitos:766-767`

> "A classificação tem cinco níveis: categoria → tipo do produto → marca →
> descrição → **peso**."

A sessão de 21/08 promoveu a **embalagem** a quinto nível. O requisito 1
(`requisitos:96`), a seção "Informações e volume" (`requisitos:700`) e o
glossário já dizem "embalagem"; esta é a única regra que ficou para trás — e é a
regra fundadora do modelo de dados.

**Correção:** trocar "peso" por "embalagem" e ajustar o exemplo, que hoje termina
em "500 g" como se fosse peso e não nome de embalagem.

### 2. "Com os cinco níveis" contradiz "nos níveis que se aplicam"
`requisitos:224`

> "Produto novo é cadastrado completo na hora, com os cinco níveis."

O histórico de 18/08 registra a troca por "nos níveis que se aplicam", *porque é
impossível para produto sem marca*, e a correção foi aplicada em "Quando dá
errado" (`requisitos:671`) mas não aqui. Como está, o requisito 3 exige marca e
embalagem no acém moído.

**Correção:** "cadastrado na hora, nos níveis que se aplicam a ele".

### 23. "a granel" sobreviveu no glossário
`requisitos:1226`

> "quantidade de embalagens (ou o peso, no produto **a granel**)"

O histórico de 18/08 registra a troca de "granel" por "vendido a peso", que é o
termo do glossário. Este é o único resto.

### 24. "Quantas caixas" no critério de aceite do requisito 3
`requisitos:218`

> "ao lançar, o produto já vem escolhido e ele só digita **quantas caixas** e o
> valor."

Contradiz a eliminação do rótulo variável decidida em 21/08: o campo é só
"Quantidade", e quem diz o que está sendo contado é o nome da embalagem.

---

## Lacunas — precisam de decisão antes de virar código

### 4. Não existe fluxo de adicionar item à lista
`wireframes:273` (o botão) — e nada mais, em nenhum dos dois documentos

O botão `[ + Adicionar item ]↻` aparece uma única vez na Tela 1 e não tem nota,
diálogo nem estado. O único diálogo descrito é o de **edição** — quantidade,
marca e embalagem preferidas, remover —, que abre ao tocar no *texto* de um item
que já existe.

Na prática o buraco aparece assim: acabou o achocolatado, ela pega o celular e
toca em "+ Adicionar item". Aí o documento para. Ela digita o nome num campo?
Escolhe de uma lista dos tipos já cadastrados? E se "achocolatado" nunca foi
comprado — logo não existe como tipo no sistema —, ela consegue adicionar assim
mesmo? Essa última pergunta não é detalhe: a lista **agrupa por categoria**
(requisito 11), e quem carrega a categoria é o tipo do produto. Item cujo tipo não
existe é item sem categoria, e não teria onde aparecer na Tela 1.

É o caminho mais usado do app — mais que lançar compra — e o único da Tela 1 sem
regra escrita.

**A decidir, em duas partes:**

1. **Como o tipo é escolhido.** As opções que fazem sentido:
   - *Busca com criar na hora* — campo de busca sobre os tipos já cadastrados,
     com "Criar 'achocolatado'" como última linha quando nada bate, abrindo um
     mini-cadastro de tipo (nome + categoria + unidade base) sem sair da tela. É o
     mesmo padrão do mercado novo dentro do lançamento, e é o único que resolve o
     caso do item nunca comprado.
   - *Só tipos já cadastrados* — mais simples de construir, mas trava justamente
     quando ela lembra de algo novo no meio da semana, e o cadastro completo de
     produto é trabalho demais para "lembrei que acabou o achocolatado".
   - *Texto livre, classifica depois* — rápido de escrever, mas cria item que não
     abate com compra nenhuma (a baixa é pelo tipo) e contraria o "não fica item
     solto sem classificação" que já está em "Quando dá errado".
2. **O que o diálogo pede além do tipo.** Entrar só com o tipo, deixando
   quantidade e preferências para o diálogo de edição que já existe; ou emendar o
   diálogo de edição logo depois da escolha, já aberto para preencher.

### 9. Reclassificar produto pode cruzar famílias de medida
`requisitos:469-470` + `requisitos:1097-1100`

O requisito 16 permite "mudar um produto de tipo ou de categoria", e a regra diz
que a classificação nova vale para todo o histórico. O documento proíbe
*cadastrar* na medida errada ("Quando dá errado": creme de leite em 200 g num
tipo medido em litro), mas não proíbe *mover depois* um produto medido em litro
para um tipo medido em quilo — o que converteria o histórico entre grandezas
incompatíveis e faria o total do tipo somar volume com peso.

**A decidir:** o sistema bloqueia a troca quando a unidade base do tipo de destino
é diferente, ou permite e obriga a redigitar as embalagens?

### 10. "Último preço pago naquela embalagem" é ambíguo
`requisitos:501` · `wireframes:557`

O que o sistema guarda é o **valor total do item** e a quantidade
(`requisitos:718`). O preço de *uma* embalagem é derivado. Sem dizer que a
linha da calculadora abre com `total ÷ quantidade`, a linha do Omo 500g abriria
com R$ 15,00 (três pacotes comprados de uma vez) em vez de R$ 5,00.

**Correção sugerida:** escrever "o valor pago por **uma** embalagem na última
compra — o total do item dividido pela quantidade".

### 11. A Tela 6 muda a regra de baixa do item sem dizer
`requisitos:600-602` · `wireframes:915-919`

"Sabão em pó — na lista, **sem quantidade**" abre o diálogo "já com a quantidade
que falta preenchida" (2 kg). Se ele confirmar, o item deixa de sair na primeira
compra daquele tipo e passa a exigir 2 kg — mudança real de comportamento, contra
a promessa da própria tela ("esta tela nunca mexe na lista sozinha").

**A decidir:** o diálogo aberto a partir da Tela 6 sobre item que já está na lista
**sem** quantidade deve vir com o campo vazio, ou preenchido com o que falta?

### 12. Aviso de item repetido dispara em lançamento retroativo, com texto errado
`requisitos:374-378` e a regra correspondente

O aviso é retroativo e compara "compras do mesmo dia". Lançar hoje uma compra de
três semanas atrás pode disparar "vocês dois compraram leite **hoje**".

**A decidir:** limitar o aviso a compras cuja data seja de hoje (ou dos últimos
dias), ou manter e trocar o texto por "no mesmo dia".

### 13. "Não encontrei" não tem regra de limpeza
`requisitos:979-980`

O item fica marcado até ser comprado ou removido. Numa compra parcial ele
continua na lista com saldo: continua marcado "não encontrei"? E se ele encontrar
o produto na ida seguinte mas ainda não tiver lançado, nada limpa a marca.

**A decidir:** a marcação cai sozinha na primeira compra daquele tipo (mesmo
parcial), ou só quando ele girar o toque de volta?

### 14. Estado "sem conexão" só existe em duas das seis telas
`wireframes:329` (Tela 1) e o equivalente na Tela 6

O sistema inteiro exige internet. A Tela 3 é a mais cara: se a conexão cair no
`[ Salvar compra ]`, nada diz se os itens já digitados sobrevivem — o estado dela
só prevê "Não foi possível salvar, tente de novo". Vinte itens digitados perdidos
matam o hábito de lançar, que é o maior risco declarado do projeto.

**A decidir:** o lançamento em andamento fica guardado no aparelho até conseguir
salvar, ou some?

### 15. O relatório não mostra gasto por marca
`requisitos:741` e o requisito 4 · `wireframes:780`

O requisito 4 pede o relatório "agrupado por categoria, por tipo de produto e por
marca", e "Informações" pede "o total gasto naquele tipo **e em cada marca**". A
Tela 5 abre o tipo mostrando só quantidade — "└ Omo 4,3 kg / Tixan 2,5 kg" —, sem
R$.

**Correção:** acrescentar o valor em cada marca na linha aberta do tipo.

### 16. O requisito 16 não cobre mercado; o wireframe cobre
`requisitos:469-471` x `wireframes:231-232`

O requisito lista "categoria, tipo, marca ou produto". O wireframe diz
"categoria, tipo, marca, produto **e mercado**". Renomear ou desativar mercado é
caso real — mercado que fechou, nome digitado errado — e não tem requisito que o
sustente.

### 17. Item da lista apontando para tipo desativado
`requisitos:1103-1106`

Desativar tira o tipo das sugestões e do lançamento, mas nada diz o que acontece
com um item que já está na lista apontando para ele: some, fica travado, ou
continua normal e volta a ser comprável.

---

## Exemplos e texto — não bloqueiam, mas confundem quem lê

### 18. A faixa "JÁ ATINGIRAM A MÉDIA DO MÊS" classifica errado o produto novo
`wireframes:900`

O iogurte aparece como `3 de 3 L` numa faixa chamada "já atingiram a média" — mas
ele não atingiu meta nenhuma: a média dele *é* a própria compra, por não haver mês
fechado. O contador "(4 já atingiram)" o inclui na conta.

**Sugestão:** faixa própria, ou rótulo do tipo "sem média ainda".

### 19. Aviso de alta no quadro da Tela 3 com os campos vazios
`wireframes:425` e a linha seguinte

O `⚠ Subiu 18% sobre a média` aparece acima de `Quantidade: __  Valor: R$ ___`,
ambos vazios — estado impossível, já que o alerta depende do preço por unidade
base, que só existe depois de o valor ser preenchido.

### 20. O quadro do `#3a` contradiz a própria nota
`wireframes:524-525`

Tixan 1kg e Tixan 2kg aparecem com preço vazio **antes** de tocar em
`[ Ver todas do tipo ]`, contra a nota que diz que a lista abre só com as
embalagens compradas nos 3 meses e com preço preenchido. E duas linhas vêm `{x}`
marcadas, quando a nota justifica só uma (a do produto que estava sendo lançado).

### 21. "6,8 kg de sabão em pó" é trimestre no requisito e mês na tela
`requisitos:239` ("o relatório do trimestre mostra") x `wireframes:779`, num
quadro cujo período é 01/03 a 31/03.

### 22. Os preços do Omo divergem entre seções
- `requisitos:782-783`: 2,3 kg por R$ 46 = **R$ 20/kg**
- calculadora `#3a`: 2,3 kg por R$ 10,00 = **R$ 4,35/kg**, e 500 g por R$ 5,00 =
  R$ 10/kg
- `wireframes:814` (comparação entre mercados): Omo 500g a **R$ 20,00/kg**

O mesmo produto aparece com o preço por quilo dobrado ou pela metade conforme a
seção. No mesmo espírito, o critério do requisito 6 descreve "mais barato = 12/08,
mais caro = 18/08", enquanto a tela mostra o mais caro em 03/07.

### 25. O mapa de navegação diz que a Tela 6 "volta para 1"
`wireframes:215` x `wireframes:221` ("Alternar entre elas não é 'voltar'") e a
barra inferior da própria Tela 6. O mapa também não mostra o eixo 5↔6.

### 26. O checklist afirma estado de erro nas seis telas
`wireframes:993` x os Estados da Tela 1, que tem carregando, vazio e sem internet
— nenhum estado de erro.

### 27. "Cobertura da entrevista" está toda marcada
`requisitos:1264` em diante, incluindo "Validação de qualidade dos Essenciais",
com pontos ainda em aberto no documento e suposições de tela por confirmar.

### 28. Período livre com um seletor de data só
`wireframes:751`: `Período: ▤ 01/03 a 31/03` usa um único `▤`, que a notação
define como um `input[type=date]`. Período livre precisa de dois campos.
