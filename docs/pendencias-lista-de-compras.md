# Pendências — o que depende de você

**Data:** 27/08/2026 · **revisado em 30/08/2026**, ao fim da Entrega 7 (H15 e H16)
**Fonte:** `tecnico §13`, `handoff §13` e `handoff §14`
**Este arquivo não é fonte da verdade** — é o inventário do que está aberto e **só você
pode fechar**. Tudo o que é código está no plano, não aqui.

Cada item diz **o que trava** e tem um espaço de **Resposta** para preencher. O que
estiver marcado `[x]` já foi verificado como feito no repositório.

---

## Resumo

| Bloco | Itens | Bloqueia |
|---|---|---|
| A — Contas e aparelhos | 3 | a 1ª migration e o 1º deploy |
| B — Decisões de schema | 6 | **as seis respondidas — cinco em 28/08, a B6 na H7** |
| C — Perguntas de negócio | 4 | **C1 respondida na H7, C2 na H11, C4 na H13**; resta a C3 |
| D — Status dos documentos | 3 | nada; são higiene de documento |
| E — Riscos aceitos | 2 | nada; são confirmação por escrito |

**O bloco B está fechado desde 28/08/2026** — a migration base já foi escrita com as cinco
respostas, e a **B6** nasceu e foi respondida ao escrever a H7 (abaixo). **O que trava o
próximo passo agora é só o bloco A:** sem os projetos Supabase (A1) nada do que está
versionado chega a um banco, e sem o Cloudflare (A3) nada chega ao iPhone.

**A Entrega 7 (30/08/2026) também não abriu pendência nenhuma**, e vale registrar por quê:
o `R7` ("nenhum limiar e nenhuma regra no SQL") foi honrado **sem migration nova**. O dado
da comparação entre mercados sai de um `select` do PostgREST, e a redução — qual é a compra
mais recente de cada mercado — é Dart, no domínio (decisão **D-q**). O precedente é o
`fetchRecentItems` da Tela 3, que escolhe a compra mais recente de cada folha pelo mesmo
motivo. Continuam **oito** migrations esperando o A1, e a H16 é exercitável hoje contra o
`shopping_list_dev` local.

**A Entrega 4 (30/08/2026) não abriu pendência nenhuma**, e fechou uma coisa que estava
implícita: a frase que barrava a criação por já existir um cadastro **desativado** mandava
a pessoa *"para a manutenção do cadastro"*. Com a H10 essa tela passou a existir — e a
decisão de 29/08 foi melhor que o desvio: **o `[ Reativar ]` está no próprio diálogo**,
nas quatro portas da Tela 4 e no `NewStoreDialog` da Tela 3, e a frase perdeu o destino.
Nada disso precisa de resposta sua; está registrado para não ser reaberto.

**Duas coisas continuam esperando A1**, e são as cinco migrations e o seed: tudo foi
aplicado e conferido num Postgres 17 local (inclusive os sete casos de
`purchase_correction_cases.sql`), e **nada foi aplicado em `dev` nem em `prod`**.

---

## A. Contas, aparelhos e infraestrutura

Nada disso está no repositório e nenhum deles eu consigo fazer por você.

### A1 — Projetos Supabase `dev` e `prod` `(tecnico §13, pendência 1)`

**O que fazer:** criar os **dois** projetos no painel do Supabase e anotar, de cada um, a
**URL** e a **chave anônima** (a `publishable key` que o painel mostra).

**Situação hoje:** o `.mcp.json` do repositório aponta para **um** projeto
(`project_ref=sxwyundsrbvbmmacgngs`). Não dá para saber pelo repositório se ele é o `dev`
ou o `prod`, nem se o segundo existe.

**Por que dois:** decisão 9 — base única foi descartada para não arriscar histórico real
numa migration.

**Trava:** aplicar as migrations (elas já estão escritas e versionadas em
`supabase/migrations/`, e foram validadas contra um Postgres 17 local) e qualquer
`flutter run` fora dos fakes.

**Resposta:**
- `dev` — **não existe** (31/08/2026): a org `Leandro` está no teto de dois projetos ativos do
  plano Free (`shopping_list` e `lions_club_points`). Criar exige pausar um deles ou plano pago.
- `prod` — `sxwyundsrbvbmmacgngs` · `https://sxwyundsrbvbmmacgngs.supabase.co` · chave anônima: ` `
  **As nove migrations foram aplicadas nele em 31/08/2026**; o seed **não**, e não deve ser.
  Decisão do dia: enquanto o `prod` não tiver histórico real, ele é o único ambiente — divergência
  consciente da decisão 9, a reabrir quando o `dev` nascer.
- O `project_ref` do `.mcp.json` (`sxwyundsrbvbmmacgngs`) é o: ( ) dev **(x) prod** — respondido em 31/08/2026

> As chaves **nunca** são commitadas: entram por `--dart-define` no build e como
> *secret* no GitHub Actions.

---

### A2 — Teste de digitação no iPhone 12 — a S1 `(tecnico §13, pendência 2)`

**O que fazer:** abrir no **iPhone 12**, com o app **instalado na tela de início**, um
formulário de três campos em Flutter Web e cronometrar a digitação. Medir `R1`
(desempenho) e `R10` (teclado cobrindo campo, foco escapando, cursor fora de lugar)
**juntos**.

**Por que é o primeiro de tudo:** o requisito 3 é 20 campos em 2 minutos, oito vezes por
mês. Se a digitação não servir, a decisão de PWA cai no dia 1 — e não depois de 40 dias
de tela construída. É o **risco principal** do projeto.

**Trava:** a 1ª tela de verdade (H1 em diante).

**Depende de:** A3 — sem HTTPS não há como pôr o formulário no iPhone nem adicioná-lo à
tela de início.

**Feito em 28/08/2026:** o formulário de três campos está em `/spike` (`Teste de
digitação`) — texto livre, número inteiro e valor, que são os três teclados do iOS que a
Tela 3 usa. O cronômetro começa na **primeira tecla**, não na abertura. A rota passa pelo
`redirect` sem perguntar quem está usando, para a pergunta não entrar na medição.
**Cronometrar nos dois aparelhos é você** — e a tela, a rota e o teste dela são apagados
assim que este item estiver respondido.

**Resposta:**
- Tempo dos 3 campos: ` ` · Teclado cobriu o campo? ( ) sim ( ) não
- Veredito: ( ) PWA se sustenta ( ) PWA não serve — reabrir a decisão 2

---

### A3 — Cloudflare Pages e o subdomínio `(tecnico §13, pendência 3)`

**O que fazer:** criar o projeto no Cloudflare Pages, definir o **subdomínio** e gerar um
**API token** com permissão de publicar.

**Regra do subdomínio:** **não adivinhável** (`tecnico §9`). Nada de `shopping-list` puro
— a URL não divulgada é a **única** barreira de segurança do sistema (decisão 6: sem
login, RLS permissiva, chave anônima pública).

**Trava:** o 1º deploy, a S1 (A2) e, com eles, tudo o que se testa no aparelho.

**O que já está feito (28/08/2026):** `.github/workflows/deploy.yml` existe e roda
`flutter analyze`, `flutter test --coverage`, o piso de cobertura e o `flutter build web`
a cada push. **O passo de publicar é pulado — não falha — enquanto os secrets não
existirem**, e a Action diz na saída exatamente o que falta. `main` publica contra o
`prod`; qualquer outra branch publica preview contra o `dev`, e **preview nunca aponta
para o `prod`**.

> ⚠️ **Abra uma branch antes do primeiro push.** O repositório está em `main`, e é dali
> que a Action publica contra produção. A S1 é medição — ela não deve sair contra a base
> sem backup do `R13`.

**Resposta:**
- Subdomínio: ` `
- Variável de repositório (`Settings → Secrets and variables → Actions → Variables`):
  `[ ] CLOUDFLARE_PROJECT_NAME`
- Secrets criados no GitHub (`Settings → Secrets → Actions`):
  `[ ] CLOUDFLARE_API_TOKEN` `[ ] CLOUDFLARE_ACCOUNT_ID`
  `[ ] SUPABASE_URL_DEV` `[ ] SUPABASE_ANON_KEY_DEV`
  `[ ] SUPABASE_URL_PROD` `[ ] SUPABASE_ANON_KEY_PROD`

---

### A4 — `[x]` Manifest, ícones e textos do PWA `(tecnico §13, pendência 4)` — FEITO

Verificado no repositório: `web/manifest.json` e `web/index.html` estão com `name`,
`short_name`, `description`, `background_color`, `theme_color`, `<title>`,
`<meta name="description">` e `apple-mobile-web-app-title` preenchidos em pt-BR; os quatro
PNG de `web/icons/` foram trocados (gerados por `tool/make_icons.py`); e
`test/web_assets_test.dart` falha se as cores divergirem do tema.

**Sobra desta pendência — `[x]` FEITA em 28/08/2026:** as duas metas do `index.html`
(`apple-mobile-web-app-capable` e `robots: noindex`) e o `web/robots.txt`
(`tecnico §13`, pendências 5 e 6). Três testes novos em `test/web_assets_test.dart`
falham se qualquer uma das três sumir. **Nada sobrou deste item.**

---

## B. Decisões de schema — antes da 1ª migration

`handoff §14.3`. **Não são pergunta ao cliente, são decisão técnica** — mas mudam o
schema inteiro e não se corrigem depois, então precisam do seu "ok" antes de eu escrever
a migration. Já trago a recomendação: **basta você confirmar ou trocar.**

São **cinco**: B1 e B2 nasceram com o `handoff`; **B3, B4 e B5 nasceram nas revisões do
plano de implementação** (28/08/2026) e moravam só dentro dele — três dos cinco bloqueios
da migration eram invisíveis neste documento, que é onde a decisão é tomada. B1 a B4 travam
a migration; **B5 trava o seed**, e o seed grava valores num formato que o app depois
precisa saber ler.

### B1 — Como o produto vendido a peso vira folha

**O problema:** a compra aponta **sempre** para `product` (a folha). Mas a decisão 23 diz
que o vendido a peso **não tem folha de embalagem** — o acém moído não tem "350 ml".

**Recomendação (é o que o `handoff §8` chama de caminho mais simples):** a folha existe
sempre, e no vendido a peso as colunas de embalagem ficam **nulas**. Assim a compra tem
sempre um alvo único e nenhuma consulta de preço precisa de dois caminhos.

**Alternativa descartada:** a compra apontar ora para o cadastro, ora para a folha — isso
duplica toda consulta de preço, de relatório e de comparação entre mercados.

**Decisão (28/08/2026):** **(x) folha sempre, com embalagem nula.** Toda compra aponta
para uma linha de `product`; no vendido a peso as colunas de embalagem ficam nulas.
Registrado na migration `20260827090100_base_schema.sql`.

---

### B2 — Como a marca ausente entra no índice único de `product_registration`

**O problema:** a identidade do cadastro é **tipo + marca + descrição**, e o acém moído
não tem marca. No Postgres `NULL` **não é igual** a `NULL`, então dois "Coca-Cola sem
descrição" — ou dois "acém moído sem marca" — passam pela trava sem ela acusar nada.

**Recomendação:** `NULLS NOT DISTINCT` no índice único (Postgres 15+, e o Supabase está
acima disso). É uma linha, o `brand_id` continua honestamente `NULL`, e nenhuma consulta
precisa saber que existe uma marca-fantasma.

**Alternativa:** uma linha sentinela em `brand` ("sem marca"). Funciona, mas suja o
seletor de marcas, o relatório por marca (que é a lacuna **L2** logo abaixo) e a
manutenção do cadastro da H10.

**Decisão (28/08/2026):** **(x) `NULLS NOT DISTINCT`.** A tela mostra "Sem marca" como
opção; o banco grava `brand_id` nulo e o índice único trata dois nulos como iguais.
Nenhuma marca-fantasma aparece no seletor nem no relatório por marca.

---

### B3 — O índice único vale para o cadastro desativado?

**O problema:** os seis cadastros têm **desativação** (decisão 19 — nada é apagado, para o
histórico não se partir) **e** trava de nome repetido. Nenhum documento diz como os dois
convivem: se você desativar a categoria "Limpeza", o sistema deixa criar uma "Limpeza"
nova ou não?

**Recomendação — a trava vale também para o desativado.** Ao digitar "Limpeza" de novo, o
app não deixa criar e oferece **reativar a que existe**. O histórico continua inteiro num
cadastro só.

**Alternativa:** a trava só olha os ativos. Nasce uma segunda "Limpeza", e no dia em que a
primeira for reativada existem duas com o mesmo nome — com metade do histórico em cada
uma. **Isso não se desfaz.**

**O que muda no código depois de decidida:** a busca da trava passa a incluir os
desativados (H2 e H3) e a tela de manutenção (H10) ganha o caminho "reativar o que já
existe" em vez de "criar".

**Decisão (28/08/2026):** **(x) trava total + reativar.** O índice único ignora `active`,
a busca da trava em Dart inclui os desativados e a H10 ganha o caminho "reativar o que
já existe".

---

### B4 — Onde mora a marcação "vendido a peso"

**O problema:** "vendido a peso" (o acém moído, o azeite a granel) precisa ficar guardado
em algum nível do cadastro, e há dois candidatos: o **tipo do produto** ("Acém moído") ou
o **cadastro** (tipo + marca + descrição).

**Recomendação — no cadastro.** É onde o wireframe da Tela 4 a desenha, entre Unidade e
Marca, e é o que permite "mussarela em pacote" e "mussarela do balcão" convivendo no mesmo
tipo. Ela vale em qualquer unidade base: o azeite a granel é medido em litro e mesmo assim
é vendido a peso.

**Alternativa descartada:** pendurá-la no tipo do produto — aí o tipo inteiro vira "a peso"
ou "por peça", e os dois casos da mussarela precisariam de dois tipos diferentes, quebrando
a soma por tipo que é a base de todo relatório.

**O que muda no código depois de decidida:** a coluna `selling_mode` fica em
`product_registration` (recomendado) ou em `product_type`, e é ela que decide se a Tela 4
mostra ou esconde a lista de embalagens.

**Decisão (28/08/2026):** **(x) no cadastro do produto.** `selling_mode` é coluna de
`product_registration`, como o wireframe da Tela 4 desenha.

---

### B5 — Em que formato o dinheiro e a quantidade viajam

**O problema:** a decisão 24 diz "`numeric` no banco, decimal no app" para o dinheiro nunca
arredondar sozinho — e a lista congelada de dependências (decisão 3) **não tem pacote
decimal**. Pior: `numeric` no banco **não** impede o erro. O Supabase devolve o número sem
aspas, e o código do app o transforma em número quebrado (`double`) **antes** de qualquer
linha nossa ver o valor. É o desfecho **automático** se nada for decidido, com o banco
inteiro correto — exatamente o risco `R15`.

**Recomendação — guardar em número inteiro na menor unidade:** centavos para dinheiro,
gramas para peso, mililitros para volume. `R$ 19,90` viaja como `1990`. Nada no caminho
arredonda, e a comparação de embalagem já é feita assim (decisão 24: "1 × 0,35 L" e
"1 × 350 ml" são a mesma coisa). A vírgula só aparece na hora de escrever na tela.

**Alternativa:** manter `numeric` no banco e pedir o valor **como texto** em toda consulta
de dinheiro, convertendo em Dart. Guarda a escala no banco ao custo de uma consulta
explícita em todo relatório — e de um esquecimento silencioso no dia em que alguém escrever
a consulta sem isso.

**Trava:** o seed de 4 meses (ele grava valores) e, depois dele, todo relatório.

**Decisão (28/08/2026):** **(x) inteiro na menor unidade.** Dinheiro em centavos, peso em
gramas, volume em mililitros — `bigint` no Postgres e `int` em Dart, do banco à tela. A
vírgula nasce só na formatação. **Consequência no schema:** as colunas de conteúdo da
embalagem deixaram de ser duas (`total_content` numeric + `total_content_smallest_unit`
bigint) e viraram **uma só** `bigint` — guardar também a forma fracionária seria
reintroduzir exatamente o `R15` que esta decisão fecha.

---

### B6 — Como um item SAI da lista de compras `(nasceu na H7, 28/08/2026)`

Não estava em nenhum documento, e a H7 a tornou inevitável:
`list_write_off.shopping_list_item_id` é `not null references shopping_list_item (id)`
**sem `on delete`**. Então *"o item saiu da lista"* **não pode ser um `DELETE`** — a
primeira compra que abatesse um item e depois tentasse removê-lo bateria na chave
estrangeira, e apagar a linha levaria embora o rastro que a H9 desfaz.

**Resposta:** as **duas** saídas da lista viram **data**, e são colunas diferentes porque
são atos diferentes — a H9 precisa distinguir *"a compra fechou este item"* de *"alguém
tirou este item da lista"*:

| Coluna | Quem preenche | Significado |
|---|---|---|
| `fulfilled_on` | a função `create_purchase` | o dia da **compra** que fechou o item |
| `removed_on` | o app, ao remover à mão | o dia em que alguém tirou o item da lista |

Nulo nas duas = ainda na lista. Toda leitura da lista filtra as duas, e o índice parcial
`shopping_list_item_open_idx` documenta essa intenção tanto quanto a serve.

**O saldo NÃO ganhou coluna:** `remainingQuantity = quantity − Σ list_write_off` é
calculado em Dart. É o que faz o desfazer da H9 ser "apagar os write-offs e limpar a
data", sem recalcular número nenhum — duas fontes para o mesmo número divergem no primeiro
erro.

**E o `check` de `list_write_off` foi relaxado para `>= 0`**, nunca menos: um item **sem
quantidade** nunca pediu quantidade nenhuma, então ele recebe uma linha de rastro valendo
**zero** e é fechado por ela. Sem essa linha, `fulfilled_on` seria inalcançável — é dos
write-offs que ele sai. Deixar o item sem quantidade engolir *"tudo o que sobrou"* — a
primeira versão do plano — inflaria o rastro e roubaria dos itens quantificados do mesmo
tipo.

Onde mora: `supabase/migrations/20260828130000_purchase_write.sql` e
`lib/domain/models/write_off_plan.dart`.

---

## C. Perguntas de negócio `(handoff §13)`

As quatro que os requisitos deixaram abertas. **Nenhuma trava o início** — cada uma pode
esperar até a história que a usa. A mais urgente é a L1.

### C1 (L1) — Como o seletor de Produto da Tela 3 ordena e filtra → **H7**

Os requisitos dizem "os produtos de sempre já sugeridos" e "o mais comprado daquele tipo
aparece primeiro", mas não dizem **em que janela** se mede "mais comprado", **como se
desempata**, nem se o seletor **lista todos os produtos ou só os do tipo já em contexto**.

**Por que importa:** é o campo mais tocado do app e o primeiro dos três toques por item —
mexe direto na meta de 2 minutos.

**Resposta (28/08/2026, ao escrever a H7):** **um campo só, com busca por trecho do
nome**, sem diferenciar maiúscula, minúscula nem acento — a mesma normalização da trava de
duplicidade, aplicada dos dois lados e depois `contains`. A busca olha tipo, marca,
descrição **e embalagem**, então `lei` acha todo leite, `italac` acha pela marca e `350`
acha pela prateleira.

- **janela:** os **últimos 3 meses de calendário**, contados do relógio do aparelho
  (`threeMonthsBefore`, no ViewModel — nenhum `now()` no SQL);
- **desempate:** o **mais comprado** primeiro; empate vai para o **comprado mais
  recentemente**; e só então alfabético pelo nome normalizado, com o id fechando a ordem
  para ela não oscilar entre duas leituras;
- **lista:** **todos** os produtos ativos, **agrupados por tipo**, com o tipo mais comprado
  abrindo a lista. Uma ordenação plana colocaria um refrigerante entre dois leites.

**Nada de `★` na tela:** a notação dos wireframes reserva o símbolo para o painel `#3a`
(melhor custo), que é H19. A contagem **ordena e não informa** — ela não vai para a tela.

Onde mora: `compareForPicker` e `groupForPicker`, em
`lib/domain/models/product_option.dart`, com teste por critério.

---

### C2 (L2) — Como o produto sem marca aparece na divisão por marca → **RESPONDIDA na H11**

O requisito 4 promete "abrir o tipo mostra a divisão por marca, com quantidade e valor de
cada uma", e o acém moído não tem marca nenhuma.

**Resposta (30/08/2026):** ( ) linha "Sem marca" (**x**) **fica fora do detalhamento**.

O total do tipo continua contando o que o produto sem marca gastou — a soma das linhas de
marca abertas pode ser **menor** que o total logo acima, e isso é aceito. E é o que faz um
tipo comprado **só** sem marca não oferecer expansão nenhuma (decisão **D-a**): não haveria
uma única linha para mostrar.

Onde mora: `buildReportSections`, em `lib/domain/models/report_section.dart`, com teste por
critério. **A regra é do domínio, não do SQL** — `report_period` devolve o grupo de marca
nula junto com os outros, e é o Dart que o descarta (decisão 7). Reabrir o C2 é uma linha.

A consulta e o schema **não mudam** com essa resposta: `brand_id` continua podendo ser
nulo, e nulo continua sendo um valor (B2).

---

### C3 (L3) — Ordem dentro de cada categoria na lista de compras → **H5**

O requisito 8 declara "agrupada por categoria e, dentro de cada uma, em ordem
alfabética", mas a lista em si (requisito 11) só declara o agrupamento. **Se a intenção é
a ordem do corredor, alfabética pode não ser o que você quer.**

**Resposta:** dentro da categoria ( ) alfabética ( ) ordem de entrada ( ) manual
· entre categorias: ` `

---

### C4 (L4) — Fuso horário → **RESPONDIDA na H13 (30/08/2026)**

O `tecnico §7.4` assume **America/Porto_Velho (UTC−4)** como premissa; os requisitos não
registram cidade. Três regras dependem de "hoje" — mês do teto, aviso de item repetido e
a janela rolante — e o erro é **silencioso** (`R9`).

**Mitigação já em vigor:** o "hoje" nasce no relógio do aparelho, em Dart, e viaja como
parâmetro (decisão 13). Nenhum `now()` no SQL.

**Resposta:** cidade/fuso: **America/Porto_Velho (UTC−4)** — a premissa do `tecnico §7.4`
confirmada.

**E ela não vira código.** A mitigação continua sendo a resposta inteira: o único `now()`
que a H13 acrescentou ao SQL é o **carimbo** de `warned_80_at`/`warned_100_at`, e nada o
lê de volta para comparar com coisa alguma. Qual é o mês do teto, o que é "hoje ou ontem"
e onde começa a janela rolante são decididos em Dart, sobre o relógio do aparelho. A
cidade fica registrada para o dia em que alguém olhar um carimbo e precisar saber em que
hora local ele caiu.

---

## D. Status dos documentos `(handoff §14.5)`

Nada disso trava código. São as três coisas que **nenhum documento registra como
abertas** e por isso passam despercebidas.

- **D1 — Congelar o questionário técnico.** O cabeçalho ainda diz
  `Status: [x] Respondido [ ] Congelado para desenvolvimento`. As 25 decisões estão
  tomadas e o `CLAUDE.md` já as trata como fonte da verdade, mas o documento nunca foi
  marcado como fechado. **Ação:** marcar o checkbox. `[ ] feito`
- **D2 — Wireframes v2.1.** O checklist do v2.0 afirma "nenhuma suposição em aberto", e
  isso era verdade em 26/08. Em 27/08 os requisitos reabriram quatro perguntas e **duas
  são de tela**: C1 (ordem do seletor de Produto, Tela 3) e C3 (ordem dentro da categoria,
  Tela 1). **C1 foi respondida na H7** e está no código (`compareForPicker`/`groupForPicker`,
  hoje em `ui/purchase/widgets/product_field.dart`); resta a C3. **Ação:** responder a C3 e
  publicar a v2.1 — com as **três telas da Entrega 4**, que os wireframes nunca desenharam:
  o histórico paginado, a correção e a manutenção do cadastro. `[ ] feito`
- **D3 — `[x]` O texto da Tela 3 promete mais do que a plataforma entrega.** "Esta compra
  será salva quando o sinal voltar" — o WebKit não tem Background Sync, então isso só
  acontece com **o app aberto** ou **na abertura seguinte** (`R16`).
  **Decidido em 28/08/2026: ajustado agora.** A faixa passou a dizer *"Sem conexão. Esta
  compra está guardada no aparelho e será salva quando você abrir o app com sinal."*, e o
  botão virou `[ Salvar quando eu abrir com sinal ]`. O app **continua reenviando sozinho
  com o app aberto** — o que a frase não promete e o app faz a mais, que é o lado certo do
  erro. `[x] feito`

---

## E. Riscos aceitos — só confirmar que continuam aceitos

- **E1 — `R13`: produção sem backup.** O plano gratuito não faz backup automático e não
  haverá rotina própria na 1ª versão (decisão 15). O histórico de compras é o dado
  insubstituível do projeto. **Sinal de alerta:** qualquer migration rodada no `prod` sem
  ter passado pelo `dev`. `[ ] continua aceito`
- **E2 — decisão 6: sem autenticação, RLS permissiva e chave anônima pública.** Quem tiver
  a URL tem a base. É o que torna o subdomínio de A3 uma decisão de segurança, não de
  estética. `[ ] continua aceito`

---

## O que **não** está em aberto `(handoff §14.6)`

Para não reabrir por engano: as **suposições dos requisitos** (caíram em 26/08/2026), as
**decisões técnicas 1 a 25** (congeladas em 27/08/2026), o **escopo** (os 18 requisitos
são todos essenciais) e o **prazo** (não existe — a ordem de entrega é sequência, não
cronograma).
