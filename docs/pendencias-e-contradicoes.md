# Pendências e contradições — Lista de compras de supermercado

_Aberto em 26/08/2026 com 31 itens · **fechado em 26/08/2026, com os 31
resolvidos** · mais as **três últimas suposições**, decididas no mesmo dia (ver
"As três últimas", no fim) · fontes: `requisitos-lista-de-compras.md` (agora na
versão de 26/08) e `wireframes-lista-de-compras.md` (agora na **versão 1.9**)_

Este documento nasceu como lista de trabalho: os **23 itens** da revisão de 21/08
que continuavam válidos e os **8 achados novos** da varredura de 26/08. Todos os
31 foram fechados na sessão de decisão de 26/08/2026 e aplicados nos dois
documentos de origem — que agora **são a fonte da verdade**. O que segue vale
como registro de _o que foi decidido e por quê_, para ninguém reabrir a discussão
sem saber o que já foi resolvido.

- **Faixa A — 11 itens.** Precisavam de decisão dele. Todos decididos.
- **Faixa B — 10 itens.** Decisão já tomada, faltava escrever. Todos escritos.
- **Faixa C — 10 itens.** Texto e exemplos. Todos corrigidos.

**Nada continua em aberto.** As duas suposições que sobreviveram a esta sessão —
data futura no lançamento e produto cadastrado em duplicidade — foram decididas
por ele ainda em 26/08/2026, junto com uma terceira que só existia no rascunho de
telas. Estão no fim deste documento, em "As três últimas".

---

# Faixa A — as onze decisões dele

## A1 · Existiam duas janelas de "3 meses", e o documento nunca escolhia
**Decidido: assumir as duas, declaradas.** Metade do documento dizia "últimos 3
meses" (janela rolante, com o mês em curso) e a outra metade "os três meses
fechados anteriores" — e dois trechos costuravam as duas como se fossem uma só.

- **Janela rolante** — alerta de preço, comparação entre mercados e a lista curta
  da calculadora. A pergunta é "este preço está caro?", e a compra da semana
  passada é a informação mais valiosa que existe.
- **Janela fechada** — média mensal, sugestão da lista (requisito 8) e "falta
  comprar no mês" (requisito 18). A pergunta é "quanto costumamos consumir?", e o
  mês em curso ficaria dos dois lados da conta.

_Aplicado em:_ regras de negócio (bloco novo com as duas janelas), requisito 8,
glossário (verbete **Janela de referência**), Telas 2, 5 e 6 e o `#3a`. Fechou de
quebra o ponto em aberto sobre os três meses fechados, aberto desde 21/08, e o
**B9**.

## A2 · Não existia fluxo de adicionar item à lista
**Decidido: busca com criar na hora, e o item entra só com o tipo.** Campo de
busca sobre os tipos já cadastrados; quando nada bate, a última linha vira
`[ + Criar "achocolatado" ]`, que abre um mini-cadastro de tipo — nome, categoria
e unidade base — sem sair da tela. Quantidade, marca e embalagem preferidas
continuam no diálogo de edição.

_Aplicado em:_ requisito 2 (quatro regras e dois critérios de aceite) e o
**diálogo `#1a` — Adicionar item**, novo no rascunho de telas, com três quadros
(busca, nada encontrado e mini-cadastro), notas e estados.

## A3 · O lançamento em andamento sumia se a conexão caísse
**Decidido: guardar o rascunho no aparelho** até conseguir salvar. É a única
exceção ao "funciona só com internet". O rascunho é local e de quem está com o
aparelho, não aparece no celular do outro e é apagado assim que a compra é salva.

_Aplicado em:_ requisito 3, "Limites", "Não faz parte" e três estados novos da
Tela 3 (sem conexão com itens digitados, rascunho recuperado, salvo com sucesso).

## A4 · Reclassificar produto podia cruzar famílias de medida
**Decidido: bloquear.** A lista de tipos de destino só oferece tipos da mesma
unidade base; para os outros, o caminho é corrigir a unidade do tipo. Era o item
mais caro de errar da lista inteira — corrompia o histórico e não tinha desfazer.

_Aplicado em:_ requisito 16 (regra + critério de aceite) e regras de negócio.

## A5 · Teto configurado no meio do mês nunca disparava o aviso dos 80%
**Decidido: dispara na hora.** Passaram a avaliar os cortes três coisas, e não só
o lançamento: a compra lançada, a correção de compra e a **configuração do
teto**. Configurar R$ 1.500 com R$ 1.300 já gastos avisa na própria tela, e esse
aviso conta como o dos 80% daquele mês.

_Aplicado em:_ requisito 9 (regra + critério de aceite), regras de negócio e a
descrição da tela de configurações em "Fora deste rascunho" — o teto é definido
atrás do `≡`, e é lá que o aviso nasce.

## A6 · Item da lista apontando para tipo desativado
**Decidido: avisar e remover** — "achocolatado está em 1 item da lista — ele será
removido", com opção de cancelar. Ficou escrito também, porque não estava em
lugar nenhum, que **desativar tem volta**: existe reativar, atrás de um filtro
"mostrar desativados" na manutenção, e **reativar não devolve o item à lista**.

_Aplicado em:_ requisito 16 (duas regras e um critério) e regras de negócio.

## A7 · "Não encontrei" não tinha regra de limpeza
**Decidido: cai sozinha na primeira compra daquele tipo, mesmo parcial.** Comprar
prova que ele achou o produto; se faltar de novo, ela marca outra vez — no
diálogo do item, desde o **U3**. O saldo do mês na Tela 6 não muda por causa
disso.

_Aplicado em:_ regras de negócio e nota da Tela 6.

## A8 · A Tela 6 abria o diálogo com a quantidade preenchida
**Decidido: continua preenchida, com aviso.** O diálogo abre com os 2 kg que
faltam e, abaixo do campo, a linha "este item está na lista sem quantidade —
confirmar passa a pedir 2 kg". A tela continua não agindo sozinha, mas não troca
mais a regra de baixa em silêncio.

_Aplicado em:_ requisito 18 e nota nova da Tela 6.

## A9 · Aviso de item repetido disparava em lançamento retroativo, com texto errado
**Decidido: só dispara em compra de hoje ou de ontem**, e o texto acompanha a
data ("vocês dois compraram leite no dia 25/08"). O retroativo que resolve o caso
real — comprou de manhã, lançou à noite — continua de pé; lançar cupons atrasados
não produz mais uma fila de avisos sobre repetições já consumadas.

_Aplicado em:_ requisito 10 (duas regras e um critério de aceite) e o aviso ao
salvar, na Tela 3.

## A10 · O requisito 16 não cobria mercado; o wireframe cobria
**Decidido: mercado entra no requisito 16** — renomear (valendo para todo o
histórico) e desativar. Sem isso, "Carrefur" digitado uma vez viraria um segundo
mercado para sempre.

_Aplicado em:_ requisito 16 (enunciado, regra e critério de aceite).

## A11 · O botão "Comparar custo" sumia no tipo vendido a peso
**Decidido: produto vendido a peso conta como opção.** "Opção" passou a ser
qualquer produto ativo do tipo, embalado ou a peso — é o que põe a mussarela do
balcão contra a fatiada em pacote, como o requisito 17 já exigia. Tipo com um
único produto a peso continua sem botão: não há duas linhas para comparar, e
confrontar o quilo de dois mercados é pergunta da Tela 5.

_Aplicado em:_ requisito 17 e nota da Tela 3.

---

# Faixa B — decisão já tomada, agora escrita

| # | O que estava errado | Como ficou |
|---|---|---|
| B1 | A 1ª regra de negócio dizia que o 5º nível era "peso" | Virou **embalagem**, com o exemplo ajustado e a explicação de por que "500g" e "2,3kg" são dois produtos |
| B2 | O glossário definia marca como campo digitado | "Cadastro próprio, escolhida de uma lista e criável na hora; nunca digitada solta" |
| B3 | "Produto novo é cadastrado com os cinco níveis" | "Nos níveis que se aplicam a ele" — categoria e tipo sempre; o resto quando existir |
| B4 | "ele só digita quantas caixas e o valor" | "ele só digita a quantidade e o valor" |
| B5 | "a granel" sobrevivia no glossário | "vendido a peso", o termo do próprio glossário |
| B6 | "último preço pago naquela embalagem" era ambíguo | "o valor pago por **uma** embalagem — o total do item dividido pela quantidade", com o exemplo dos três pacotes por R$ 30 |
| B7 | O relatório não mostrava gasto por marca | Quantidade **e valor** por marca, no critério de aceite do requisito 4, em "Informações" e na Tela 5 |
| B8 | A fórmula do recálculo multiplicava embalagens por preço da unidade base | *Quantidade convertida para a unidade base × preço da unidade base*, com o fardo (4,2 L × R$ 11,43 = R$ 48) como segundo exemplo |
| B9 | O cabeçalho da Tela 2 contradizia a nota da própria tela | Caiu junto com o **A1**: o cabeçalho passou a dizer "três meses fechados anteriores" |
| B10 | A cobertura do PWA listava três diálogos | São **cinco**: `#1a` (novo), edição de item, mercado novo, marca nova e `#3a` |

---

# Faixa C — texto e exemplos

| # | O que estava errado | Como ficou |
|---|---|---|
| C1 | "Cobertura da entrevista" toda marcada, com três perguntas em aberto | Linha nova declarando as **duas** suposições que faltam; a terceira (os 3 meses) caiu com o **A1** |
| C2 | Os preços do Omo divergiam entre três seções | Preço único em todo o documento: **Omo 500g R$ 10,00 (R$ 20,00/kg)** e **Omo 2,3kg R$ 33,00 (R$ 14,35/kg, 28% mais barato)**. As datas da comparação entre mercados passaram a bater com o critério do requisito 6 — o mais barato é o mais **velho** (03/07), que é a lição da tela |
| C3 | "6,8 kg de sabão em pó" era trimestre no requisito e mês na tela | Virou "em março" / "01/03 a 31/03" nos dois — o quadro tem "gastou X de Y", que só existe em relatório de mês inteiro |
| C4 | O quadro do `#3a` contradizia a própria nota | Todas as linhas abrem com preço preenchido (Tixan 2kg saiu para trás do "ver todas do tipo"), e ficou escrito que **só a linha do produto em lançamento abre marcada** — o quadro mostra o estado depois de ele marcar a segunda |
| C5 | Aviso de alta acima dos campos vazios | O quadro mostra `Quantidade: 1  Valor: R$ 56,70`, e a nota diz que o alerta só aparece depois do valor preenchido |
| C6 | O mapa dizia que a Tela 6 "volta para 1" | O mapa ganhou o eixo da barra fixa (1 ↔ 6 ↔ 5) desenhado à parte, o `#1a` e a regra de onde `< Voltar` existe |
| C7 | O checklist afirmava estado de erro nas seis telas | A Tela 1 ganhou o estado de erro que faltava |
| C8 | Período livre com um seletor de data só | `▤ 01/03  a  ▤ 31/03` |
| C9 | A faixa "já atingiram a média" incluía o produto novo | Virou **"nada faltando este mês"**, e o botão, "(4 sem faltar)" — verdade também para o iogurte, que não atingiu meta nenhuma |
| C10 | `[–]` documentado como item e usado como botão | A notação passou a dizer "item **ou botão** travado" — um significado só, e o checklist explica |

---

# Achados da revisão de fechamento

Uma releitura cruzada depois de aplicar as 31 correções pegou **sete pontos** que
as próprias mudanças deixaram para trás, todos corrigidos na mesma sessão. Ficam
registrados porque são o tipo de resíduo que uma revisão rápida não veria:

1. A **regra de negócio do teto** continuava dizendo que só o *lançamento* faz o
   mês cruzar os 80% — o A5 tinha sido escrito no requisito 9 e não na regra.
2. O **requisito 18** não tinha ganhado o aviso do diálogo (A8), que só existia
   na nota da Tela 6.
3. O **aviso ao salvar da Tela 3** ainda dizia "compraram leite hoje" sem a
   janela de hoje/ontem nem o texto com data (A9).
4. A nota do `#3a` dizia que o custo por unidade base aparece em **cada linha**,
   contra a regra nova de que linha não marcada não concorre — virou "cada linha
   marcada".
5. A nota da Tela 5 ainda descrevia a divisão por marca **sem valor** ("Omo
   4,3 kg / Tixan 2,5 kg"), contra o próprio B7 que o quadro já aplicava.
6. O item já lançado no quadro da Tela 3 trazia **Omo 500g a R$ 12,90**, contra
   os R$ 10,00 que o C2 fixou — e a esse preço o sistema teria acusado alta de
   29%. Corrigido junto com o total da compra (R$ 72,00).
7. O critério do requisito 17 comprava o **fardo 12x350ml a R$ 42,00** enquanto o
   resto do documento usa R$ 48,00. Aqui o número ficou, com a promoção declarada
   no texto — é preço de etiqueta do dia, que é exatamente o que a calculadora
   aceita —, mas a divergência silenciosa saiu.

Duas decisões desta sessão também ganharam lugar no rascunho de telas, em "Fora
deste rascunho": o aviso do teto na tela de configurações (A5) e a manutenção do
cadastro com **reativar**, a remoção do item ao desativar o tipo (A6) e o
bloqueio de troca entre unidades base diferentes (A4).

---

# As três últimas

Fechadas em 26/08/2026, depois das 31. As duas primeiras estavam registradas nos
Pontos em aberto do documento de requisitos desde 18/08; a terceira vivia só
dentro do rascunho de telas, marcada como "suposição a confirmar" e nunca
promovida a ponto em aberto — o que já é o achado desta rodada. **Com elas, os
dois documentos ficam sem nenhuma pergunta pendente.**

## U1 · Data futura no lançamento
**Decidido: bloquear na origem.** O calendário do lançamento não deixa tocar em
nenhum dia depois de hoje — não é aviso que dá para atropelar. Data anterior
continua aceita, para compra esquecida. Um aviso ignorável mandaria o gasto para
o mês seguinte no primeiro escorregão de dedo, errando o relatório dos dois meses
e o aviso do teto junto.

_Aplicado em:_ requisito 3 (regra + critério de aceite), Pontos em aberto,
cobertura da entrevista e a nota da data na Tela 3.

## U2 · Cadastrar um produto que já existe
**Decidido: o cadastro é único por tipo + marca + descrição, e a repetição é
barrada.** A descrição entra na identidade porque é ela que separa "Coca-Cola
zero" de "Coca-Cola original"; em branco, também conta como valor. A **embalagem
fica de fora** — ela é o que se acrescenta depois, não o que distingue um
cadastro do outro.

Pôr a descrição na identidade cobra um preço, e ele foi pago na mesma sessão: um
texto livre que separa produtos volta a ser a porta que o cadastro de marca
fechou — "original", "Original" e "orig." virariam três produtos. A comparação
das três partes passou a **ignorar maiúsculas e espaço sobrando** (a mesma lógica
do "duas embalagens são iguais pelo conteúdo, não pelo texto") e o campo passou a
**sugerir as descrições já usadas** naquele tipo e naquela marca. Ela continua
livre, sem cadastro próprio: não entra em relatório nenhum, e um cadastro a mais
para manter custaria mais do que resolve.

Das três saídas possíveis ele escolheu a mais dura: **travar o salvar**, em vez
de salvar só as embalagens novas ou avisar e deixar duplicar. Para o bloqueio não
virar beco sem saída, ele abre o cadastro que já existe com a lista de embalagens
carregada — o caminho do requisito 16, agora a um toque, com a linha que estava
sendo montada descendo junto. Era a última porta aberta para o histórico de preço
rachar em dois, e um cadastro que cria quatro embalagens de uma vez multiplicava
por quatro a chance de acontecer.

_Aplicado em:_ requisito 1 (regra + critério de aceite), requisito 16, regras de
negócio, glossário (verbete novo **Cadastro de produto** e verbete **Descrição**
reescrito), "Informações", Pontos em aberto, cobertura da entrevista e a Tela 4 —
duas notas novas e o **estado de cadastro barrado**, desenhado.

## U3 · O ciclo de três estados da caixa do item
**Decidido: a caixa alterna só vazio ↔ pego; "não encontrei" vai para o diálogo**
do item, aberto ao tocar no texto. Os três estados que os requisitos exigem
continuam todos de pé — mudou o gesto. Girar os três na mesma caixa punia o erro
mais provável do corredor, o toque repetido por distração, com a consequência
mais cara: item comprado virava item não achado, que é o recado errado para quem
lê a lista depois e só cai sozinho na primeira compra daquele tipo. Descartados
manter o ciclo e usar toque longo, este por ser gesto invisível para quem não
souber que existe.

_Aplicado em:_ requisito 2 (regra + critério de aceite), regras de negócio,
glossário (verbete **Não encontrei**), Pontos em aberto — onde a suposição nunca
tinha entrado —, cobertura da entrevista, notas das Telas 1 e 6 e o checklist do
rascunho.

---

# Notas de procedência

- As decisões desta sessão estão registradas no **histórico de sessões** do
  documento de requisitos, na entrada de 26/08/2026, com o motivo de cada uma; as
  três últimas ganharam entrada própria, no mesmo dia.
- O rascunho de telas subiu para a **versão 1.8** com as 31 e para a **1.9** com
  as três últimas; o "o que mudou" no topo do arquivo resume as mudanças de tela
  de cada uma.
- Documentos anteriores, mantidos como histórico: `revisao-pendencias.md`
  (relatório de 21/08) e `triagem-pendencias.md` (triagem e varredura de 26/08).
