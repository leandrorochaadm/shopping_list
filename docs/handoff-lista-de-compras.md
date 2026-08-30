# Handoff técnico — Lista de compras de supermercado

Versão: 1.4 | Data: 27/08/2026

_Gerado em 27/08/2026, a partir de:_
- `requisitos-lista-de-compras.md` — 18 requisitos essenciais, fechado em 26/08/2026
  (com **quatro perguntas reabertas em 27/08** por este handoff — ver §13)
- `tecnico-lista-de-compras.md` — questionário técnico v1.4, respondido em 27/08/2026
- `wireframes-lista-de-compras.md` — rascunho v2.0, de 26/08/2026 (6 telas + 6 diálogos + painel `#3a`)

> **Documento interno, linguagem técnica.** Não é o que o cliente lê — esse é
> `requisitos-lista-de-compras.md`. Onde este documento divergir dos requisitos ou do
> questionário técnico, **são eles que valem** e é este que está errado.
>
> **Ressalva de processo:** cliente e desenvolvedor são a mesma pessoa, não há board e
> não há segundo dev — o próprio questionário técnico (§10.6) diz que o handoff só se
> justifica se isso mudar. Ele foi gerado a pedido, e o que ele acrescenta ao documento
> de requisitos é a **sequência executável**: quebra em histórias, ordem de entrega,
> mapa história → schema e a lista do que ainda não tem resposta (§13).

**O que mudou na 1.4** — a revisão que a 1.3 deixou pedida ("aberto para revisão em
outra sessão"), feita contra as três fontes. Treze achados, **nenhuma decisão nova de
negócio**: **três de erro factual**, **dois de sequência** e **oito de regra que existia
na fonte e não tinha chegado aqui**.

- **A linha `H11` do §8 contradizia o corpo da própria H11.** A tabela dizia "por tipo";
  a fronteira SQL escrita na história devolve **três agregações** — categoria, tipo e,
  dentro do tipo, marca. A correção da 1.1 tinha ficado só no corpo.
- **A `H12` não tem consulta própria.** Se a H11 já devolve o total por categoria, o
  percentual é conta de Dart sobre um número que já chegou. A linha saiu de "a escrever":
  são **7 consultas**, não 8, e **11 linhas** em aberto no §8, não 12.
- **O §7 registrava `ativo` em uma linha só.** A decisão 19 põe `ativo` nos **seis**
  cadastros e a decisão 23 dá `ativo` próprio aos dois níveis de produto — a coluna
  "Observação" contava outra história.
- **O estado "Tela 4 aberta sobre cadastro existente" não tinha dono na ordem.** A H2
  (2ª) já promete o botão `[ Abrir e acrescentar embalagem ]` do cadastro barrado, e o
  handoff mandava esse caminho para a H10 (9ª). Pelo rascunho é uma **porta interna da
  Tela 4**, sem passar pelo `≡`: o estado nasce na **H2**, e a H10 acrescenta só a porta
  do menu. Sem isso, sete histórias com um beco sem saída no cadastro.
- **O `≡` não tinha nota de sequência**, como a barra inferior da Tela 1 já tinha. Ele é
  cabeçalho da Tela 1 (H4) e abre quatro telas que chegam entre a 8ª e a 12ª.
- **Faltava, na H19, a ordenação das linhas e o `−%` em cada linha perdedora** — o
  requisito 17 manda "lista ordenada do mais barato para o mais caro" e a porcentagem
  **ao lado de cada linha**, e o rascunho reforça "sempre, com duas opções ou com dez".
  O documento só registrava o veredito do rodapé.
- **Faltava, na H7, o `[ed]` de cada item já adicionado** — corrigir ou remover item
  **antes** de salvar — e o total da compra visível. Sem ele, o único conserto seria a
  H9, três entregas depois.
- **Faltava, na H2, que o rádio de "comprando agora" nasce na primeira linha** e nunca
  fica vazio.
- **Faltava, na H8, que o rascunho é local e não aparece no celular do outro.** Estava
  no §7 e não na história.
- **Faltava, na H18, o estado "sem conexão"**, que o rascunho da Tela 6 declara e o §11
  cobra em toda tela que depende do servidor.
- **A autoria do mini-cadastro de tipo estava invertida em relação ao rascunho.** Ele
  "nasceu dentro do `#1a` e desde a 2.0 é reusado pelo `[+Novo]↻` do Tipo na Tela 4" —
  quem inverte a autoria é a ordem de construção deste documento, e isso agora está
  escrito em vez de subentendido.
- **A `L4` (fuso) pulava a H17** na lista de consumidores de "hoje": a janela **fechada**
  também precisa saber qual é o mês em curso, e a H17 é a 16ª, antes da H18.
- **A H10 usava o vocabulário de cinco níveis do cliente** ("desativar produto ou
  embalagem") contra o §7 e o §10, que modelam **cadastro de produto** e **produto
  (folha)**. As duas leituras não se encaixavam.

**O que mudou na 1.3** — nasceu o **§14, painel do que está em aberto**, para consolidar
num lugar só o que a revisão de 27/08/2026 levantou: as 4 perguntas de negócio (que já
viviam no §13), as 6 pendências operacionais do `tecnico §13`, as 2 decisões de schema a
fechar antes da 1ª migration, as 12 linhas de SQL ainda não escritas, e **três coisas que
nenhum documento registrava como abertas** — o questionário técnico nunca marcado como
congelado, o checklist dos wireframes v2.0 dizendo "nenhuma suposição em aberto" depois
de os requisitos reabrirem duas perguntas de tela em 27/08, e o texto da Tela 3
prometendo salvamento com o app fechado, que o WebKit não entrega (`R16`). Nenhuma
decisão nova: o §14 é inventário, e o §13 continua sendo só o que depende do cliente.
**Aberto para revisão em outra sessão.**

**O que mudou na 1.2** — revisão do documento contra as três fontes (requisitos v27/08,
wireframes v2.0 e questionário técnico v1.4), sem nenhuma decisão nova de negócio.
Quatorze achados: **dois de erro factual**, **dois de sequência** e **dez de critério ou
decisão** que existia na fonte e não tinha chegado aqui.

- **`E3` chamava de "5 telas atrás do `≡`" um conjunto de quatro.** A primeira abertura
  não mora no menu — ela é estado da Tela 1 (`tecnico §3`). São **4 atrás do `≡`** mais
  a de primeira abertura.
- **`L4` (fuso) apontava para a história errada.** O primeiro consumidor de "hoje" numa
  regra que erra em silêncio é o **mês do teto (H13, 12ª)**, não o aviso de item
  repetido (H14, 13ª).
- **O mini-cadastro de tipo e o diálogo de categoria apareciam em duas histórias sem
  dono.** Eles **nascem na H2** (Tela 4) e a **H4 os reusa** — é a mesma relação que o
  diálogo de item já tinha entre H6 e H18. Sem dono declarado, os dois seriam escritos
  duas vezes.
- **Faltava o critério do produto trocado na H9** — corrigir o produto de um item tira a
  baixa do tipo antigo e dá baixa no tipo novo. Os requisitos listam cinco coisas que a
  correção refaz; o documento cobria quatro.
- **Faltava, na H2, que produto por peça exige ao menos uma embalagem** — sem ela não há
  como converter a compra para a unidade base.
- **Faltavam cinco regras do painel `#3a` na H19**, mais os estados dele: só a linha do
  produto em lançamento abre marcada; linha marcada sem preço não entra na conta; com
  menos de duas linhas com preço o rodapé pede o segundo preço e o `[ Usar… ]` fica
  travado; no produto vendido a peso o preço digitado **já é o da unidade base**; e
  produto fora do cadastro **não se compara aqui** — vira produto pela Tela 4 primeiro.
- **Faltava, na H17, que o tipo nascido no mês em curso também é oferecido**, e que a
  Tela 2 **abre com tudo desmarcado**.
- **Faltava, na H18, que a opção "não encontrei" do diálogo só aparece no item que já
  está na lista.**
- **Faltavam, na H4, duas regras do `#1a`:** a busca vazia mostra os tipos mais comprados
  agrupados por categoria, e o tipo **já presente na lista** aparece travado.
- **§2 dizia "nada além disso" nas dependências** e omitia as de desenvolvimento
  (`flutter_test`, `mocktail`, `flutter_lints`), que o `tecnico §8.2` e `§3.13` fixam.
- **§2 não registrava a decisão de UI** — Material 3, tema claro apenas, sem design
  system (`tecnico §3.10`). O preto e branco dos wireframes vale para o rascunho de
  validação, não para o app.
- **§11 não tinha acessibilidade** (`tecnico §7.5`): alvo de toque de 48 px, contraste do
  Material 3 e rótulo semântico em botão só de ícone.
- **§9 não registrava o atraso de uma sessão do service worker** (`tecnico §6.8`) — um
  deploy corretivo só passa a valer na abertura seguinte do app.
- **A volumetria da folha de produto dizia "1 a 4"**, número que nenhuma fonte fixa: o
  cadastro cria quantas embalagens ele listar.

**O que mudou na 1.1** — revisão do documento contra as três fontes, no mesmo dia em que
a 1.0 foi escrita. Dez achados, quatro deles de sequência, que é o que este documento
existe para acertar:

- **A S1 não tinha como ser executada.** Ela mede a digitação no iPhone, mas quem cria a
  hospedagem é a H0, que vem depois. Passa a antecipar a **pendência 3** (Cloudflare
  Pages) — e fica escrito que rede local mede digitação, mas não vale para `R2` e `R5`.
- **H2 e H3 nasciam antes da porta que as abre.** A Tela 4 é alcançada pelo `[+Novo]` da
  Tela 3 e pelo `≡`; o cadastro de mercado **não tem tela própria**. Até a H7, as duas
  vivem atrás da rota nomeada — serve para desenvolver, não para uso real.
- **H9 e H13 se dependiam em círculo.** Corrigir compra rearma o aviso de teto, mas o
  teto só existe na H13. A H9 entrega o **ponto de extensão dentro da transação**; o
  rearme é implementado na H13.
- **A barra inferior da Tela 1 apontava para telas de três entregas depois.** Destino
  inexistente fica desabilitado e explicado (H4).
- **Faltava uma regra da baixa:** item marcado como pego que não apareceu em compra
  nenhuma **continua na lista** (H7).
- **A fronteira SQL da H11 esquecia marca e categoria** — o relatório precisa das três
  agregações, não só da do tipo.
- **Um número inventado saiu da H18** ("média de 14"), que os requisitos não registram.
- **Contagem corrigida:** são **19** histórias de negócio para 18 requisitos — o
  requisito 3 rendeu duas.
- Referência de seção errada na H0 (§8 → §7) e volumetria da folha de produto ajustada.
- **A Entrega 2 ganhou ressalva honesta:** a lista funciona, mas item só sai à mão até a
  Entrega 3.

---

## 1. Visão geral

Casal que faz mais de 8 idas ao supermercado por mês e hoje não consegue responder
quanto gastou em quê: a lista mora metade no papel, metade na cabeça, e os cupons se
perdem antes de virar registro. A 1ª versão entrega um PWA para dois iPhones, com base
única no Supabase e sem login, que resolve as três dores declaradas — **saber se está
pagando caro** (alerta de alta e comparação entre mercados), **não esquecer item**
(lista comum que os dois editam em tempo real) e **saber para onde foi o dinheiro**
(relatório de gasto e consumo por período, com teto mensal). O critério que manda em
todo o resto é o **lançamento de uma compra de 20 itens em até 2 minutos**: é ele que
decide se o hábito de lançar pega, e é o maior risco do projeto.

A lista é comum e se atualiza com a tela aberta, mas **nunca se mexe debaixo do dedo**:
o que chega do outro celular entra por uma faixa de aviso, e é o toque dela que refaz a
tela (decisão de 26/08/2026). "Tempo real" aqui é isso, e não reordenação automática.

Os 18 requisitos são todos **essenciais** — decisão do cliente, com a consequência
registrada de que a primeira entrega útil demora mais. A sequência abaixo existe para
compensar isso: os dois já usam o sistema para valer a partir da Entrega 2.

---

## 2. Decisões técnicas em vigor

| Item | Decisão | Origem |
|---|---|---|
| Backend | **Supabase** (Postgres gerenciado + PostgREST + Realtime). Sem backend próprio escrito | `tecnico §1.1`, decisão 1 |
| Contrato de API | **O schema SQL é o contrato**, versionado em `supabase/migrations/`. Sem OpenAPI. Nunca editar estrutura pelo painel | `tecnico §1.3` |
| Ambientes | Dois projetos Supabase: **`dev` e `prod`**. Credenciais por `--dart-define` | `tecnico §1.5`, `§1.6`, decisão 9 |
| Autenticação | **Nenhuma.** Sem login, sem sessão, sem perfil. RLS permissiva, chave anônima pública, URL não divulgada | `tecnico §2.1`, decisão 6 |
| Arquitetura | **MVVM oficial do Flutter** (`ui`/`data`/`domain`). Regra de negócio só no `domain`, em Dart puro | `tecnico §3.2`, decisão 8 |
| Gerência de estado | **Riverpod 3, providers escritos à mão, sem anotação e sem codegen** | `tecnico §3.3` |
| Navegação | **GoRouter**, rota nomeada por tela (11 telas). Um único `redirect`: sem etiqueta de "quem está usando", tudo cai na primeira abertura. Diálogos são `showDialog`/`showModalBottomSheet`, não rotas | `tecnico §3.4` |
| Modelagem | **Sem codegen.** `fromJson`/`toJson`/`copyWith` à mão, classes seladas do Dart 3, `Result` selado próprio | `tecnico §3.7`, `§3.11` |
| Persistência local | **Hive (`hive_ce`)**, e só duas coisas: o rascunho do lançamento (com a marca de "pendente de envio") e a etiqueta de quem está usando. Em web grava em IndexedDB | `tecnico §4.2`, decisão 4 |
| Relatórios | **Misto**: o Postgres soma e agrupa por período; o `domain` em Dart aplica toda regra. **Nenhum limiar numérico e nenhum `now()`/`current_date` no SQL** | `tecnico §12.7`, decisão 7 e 13 |
| Números | **`numeric` no Postgres, decimal no Dart.** Nunca `double`. Conteúdo de embalagem comparado em inteiros na menor unidade; arredondar só na formatação | decisão 24, `R15` |
| Datas | Data da compra é **`date` sem fuso**; o "hoje" nasce em Dart, no relógio do aparelho, e viaja como parâmetro | decisão 13, `R8`, `R9` |
| Plataforma | **PWA em Flutter Web, só celular em retrato.** Alvo único: **Safari no iOS** (iPhone 12 e 15, iOS 17+). Sem Android, sem desktop, sem loja | decisões 2, 10, 16 |
| Distribuição | **Cloudflare Pages + GitHub Actions.** Instalar na tela de início é **obrigatório**, não conveniência | decisões 3, 5, 11 |
| Versões mínimas | **Flutter 3.44.0 stable · Dart 3.12.0** | `tecnico §3.8` |
| UI | **Material 3 padrão, tema claro apenas.** Sem design system próprio. O preto e branco dos wireframes é do rascunho de validação, **não** do app | `tecnico §3.10` |
| Dependências | `supabase_flutter` · `flutter_riverpod` 3.x · `go_router` · `hive_ce` + `hive_ce_flutter` · `intl`. Nada além disso em runtime. **Em desenvolvimento:** `flutter_test` + `mocktail` e `flutter_lints` ^6.0.0 com o `analysis_options.yaml` padrão | `tecnico §3`, `§8.2`, `§3.13` |
| Backup | **Não existe, e a perda é aceita por escrito.** A separação `dev`/`prod` é a única barreira real | `tecnico §1.12`, decisão 15, `R13` |

Detalhe completo em `tecnico-lista-de-compras.md`. **Mudança em qualquer linha acima é
alteração de escopo**, e as decisões 1 a 25 estão congeladas lá.

---

## 3. Histórias (1ª versão)

As **19 histórias de negócio** (H1–H19) cobrem os **18 requisitos Essenciais** — o
requisito 3 rendeu duas, porque o rascunho offline tem risco e teste próprios. Não há
"Desejável" nesta lista. `S1` e `H0` não são requisitos: são o spike que decide se a
plataforma se sustenta e a fundação sem a qual nenhuma tela existe.

Estimativas em **dias ideais**, como referência de tamanho relativo — não são prazo:
o projeto não tem prazo (`requisitos §Limites`).

---

### S1 — Spike: digitação e desempenho no iPhone 12 `(origem: tecnico §13 pendência 2, R1 + R10)`

**Como** desenvolvedor, **quero** medir a digitação de três campos no iPhone 12 antes
de construir qualquer tela, **para** descobrir no dia 1, e não no fim do projeto, se o
PWA sustenta a meta de 2 minutos.

**Telas envolvidas:** nenhuma do rascunho — formulário descartável com os três campos
do item (produto, quantidade, valor), teclado numérico incluso.

**Critérios de aceitação:**
- **Dado** o formulário servido ao iPhone 12 por HTTPS e **adicionado à tela de
  início**, **quando** 20 itens forem digitados com cronômetro, **então** o tempo total
  e os defeitos observados ficam registrados (teclado cobrindo campo, foco escapando ao
  trocar de campo, cursor fora de lugar, autocorreção intrometida).
- **Dado** o resultado, **quando** a digitação inviabilizar 6 segundos por item,
  **então** a decisão de PWA é reaberta **antes** da H0 — não depois.

**Regras de negócio envolvidas:** nenhuma. É medição de plataforma.

**Depende de:** nada do produto — mas **de alguma forma de servir a página ao
iPhone**, e isso a H0 ainda não fez. O caminho mais curto é antecipar a **pendência 3**
(criar o projeto no Cloudflare Pages) e publicar um preview. Servir da rede local mede a
digitação, mas **não** vale para os testes de armazenamento (`R5`) nem de modo avião
(`R2`), que exigem HTTPS e o app instalado. **É a primeira coisa a fazer.**

**Estimativa:** 0,5 d | **Prioridade:** bloqueante

---

### H0 — Fundação: ambientes, schema base, deploy e PWA `(origem: tecnico §13 pendências 1, 3, 4, 5, 6)`

**Como** desenvolvedor, **quero** os dois ambientes, o schema inicial e o deploy
automático de pé, **para** que toda história seguinte tenha onde nascer.

**Telas envolvidas:** nenhuma.

**Critérios de aceitação:**
- **Dado** o painel do Supabase, **quando** os projetos `dev` e `prod` forem criados,
  **então** URL e chave anônima de cada um estão anotadas e chegam ao app por
  `--dart-define`, nunca commitadas.
- **Dado** o repositório, **quando** a primeira migration for aplicada, **então** ela
  cria as entidades de §7 com `numeric` em todo dinheiro e quantidade, `date` na data da
  compra, coluna `ativo` nos seis cadastros e chave estrangeira em vez de nome copiado.
- **Dado** o índice de duplicidade, **quando** a migration for aplicada, **então** ele
  usa **coluna gerada normalizada** (`lower`+`trim`+sem acento) com uma função
  `IMMUTABLE` própria envolvendo `unaccent()` — que é `STABLE` e o Postgres recusa
  direto no índice.
- **Dado** um push na branch, **quando** a Action rodar, **então** ela instala o
  Flutter, roda `flutter build web --release --dart-define=...` e publica `build/web`
  pelo `wrangler` — o builder padrão do Cloudflare **não** tem Flutter.
- **Dado** o `web/manifest.json` e o `web/index.html`, **quando** o primeiro deploy
  sair, **então** `name`, `short_name`, `description`, `background_color`,
  `theme_color`, `<title>`, `<meta name="description">` e `apple-mobile-web-app-title`
  estão preenchidos, os quatro PNG de `web/icons/` trocados, e existem
  `<meta name="apple-mobile-web-app-capable" content="yes">`,
  `<meta name="robots" content="noindex">` e `web/robots.txt`.
- **Dado** o subdomínio, **quando** for definido, **então** ele **não** é adivinhável
  (nada de `shopping-list` puro). **A pendência 3 pode já ter sido antecipada pela S1** —
  se foi, o que sobra aqui é o deploy automático, não a criação do projeto.
- **Dado** o `dev`, **quando** o seed for aplicado, **então** ele vem de
  `supabase/seed.sql` versionado e traz **4 meses de compras sintéticas** — sem isso as
  duas janelas de 3 meses não têm o que mostrar e metade dos relatórios só seria
  testável em produção, meses depois.

**Regras de negócio envolvidas:** nenhuma de negócio. Estruturais: decisões 9, 13, 15,
17, 19, 23, 24, 25.

**Estados a implementar:** não se aplica.

**Depende de:** S1.

**Estimativa:** 3 d | **Prioridade:** bloqueante

---

### H1 — App abre direto, base compartilhada e etiqueta de quem está usando `(origem: Requisito Essencial 14)`

**Como** um dos dois, **quero** abrir o app e já ver a lista e o histórico do outro,
sem login nem cadastro, **para** que o sistema não cobre nada de ninguém antes de
servir.

**Telas envolvidas:** **Primeira abertura** (tela não desenhada, `tecnico §3`) · Tela 1
`#1` (cabeçalho `👤`) · Configurações (não desenhada)

**Critérios de aceitação:**
- **Dado** o app recém-instalado, **quando** ela abrir pela primeira vez, **então**
  aparece "Quem está usando? ( ) Leandro ( ) esposa", uma vez só naquele aparelho, e
  depois disso a Tela 1 abre direto.
- **Dado** o aparelho já marcado, **quando** qualquer rota for acessada, **então** o
  `redirect` do GoRouter não dispara mais — a etiqueta é estado local (Hive), não
  identidade.
- **Dado** o app aberto nos dois celulares, **quando** ela abrir o dela, **então** ela
  vê a lista e o histórico que ele lançou, sem digitar nada.
- **Dado** o `👤` da Tela 1 ou a tela de configurações, **quando** a etiqueta for
  trocada, **então** a troca vale a partir da próxima compra lançada naquele aparelho,
  sem senha e sem confirmação.
- **Dado** o histórico, **quando** for aberto, **então** cada compra mostra quem lançou.

**Regras de negócio envolvidas:** `requisitos §Regras` — "quem lançou vem de quem está
marcado no celular, não de login"; "não existe login, senha nem cadastro de usuário".
**Limitação aceita:** dois lançamentos do mesmo aparelho sem trocar a marcação ficam com
o mesmo nome, e aí o aviso de item repetido (H14) não dispara.

**Estados a implementar:** carregando · erro de rede · sucesso. **Sem conexão:** "Sem
conexão — não é possível abrir a lista agora" + `[ Tentar de novo ]`.

**Tratamento de erros:** `requisitos §Quando dá errado` não cobre este requisito; os
estados vêm da Tela 1 do rascunho.

**Depende de:** H0.

**Estimativa:** 1 d | **Prioridade:** Essencial · 1ª na ordem de construção

---

### H2 — Cadastro de produto em cinco níveis, com várias embalagens de uma vez `(origem: Requisito Essencial 1)`

**Como** quem está lançando, **quero** cadastrar o produto na hora, nos níveis que se
aplicam a ele, **para** não travar com o cupom na mão.

**Telas envolvidas:** Tela 4 `#4` (Novo produto) · diálogos de **categoria nova**,
**marca nova** e **mini-cadastro de tipo** (nome, categoria, unidade base), todos
abrindo sem sair da tela.
**Os três diálogos nascem aqui**, e o `#1a` da H4 reusa dois deles (mini-cadastro de
tipo e categoria nova) — mesma relação que o diálogo de item tem entre H6 e H18. Escrever
duas vezes é o erro a evitar; os wireframes já dizem que é a mesma tela nos dois lugares.
**Ressalva de fonte:** o rascunho conta a autoria ao contrário — o mini-cadastro de tipo
"nasceu dentro do `#1a` e desde a 2.0 é reusado pelo `[+Novo]↻` do Tipo na Tela 4". Quem
inverte é a **ordem de construção deste documento**, que põe a H2 antes da H4; a tela é a
mesma nos dois lugares e o rascunho continua valendo para o desenho dela.

**Também nasce aqui o estado "cadastro existente, ganhando embalagem nova"** — a Tela 4
aberta com categoria, tipo, marca e descrição preenchidos e travados, e a lista de
embalagens já carregada. Ele é o destino do `[ Abrir e acrescentar embalagem ]` do
cadastro barrado, que o rascunho declara ser uma **porta interna da Tela 4**, sem passar
pelo `≡`. A H10 acrescenta a segunda porta (a do menu), não o estado — deixá-lo para lá
faria o cadastro barrado ser um beco sem saída da 2ª até a 9ª história. **Quem chegou
pelo lançamento volta para ele:** salvar a embalagem nova devolve à Tela 3 com ela já
selecionada.

**Critérios de aceitação:**
- **Dado** o cadastro em branco, **quando** ele digitar "Limpeza / sabão em pó / Omo /
  lavagem perfeita / 500 g", **então** o produto passa a ser escolhível pronto no
  lançamento, com marca, descrição e embalagem juntas.
- **Dado** "Carnes / acém moído" marcado como **vendido a peso**, **quando** for salvo,
  **então** ele não tem embalagem nenhuma e o lançamento passa a pedir só a quantidade
  medida.
- **Dado** um cadastro só de "Bebidas / refrigerante / Coca-Cola", **quando** ele listar
  quatro embalagens (lata 350 ml, lata 269 ml, garrafa 2 L, 12x350ml), **então** nascem
  **quatro produtos separados**, e a que ele marcou como "comprando agora" volta
  selecionada no lançamento. **O rádio nasce na primeira linha e nunca fica vazio** —
  parar o cadastro para perguntar "qual delas?" custa mais do que errar e trocar no
  seletor.
- **Dado** o cadastro barrado por repetição, **quando** ele tocar em `[ Abrir e
  acrescentar embalagem ]`, **então** a mesma Tela 4 reabre com a identidade preenchida e
  travada, as embalagens existentes carregadas e **a linha que ele estava montando
  descida para essa lista** — nada do que digitou se perde.
- **Dado** um tipo medido em quilo, **quando** ele digitar a medida da peça, **então** a
  lista de unidades oferece **só g e kg**; num tipo medido em litro, **só ml e L** — as
  quatro nunca juntas.
- **Dado** "500 g" digitado, **quando** o produto aparecer em qualquer tela, **então**
  ele continua lendo "500 g", e o relatório de "sabão em pó" conta 0,5 kg. **As duas
  formas são persistidas** — a digitada e a convertida —, e quem converte é o `domain`,
  antes de gravar.
- **Dado** um tipo medido em **unidade**, **quando** a embalagem for cadastrada,
  **então** ela é só a contagem de peças ("12un"), e a medida anotada ao lado é lembrete
  fora de todo cálculo.
- **Dado** "Coca-Cola original" já cadastrada em "refrigerante", **quando** ele
  recomeçar o mesmo cadastro, **então** o salvar é **barrado** e o sistema oferece abrir
  o cadastro existente para acrescentar a embalagem (H10); "Coca-Cola zero" passa.
- **Dado** que marca, tipo ou categoria não existem, **quando** ele tocar no `[+Novo]`
  ao lado, **então** o cadastro nasce ali mesmo e **recusa nome repetido**, comparando
  ignorando maiúsculas, espaço sobrando e acento.
- **Dado** o campo Descrição, **quando** ele digitar, **então** o campo sugere as
  descrições já usadas naquele tipo e naquela marca, e "Original" e "original " contam
  como a mesma.
- **Dado** duas linhas de embalagem com o mesmo **conteúdo total** ("1 × 0,35 L" e
  "1 × 350 ml"), **quando** ele salvar, **então** a segunda é recusada — a comparação
  acontece **depois** da conversão, em inteiros na menor unidade.
- **Dado** um produto **vendido por peça**, **quando** ele salvar sem nenhuma linha de
  embalagem, **então** o salvar é recusado — sem ao menos uma não há como converter a
  compra para a unidade base. **Vendido a peso é o oposto:** a lista de embalagens some
  da tela inteira e o botão volta a ser `[ Salvar produto ]`.
- **Dado** que o tipo ainda não foi escolhido, **quando** ele tentar listar embalagem,
  **então** não há como: sem unidade base o sistema não sabe quais medidas oferecer.

**Regras de negócio envolvidas:** `requisitos §Regras` — cinco níveis; marca é cadastro
e descrição é campo livre que **separa cadastros**; identidade **tipo + marca +
descrição** (descrição em branco conta como valor); "cada embalagem é um produto
próprio"; "duas embalagens são a mesma quando o conteúdo total bate"; "nenhum cadastro
pode nascer duas vezes"; "todo cadastro nasce onde deu falta".

**Estados a implementar:** carregando · vazio (sistema no dia 1) · erro de rede · erro
do servidor · sucesso. **Saída própria obrigatória** (`R11`).

**Tratamento de erros:** `requisitos §Quando dá errado` — produto nunca comprado antes;
produto vendido numa medida que não é a do tipo (o caminho é cadastrar na medida do tipo
ou separar num tipo próprio, nunca misturar grandezas).

**Depende de:** H0. **A Tela 4 nasce antes da porta que a abre** — o `[+Novo]` da
Tela 3 (H7) e o `≡` da manutenção (H10). Até uma das duas existir, ela é alcançável só
pela rota nomeada do GoRouter: serve para desenvolver e testar, não para uso real.
**Quem responde ao usuário é o Dart** — a tela trava o salvar assim
que a descrição sai do foco; o índice único é a rede embaixo, não a mensagem.

**Estimativa:** 4 d | **Prioridade:** Essencial · 2ª na ordem

---

### H3 — Cadastro de mercados, criável dentro do lançamento `(origem: Requisito Essencial 15)`

**Como** quem lança, **quero** escolher o mercado de uma lista e cadastrar o novo sem
sair da tela, **para** que o mesmo mercado nunca vire dois.

**Telas envolvidas:** Tela 3 `#3` (campo Mercado + `[+Novo]`) · diálogo **mercado novo**
(um campo só)

**Critérios de aceitação:**
- **Dado** o lançamento, **quando** ele abrir o campo Mercado, **então** escolhe
  "Carrefour" de uma lista — nunca digita solto.
- **Dado** um mercado onde nunca comprou, **quando** ele tocar em `[+Novo]`, **então**
  cadastra o nome ali mesmo e continua o lançamento de onde parou, sem perder o que
  digitou.
- **Dado** "Carrefour" já cadastrado, **quando** ele tentar cadastrar "carrefour",
  **então** o sistema **recusa** e aponta o que já existe (comparação ignorando
  maiúsculas, espaço sobrando e acento).
- **Dado** que não há nenhum mercado, **quando** a Tela 3 abrir, **então** o campo mostra
  "Nenhum mercado ainda — cadastre o primeiro" e o `[+Novo]` fica em destaque.

**Regras de negócio envolvidas:** `requisitos §Regras` — "o mercado é escolhido de uma
lista, nunca digitado livre"; mercado é qualquer lugar de compra (feira, açougue,
hortifrúti) e todos entram junto no gasto do mês.

**Estados a implementar:** carregando · vazio · erro de rede · erro do servidor ·
sucesso.

**Depende de:** H0. **O cadastro de mercado não tem tela própria:** o diálogo mora
dentro da Tela 3, que só nasce em H7. Na prática, H3 entrega tabela, repositório, diálogo
e trava de duplicidade, e isso só fica alcançável com a Tela 3 de pé — se a Tela 3 for
antecipada por causa de `R1`/`R10`, as duas andam juntas. É pré-requisito de H7 (não há
compra sem mercado).

**Estimativa:** 0,5 d | **Prioridade:** Essencial · 3ª na ordem

---

### H4 — Lista comum: adicionar item, marcar e atualizar sem mexer debaixo do dedo `(origem: Requisito Essencial 2)`

**Como** um dos dois, **quero** uma lista única que os dois editam, **para** não voltar
do mercado sem o que o outro pediu.

**Telas envolvidas:** Tela 1 `#1` · diálogo `#1a` (Adicionar item) · **mini-cadastro de
tipo** e **categoria nova**, os dois **reusados da H2**, não reescritos aqui

**Critérios de aceitação:**
- **Dado** que ela adiciona "leite" pelo celular dela, **quando** ele abrir a lista,
  **então** "leite" está lá; ele marca como pego e ela vê que já foi pego.
- **Dado** a lista aberta na mão dele, **quando** ela adicionar dois itens de casa,
  **então** aparece a faixa `[ 2 itens novos — atualizar ]` no topo, **nada se move
  sozinho**, e os dois itens entram só quando ele toca na faixa.
- **Dado** que a mudança do outro não é só adição (item removido ou marcado), **quando**
  a faixa aparecer, **então** o texto vira "a lista mudou — tocar para ver".
- **Dado** um item qualquer, **quando** ele tocar duas vezes na caixa, **então** ela volta
  ao vazio e **nunca** passa por "não encontrei" — a caixa alterna só vazio ↔ pego.
- **Dado** o `[ + Adicionar item ]`, **quando** ela digitar "lei", **então** a busca
  filtra os tipos já cadastrados e o item entra com dois toques, **só com o tipo**.
- **Dado** o painel recém-aberto, **quando** ela ainda não tiver digitado nada, **então**
  ele já mostra os **tipos mais comprados por eles, agrupados por categoria** — abrir o
  painel dá o que tocar sem digitar.
- **Dado** um tipo **já presente na lista**, **quando** ele aparecer na busca, **então**
  vem travado (`[–]`): item repetido na lista não ajuda ninguém no corredor.
- **Dado** que nada bate com o que ela digitou, **quando** a busca terminar, **então** a
  última linha é `[ + Criar "achocolatado" ]`, que abre o mini-cadastro de tipo (nome,
  categoria, unidade base) ali mesmo — e o item aparece na lista, no grupo da categoria,
  sem ela passar pelo cadastro de produto.
- **Dado** um tipo que já existe, **quando** ela digitar "acem moido" ou "ACHOCOLATADO",
  **então** a busca **encontra o tipo existente** e a linha "Criar '…'" **não aparece**.
- **Dado** um tipo desativado, **quando** ele aparecer na busca, **então** vem marcado
  como desativado, com a opção de **reativar** em vez de criar outro.
- **Dado** que ela pôs só "leite" e ele pôs "leite Italac 1L", **quando** os dois
  estiverem na mesma lista, **então** os dois formatos convivem, e comprar Piracanjuba
  abate os dois.

**Regras de negócio envolvidas:** `requisitos §Regras` — lista única, permanente e comum;
"a baixa acontece no nível do tipo do produto"; "marcar e lançar são dois atos
separados"; "a caixa marca só peguei"; "a lista avisa em vez de se mexer"; trava de
duplicidade de tipo e categoria.

**Estados a implementar:** carregando ("a lista vem de fora do celular, sempre há espera
na abertura") · vazio ("Sua lista está vazia" + adicionar + sugerir) · erro de rede ·
erro do servidor · **sem conexão** (a lista não abre) · sucesso.

**Depende de:** H1, H2 (as tabelas de tipo e categoria e os dois diálogos que o `#1a`
reusa). **Realtime só aqui** — é a única tela do app com websocket (`tecnico §1.11`).

**Nota de sequência:** a **barra inferior fixa** (`Lista · Falta · Relatórios`) e os
botões `[ Sugerir itens ]` e `[ Lançar compra ]` nascem nesta tela, mas apontam para
telas que ainda não existem (H18, H11, H17, H7). Até cada uma chegar, o destino fica
**desabilitado e explicado** — nunca um toque que não faz nada e não diz por quê.
**O menu `≡` segue a mesma régua e nasce aqui**, no cabeçalho da Tela 1: ele é a única
porta das quatro telas não desenhadas, que chegam entre a 8ª e a 12ª história — histórico
e correção de compra (H9), manutenção do cadastro (H10) e configurações (H13). Cada
entrada aparece desabilitada e explicada até a sua história existir; o `≡` sem dono
declarado é o jeito mais fácil de essas quatro telas ficarem sem porta.

**Estimativa:** 3 d | **Prioridade:** Essencial · 4ª na ordem

---

### H5 — Lista agrupada por categoria `(origem: Requisito Essencial 11)`

**Como** quem está no corredor, **quero** a lista agrupada por categoria, **para**
diminuir o zigue-zague.

**Telas envolvidas:** Tela 1 `#1`

**Critérios de aceitação:**
- **Dado** itens de categorias diferentes, **quando** a lista for exibida, **então** ela
  mostra "Carnes: acém moído, frango" e "Limpeza: detergente, sabão" separados, e **não**
  a ordem em que foram adicionados.
- **Dado** que o agrupamento é automático, **quando** a categoria do tipo mudar (H10),
  **então** o item passa a aparecer no grupo novo.

**Regras de negócio envolvidas:** `requisitos §Requisito 11`; "a classificação vale
sempre a atual".

**Estados a implementar:** herda os da Tela 1 (H4).

**Depende de:** H4. **Lacuna aberta:** a ordenação **dentro** de cada grupo e a ordem
entre grupos não estão definidas — ver §13, L3.

**Estimativa:** 0,5 d | **Prioridade:** Essencial · 5ª na ordem

---

### H6 — Diálogo do item: quantidade, preferências, "não encontrei" e remover `(origem: Requisito Essencial 13)`

**Como** quem escreve a lista, **quero** ajustar o item num diálogo, **para** não abrir
teclado por engano no corredor.

**Telas envolvidas:** **diálogo de edição do item** (sobre a Tela 1, reusado pela Tela 6)

**Critérios de aceitação:**
- **Dado** um item da lista, **quando** ele tocar **no texto** (não na caixa), **então**
  abre o diálogo com quantidade, marca e embalagem preferidas (as duas com "qualquer
  uma" como padrão), marcar/desmarcar "não encontrei" e remover o item à mão.
- **Dado** o campo de quantidade, **quando** ele digitar, **então** a unidade ao lado é
  sempre a **unidade base do tipo** — "litros", "quilos" —, mesmo com a embalagem de 1 L
  escolhida: a lista mostra "6 litros", nunca "6 caixas".
- **Dado** "leite — 6 litros" e "detergente" sem quantidade, **quando** os dois estiverem
  na lista, **então** convivem: o com quantidade sai por saldo, o sem quantidade sai na
  primeira compra do tipo.
- **Dado** uma quantidade sugerida de 6 kg, **quando** ele trocar para 3 kg e comprar
  3 kg, **então** o item sai da lista — **a quantidade escrita no item é quem manda na
  baixa**, tenha vindo da sugestão ou não.
- **Dado** a linha do item, **quando** a tela for renderizada, **então** existem **dois
  alvos de toque** e nenhum campo numérico na linha.

**Regras de negócio envolvidas:** `requisitos §Regras` — quantidade sempre na unidade
base; preferência é lembrete e **não manda na baixa**; "não encontrei" mora no diálogo e
cai sozinha na primeira compra do tipo.

**Estados a implementar:** carregando · erro do servidor · sucesso. **Saída própria**
(`R11`).

**Depende de:** H4.

**Estimativa:** 1,5 d | **Prioridade:** Essencial · 6ª na ordem

---

### H7 — Lançar compra em até 2 minutos, com baixa da lista `(origem: Requisito Essencial 3)`

**Como** quem chegou do mercado, **quero** lançar a compra inteira em até 2 minutos,
**para** que o hábito não morra como morreu com os cupons de papel.

**Telas envolvidas:** Tela 3 `#3` (Lançar compra)

**Critérios de aceitação:**
- **Dado** uma compra de 20 itens, **quando** ele cronometrar o lançamento, **então**
  termina em **2 minutos ou menos**, corrigindo só os preços que mudaram — medido **no
  iPhone 12**, que é o piso de desempenho.
- **Dado** o campo Produto preenchido, **quando** a quantidade mudar, **então** o valor
  total é recalculado como **quantidade convertida para a unidade base × preço da unidade
  base da última compra em qualquer mercado**; a partir do momento em que ele digita o
  valor à mão, o recálculo para de mexer nele.
- **Dado** um fardo, **quando** ele escolher "Coca 12x350ml" e digitar 1, ou escolher
  "Coca 350ml" e digitar 12, **então** os dois fecham em **4,2 litros a R$ 11,43 o
  litro**, sem conta na mão.
- **Dado** um produto **vendido a peso**, **quando** o campo de quantidade aparecer,
  **então** o rótulo vem da **unidade base do tipo** — "Peso (kg)", "Volume (L)" ou
  "Quantidade (un)" —, e não há contagem de embalagens.
- **Dado** o item que veio da lista com preferência ("leite Italac 1L"), **quando** o
  tipo for escolhido, **então** o campo Produto já abre naquela embalagem, e trocar não
  deixa nada pendente.
- **Dado** o calendário da data, **quando** ele abrir, **então** **nenhum dia posterior a
  hoje pode ser tocado** — não é aviso que dá para atropelar. Data anterior é aceita.
- **Dado** o "compre 2 leve 3", **quando** ele lançar 3 embalagens e o valor pago pelas
  2, **então** o preço por unidade base sai certo sozinho, sem marcação nenhuma.
- **Dado** a compra salva, **quando** ela contiver um tipo que estava na lista, **então**
  o item sai da lista — respeitando: **compra parcial abate e não zera** (pediu 6 L,
  comprou 2, restam 4); **item sem quantidade sai na primeira compra do tipo**; **compra
  com data anterior não mexe em item que entrou na lista depois**; e a marcação "não
  encontrei" daquele tipo **cai**, mesmo em compra parcial.
- **Dado** um item **marcado como pego** que não apareceu em nenhuma compra lançada,
  **quando** a compra for salva, **então** ele **continua na lista** — a marcação sozinha
  nunca tira item da lista, senão o esquecimento de lançar viraria item perdido.
- **Dado** um item já acrescentado à compra, **quando** ele tocar no `[ed]` da linha,
  **então** o item reabre para correção ou remoção **antes de salvar** — é o único
  conserto que existe durante o lançamento, porque a H9 só chega três entregas depois. O
  **total da compra** fica visível na tela e se refaz a cada item.
- **Dado** o salvamento, **quando** ele acontecer, **então** é **uma única escrita
  transacional**, e a **chave da compra nasce no aparelho** — para o reenvio que chegou
  duas vezes não virar compra duplicada.
- **Dado** a compra salva, **quando** ela mexer na lista, **então** fica gravado o
  **rastro**: qual item abateu, quanto abateu e se derrubou um "não encontrei" (é o que
  H9 desfaz).

**Regras de negócio envolvidas:** `requisitos §Regras` — valor total pago, nunca preço
unitário; preço pré-preenchido vem da última compra em **qualquer** mercado; promoção não
tem marcação; a baixa é pelo tipo; a regra do lançamento atrasado; compra parcial abate.

**Estados a implementar:** carregando (Mercado e Produto em "Carregando...", com o que já
foi digitado visível e editável) · **sistema vazio** (dia 1: sem mercado e sem produto,
com os `[+Novo]` em destaque) · **sem base de comparação** (valor abre vazio) · salvando ·
erro de rede · erro do servidor · sucesso.

**Tratamento de erros:** `requisitos §Quando dá errado` — comprou produto que nunca
comprou (cadastra na hora, H2); pediu marca e só tinha outra (lança o que comprou de
verdade); esqueceu de lançar e lembrou dias depois (escolhe a data real).

**Depende de:** H2, H3, H4, H6. **É a tela que S1 mediu** — construir cedo e cronometrar.

**Estimativa:** 4 d | **Prioridade:** Essencial · 7ª na ordem

---

### H8 — Rascunho do lançamento no aparelho e reenvio quando o sinal voltar `(origem: Requisito Essencial 3, parte offline)`

**Como** quem digitou 18 dos 20 itens, **quero** que nada se perca se a conexão cair,
**para** que perder um lançamento inteiro não mate o hábito.

**Telas envolvidas:** Tela 3 `#3` (estados "Sem conexão", "Rascunho recuperado", "Salvo
com sucesso")

**Critérios de aceitação:**
- **Dado** 18 itens digitados, **quando** a conexão cair e ele fechar o app, **então**
  ao voltar uma hora depois a compra reaparece como estava — data, mercado e itens.
- **Dado** o rascunho recuperado, **quando** a Tela 3 abrir, **então** ela mostra "Compra
  de 18/08 no Carrefour, 18 itens, não salva" com `[ Continuar ]` e `[ Descartar ]`.
- **Dado** que ele tocou em salvar sem sinal, **quando** a faixa aparecer, **então** ela
  diz "Esta compra está guardada no aparelho e será salva quando o sinal voltar" e o botão
  vira `[ Salvar quando voltar o sinal ]` — e o rascunho ganha a marca de **pendente de
  envio**.
- **Dado** o estado pendente, **quando** a conexão voltar **com o app aberto** ou **na
  abertura seguinte**, **então** a compra é enviada sozinha. **Nunca com o app fechado**:
  o WebKit não tem Background Sync (`R16`) — e o texto da faixa não pode prometer mais do
  que isso.
- **Dado** a compra salva, **quando** o servidor confirmar, **então** o rascunho é apagado
  na hora e não sobra nada para salvar duas vezes.
- **Dado** o rascunho no aparelho dele, **quando** ela abrir a Tela 3 no celular dela,
  **então** **não há rascunho nenhum lá** — ele é local, é de quem está com o aparelho e
  não existe como compra até ser salvo. É o que mantém a escrita única do `tecnico §4.5`.
- **Dado** o rascunho recuperado sem sinal, **quando** ele tentar acrescentar item,
  **então** os campos Produto e Mercado ficam em "Carregando..." — sem sinal ele
  **guarda e continua**, mas não **acrescenta**.
- **Dado** o app **fechado e em modo avião**, **quando** ele abrir, **então** o service
  worker serve a tela e o rascunho é alcançável (`R2` — teste manual obrigatório, **no
  app instalado na tela de início**, não em aba do Safari).

**Regras de negócio envolvidas:** `requisitos §Limites` — "única exceção: o lançamento em
andamento". `tecnico §4.4` e decisão 22: **um rascunho por aparelho, nunca uma fila**.

**Estados a implementar:** sem conexão · pendente de envio · rascunho recuperado ·
sucesso · erro do servidor.

**Depende de:** H7.

**Estimativa:** 2 d | **Prioridade:** Essencial · 7ª na ordem (junto com H7)

---

### H9 — Histórico, correção e exclusão de compra, desfazendo o efeito na lista `(origem: Requisito Essencial 12)`

**Como** quem digitou R$ 3,80 em vez de R$ 38, **quero** corrigir ou apagar a compra,
**para** que o erro não vire falta de comida em casa nem relatório errado.

**Telas envolvidas:** **Histórico de compras lançadas** e **Correção/exclusão de compra**
(as duas atrás do `≡`, não desenhadas — `tecnico §3`)

**Critérios de aceitação:**
- **Dado** o histórico, **quando** ele abrir, **então** lista as compras com data,
  mercado, total e **quem lançou** — é a única tela paginada do app.
- **Dado** o acém lançado a R$ 3,80, **quando** ele corrigir para R$ 38, **então** o
  relatório do período e o preço médio já saem certos na sequência.
- **Dado** uma compra com leite que tirou o leite da lista, **quando** ela for apagada,
  **então** o leite **volta à lista**, como se a compra nunca tivesse sido lançada.
- **Dado** uma compra parcial (pediu 6 L, comprou 2), **quando** ela for apagada,
  **então** o item volta ao **saldo de 6 litros**.
- **Dado** o detergente marcado como "não encontrei" e uma compra que derrubou a marcação,
  **quando** essa compra for apagada, **então** o item volta **com a marcação de volta**.
- **Dado** uma compra de 6 L de leite, **quando** ela for corrigida para 2 L, **então** o
  leite volta à lista com **saldo de 4 litros**.
- **Dado** um item que não deveria estar na compra, **quando** ele for removido dela,
  **então** o item volta inteiro para a lista.
- **Dado** o **produto trocado** num item da compra, **quando** a correção for salva,
  **então** a baixa do **tipo antigo** é desfeita e a do **tipo novo** é aplicada — é a
  quinta coisa que os requisitos mandam a correção refazer, junto de quantidade, item
  removido, data e mercado.
- **Dado** a correção da **data**, **quando** ela for salva, **então** a regra do
  lançamento atrasado é refeita item por item — item que entrou na lista depois da data
  nova fica de pé. **Reaplicar não é replay cego.**
- **Dado** a correção do **mercado**, **quando** ela for salva, **então** a comparação
  entre mercados passa a refletir o mercado novo.
- **Dado** qualquer correção ou exclusão, **quando** ela mudar o total do mês, **então**
  os dois cortes do teto são reavaliados na **mesma transação**, limpando a marca do
  corte que o mês deixou de cruzar. **Este critério só passa a valer com H13**, que é
  quem cria as tabelas de teto — até lá não há corte para reavaliar. O que a H9 entrega é
  o **ponto de extensão dentro da transação**, e não uma segunda escrita depois dela.

**Regras de negócio envolvidas:** `requisitos §Regras` — "apagar uma compra desfaz o
efeito dela sobre a lista", e isso é a frase inteira (itens, saldo e "não encontrei");
"corrigir refaz o efeito", valendo para quantidade, item removido, produto trocado, data
e mercado.

**Estados a implementar:** carregando · vazio (nenhuma compra ainda) · erro de rede · erro
do servidor · sucesso. **Confirmação antes de apagar.** **Saída própria** (`R11`) — estas
telas não têm nada desenhado e são as que mais arriscam prender o usuário.

**Depende de:** H7 (o **rastro** gravado lá é o que esta história desfaz — `R14`;
sem ele, não tem como reconstruir depois).

**Estimativa:** 3 d | **Prioridade:** Essencial · 8ª na ordem

---

### H10 — Manutenção do cadastro: renomear, reclassificar, desativar e reativar `(origem: Requisito Essencial 16)`

**Como** dono do vocabulário, **quero** arrumar depois o cadastro que nasceu improvisado
no corredor, **para** que o histórico não fique partido nem errado.

**Telas envolvidas:** **Manutenção do cadastro** (atrás do `≡`, não desenhada) · Tela 4
`#4`, **reusada da H2** — esta história acrescenta a **porta do `≡`**, não o estado, que
já nasceu lá pela porta interna do cadastro barrado

**Vocabulário:** os requisitos falam nos cinco níveis do cliente ("desativar produto",
"desativar embalagem"); o schema tem **dois** níveis (`tecnico` decisão 23, §7 e §10
deste documento). A tradução é: **cadastro de produto** = tipo + marca + descrição, e
**produto (folha)** = cadastro + embalagem. "Desativar o produto" desativa o cadastro e,
com ele, todas as folhas; "desativar a embalagem" desativa **uma folha**. São os dois
`ativo` da decisão 23, e é por isso que os cadastros são seis e não cinco.

**Critérios de aceitação:**
- **Dado** "acem moido" cadastrado, **quando** ele renomear para "acém moído", **então**
  o nome certo aparece em **todas as telas e em todo o histórico** — a compra referencia
  o cadastro por chave e **nunca copia o nome**.
- **Dado** "Carrefur" e o histórico dele, **quando** for renomeado para "Carrefour",
  **então** a comparação entre mercados passa a mostrar **um mercado só**, com o
  histórico dos dois juntos.
- **Dado** uma marca renomeada ("OMO" → "Omo"), **quando** salvar, **então** vale de uma
  vez para todos os produtos dela e todo o histórico.
- **Dado** "acém moído" mudado de categoria, **quando** salvar, **então** os relatórios de
  **meses anteriores** passam a contar esse gasto na categoria nova.
- **Dado** um produto medido em litro, **quando** ele tentar movê-lo para um tipo medido
  em quilo, **então** o tipo **nem aparece** na lista de destino, e o sistema explica que
  a medida não bate, apontando para a correção da unidade base do tipo.
- **Dado** um produto com compra lançada, **quando** ele tentar apagar, **então** o
  sistema **impede** e oferece **desativar** — vale igual para tipo, categoria e
  embalagem.
- **Dado** um produto desativado, **quando** ele abrir sugestões e lançamento, **então**
  ele sumiu dos dois, mas **continua nos relatórios** do período em que foi comprado.
- **Dado** o filtro "mostrar desativados", **quando** ele reativar categoria, tipo, marca,
  produto, embalagem ou mercado, **então** volta a aparecer nas sugestões e no lançamento.
- **Dado** "achocolatado" presente em 1 item da lista, **quando** ele desativar o tipo,
  **então** o sistema avisa antes — "achocolatado está em 1 item da lista — ele será
  removido" — com opção de cancelar; confirmando, o item sai, e **reativar depois não
  devolve o item**.
- **Dado** uma marca, produto ou embalagem que é **preferência** de um item da lista,
  **quando** for desativada, **então** **nada é avisado**: a preferência cai em silêncio e
  o item continua na lista só com o tipo.
- **Dado** o Omo de 500 g já cadastrado, **quando** ele acrescentar a embalagem de 2,3 kg
  **pela manutenção**, **então** abre a mesma Tela 4 da H2, com categoria, tipo, marca e
  descrição preenchidos, e ele só acrescenta a linha. A outra porta para esse estado — o
  cadastro **barrado por repetição** — já existe desde a H2 e **não passa por aqui**.
- **Dado** uma embalagem digitada errada ("350 ml" como "35 ml"), **quando** for
  corrigida, **então** a correção vale para todo o histórico dela.

**Regras de negócio envolvidas:** `requisitos §Regras` — "a classificação vale sempre a
atual"; "a reclassificação para em cima da unidade base"; "produto, categoria ou tipo com
compra lançada não pode ser apagado, só renomeado ou desativado"; a assimetria proposital
entre desativar tipo (avisa e remove) e desativar preferência (silêncio).

**Estados a implementar:** carregando · vazio · erro de rede · erro do servidor · sucesso.
**Confirmação antes de desativar tipo em uso.** **Saída própria** (`R11`).

**Depende de:** H2, H3, H7 (só faz sentido com histórico existindo).

**Estimativa:** 3 d | **Prioridade:** Essencial · 9ª na ordem

---

### H11 — Relatório de gasto e consumo por período livre `(origem: Requisito Essencial 4)`

**Como** quem quer saber para onde foi o dinheiro, **quero** escolher o período e ver o
gasto e o consumo por categoria, por tipo e por marca, **para** responder a pergunta que
hoje fica sem resposta.

**Telas envolvidas:** Tela 5 `#5`, **aba Resumo**

**Critérios de aceitação:**
- **Dado** o período de 01/03 a 31/03, em que comprou 5 kg de acém a R$ 30 o quilo e 1 kg
  a R$ 42, **quando** o relatório for aberto, **então** ele responde **6 kg de acém moído,
  preço médio R$ 32 o quilo, total R$ 192** — e mostra também o total da categoria
  "Carnes" e o total geral do período.
- **Dado** o mesmo período, **quando** ele olhar "sabão em pó", **então** lê "6,8 kg —
  R$ 136" somando Omo e Tixan, todas as descrições e todas as embalagens.
- **Dado** o tipo aberto, **quando** ele expandir, **então** vê a divisão por marca **com
  quantidade e valor de cada uma** — "Omo 4,3 kg — R$ 86 / Tixan 2,5 kg — R$ 50".
- **Dado** qualquer período, **quando** o preço médio for calculado, **então** ele é
  **total gasto ÷ quantidade total**, nunca média de médias (R$ 32 o quilo, não R$ 36).
- **Dado** o intervalo escolhido, **quando** ele for livre (quinze dias, dois meses),
  **então** funciona igual — o único que muda é o teto, que **só aparece no relatório do
  mês** (H13).

**Regras de negócio envolvidas:** `requisitos §Regras` — "o tipo do produto é o nível que
soma"; preço médio como total ÷ quantidade; tudo contado na unidade base.

**Fronteira SQL × Dart (`R7`, decisão 7):** o Postgres devolve, no intervalo recebido
**por parâmetro**, o **total consumido** e o **total gasto** agrupados por **categoria**,
por **tipo de produto** e, dentro do tipo, por **marca** — três agregações do mesmo
período, nada além de soma e agrupamento. Nenhum limiar, nenhuma janela e nenhum
`current_date` no SQL.

**Estados a implementar:** carregando · **vazio** (período sem compra) · erro de rede ·
erro do servidor · sucesso.

**Depende de:** H7. **A aba "Comparação de preço" só chega na H16** — até lá a Tela 5
abre **com uma aba só**, e não com uma aba vazia esperando.

**Estimativa:** 2,5 d | **Prioridade:** Essencial · 10ª na ordem

---

### H12 — Peso de cada categoria no total do período `(origem: Requisito Essencial 7)`

**Como** quem quer ver onde o dinheiro se concentra, **quero** o percentual de cada
categoria no período, **para** enxergar desperdício.

**Telas envolvidas:** Tela 5 `#5`, **aba Resumo**

**Critérios de aceitação:**
- **Dado** o relatório do mês, **quando** ele abrir, **então** lê "Carnes = 40% do gasto
  do mês".
- **Dado** o mesmo relatório, **quando** o período for livre, **então** o percentual é
  sobre o total **daquele período**, não do mês.

**Regras de negócio envolvidas:** é a terceira leitura de "desperdício"
(`requisitos §Problema e objetivos`): categoria pesando demais no total.

**Fronteira SQL × Dart (`R7`):** **nenhuma consulta nova.** A agregação por categoria já
vem da consulta da H11, no mesmo intervalo; aqui o `domain` só divide pelo total do
período. Uma segunda consulta seria a mesma soma escrita em dois lugares, e é assim que
relatório passa a divergir de si mesmo.

**Estados a implementar:** herda os de H11.

**Depende de:** H11.

**Estimativa:** 0,5 d | **Prioridade:** Essencial · 11ª na ordem

---

### H13 — Teto de gasto do mês, com os dois avisos e o rearme `(origem: Requisito Essencial 9)`

**Como** casal, **queremos** ser avisados antes de estourar o teto do mês, **para** que o
aviso sirva para alguma coisa.

**Telas envolvidas:** **Configurações** (atrás do `≡`, não desenhada) · Tela 3 `#3` (aviso
ao salvar) · Tela 5 `#5` ("gastou X de Y")

**Critérios de aceitação:**
- **Dado** teto de R$ 1.500, **quando** a compra levar o mês a R$ 1.200 (80%), **então**
  o aviso aparece **na hora do lançamento** e o relatório do mês mostra "gastou R$ 1.200
  de R$ 1.500".
- **Dado** o mesmo teto, **quando** a compra passar de R$ 1.500, **então** o aviso de
  estouro aparece — e as compras seguintes do mesmo mês **não repetem** nenhum dos dois.
- **Dado** que ainda **não há teto configurado**, **quando** o relatório do mês abrir,
  **então** **não existe** linha "gastou X de Y" e nenhum lançamento dispara aviso.
- **Dado** R$ 1.300 já gastos em agosto, **quando** ele configurar R$ 1.500 no dia 20,
  **então** o relatório de agosto passa **na hora** a mostrar "gastou R$ 1.300 de
  R$ 1.500", **a própria tela do teto avisa** que o mês está em 87%, esse aviso **conta
  como o dos 80%** e não se repete — e o de 100% continua guardado. **Julho continua sem
  linha de teto para sempre.**
- **Dado** um teto salvo já acima de **100%**, **quando** a tela reavaliar, **então**
  grava os **dois** avisos — um teto nascido em 120% não pode soltar o "estourou" no
  lançamento seguinte, sobre um estouro que já era passado.
- **Dado** R$ 1.300 gastos, o aviso dos 80% já dado sobre R$ 1.500, **quando** ele subir o
  teto para R$ 1.800, **então** **nada dispara na hora** e a compra que leva o mês a
  R$ 1.440 **traz de volta** o aviso dos 80% — alterar o teto **zera os dois avisos do mês
  corrente e reavalia na hora**.
- **Dado** setembro fechado com R$ 1.600 sobre teto de R$ 1.500, **quando** em outubro o
  teto subir para R$ 1.800, **então** o relatório de setembro continua mostrando "gastou
  R$ 1.600 de R$ 1.500".
- **Dado** uma correção ou exclusão de compra (H9) que derrube o mês para baixo de um
  corte, **quando** a transação fechar, **então** aquele aviso **volta a ficar
  disponível** e dispara de novo quando o corte for cruzado outra vez.
- **Dado** um período livre (quinze dias, dois meses), **quando** o relatório abrir,
  **então** o teto **não** é mostrado.
- **Dado** o teto e o aviso do teto na mesma compra que o aviso de item repetido (H14),
  **quando** a compra for salva, **então** os dois aparecem **empilhados na mesma tela de
  confirmação**, teto em cima, com um único botão `[ Entendi ]`.

**Regras de negócio envolvidas:** `requisitos §Regras` — teto mensal do casal, aviso aos
80% e aos 100%, um por mês; "antes de ser configurado, o teto não existe"; "três coisas
fazem o mês cruzar um corte: o lançamento, a correção e a configuração do teto".

**Modelagem (decisão 14, `tecnico §5`):** duas tabelas — `teto`, uma linha por
**alteração** (`vigente_desde`, sempre dia 1), e `aviso_teto`, uma linha por **mês** com
`aviso_80_em` e `aviso_100_em`. Salvar teto novo **apaga a linha de avisos do mês
corrente e reavalia na mesma transação**; meses fechados não são tocados. **Os limiares
de 80% e 100% ficam no `domain`, em Dart** — nada disso no SQL (`R7`).

**Estados a implementar:** carregando · vazio (sem teto) · erro de rede · erro do servidor
· sucesso. **Saída própria** (`R11`).

**Depende de:** H7, H9, H11. **O rearme pela correção de compra é implementado aqui**,
dentro da transação que a H9 já escreveu — a dependência é de mão única, não circular.

**Estimativa:** 2 d | **Prioridade:** Essencial · 12ª na ordem

---

### H14 — Aviso de item já comprado pelo outro no mesmo dia `(origem: Requisito Essencial 10)`

**Como** um dos dois, **quero** saber que o outro comprou o mesmo tipo de produto no
mesmo dia, **para** decidir se foi repetição ou se era proposital.

**Telas envolvidas:** Tela 3 `#3` (aviso ao salvar)

**Critérios de aceitação:**
- **Dado** que ele lançou "leite" à tarde e ela compra de manhã e lança à noite,
  **quando** ela salvar, **então** ela vê "⚠ Vocês dois compraram leite hoje" — quem avisa
  é **o segundo lançamento a chegar**, seja qual for a ordem em que as compras
  aconteceram.
- **Dado** uma compra de **ontem**, **quando** o aviso aparecer, **então** o texto é
  "Vocês dois compraram leite **no dia 25/08**" — nunca "hoje".
- **Dado** uma compra de **05/08 lançada hoje** com leite que ela também comprou naquele
  dia, **quando** ele salvar, **então** **nenhum aviso aparece** — só dispara em compra de
  **hoje ou de ontem**.
- **Dado** leite Italac dele e leite Piracanjuba dela, **quando** o aviso for avaliado,
  **então** ele dispara: a comparação é no **nível do tipo do produto**.
- **Dado** qualquer um dos casos, **quando** o aviso aparecer, **então** a compra é
  registrada normalmente — ele **não bloqueia nem apaga nada**, e o texto é **neutro**,
  sem apontar quem comprou primeiro.

**Regras de negócio envolvidas:** `requisitos §Regras` — aviso retroativo, no nível do
tipo, informativo; "quem lançou vem de quem está marcado no celular".

**Cuidado com data (`R9`):** o "hoje ou ontem" nasce em **Dart, no relógio do aparelho**.
Um `current_date` no SQL às 21h do dia 30 em UTC−4 devolve **dia 31** e erra o aviso em
silêncio.

**Estados a implementar:** herda os de H7 (o aviso é um estado do salvar).

**Depende de:** H1 (etiqueta de quem lançou), H7.

**Estimativa:** 1 d | **Prioridade:** Essencial · 13ª na ordem

---

### H15 — Alerta de alta de preço no lançamento `(origem: Requisito Essencial 5)`

**Como** quem está lançando, **quero** ser avisado quando o preço subiu de verdade,
**para** perceber onde estou pagando caro.

**Telas envolvidas:** Tela 3 `#3` (linha "⚠ Subiu 18% sobre a média")

**Critérios de aceitação:**
- **Dado** média de R$ 32 o quilo no acém nos últimos 3 meses, **quando** ele lançar a
  R$ 38 (+18,8%), **então** o sistema sinaliza; a R$ 34 (+6,3%), **não sinaliza nada** —
  o corte é **10% ou mais**.
- **Dado** quantidade e valor ainda vazios, **quando** o item estiver sendo preenchido,
  **então** **não há alerta**: ele só aparece depois dos dois, que é de onde sai o preço
  da unidade base.
- **Dado** um produto **sem marca**, **quando** o alerta for avaliado, **então** a
  comparação **sobe para o tipo do produto** — é a **falta da marca** que manda, não o
  fato de ser vendido a peso (a mussarela Tirolez é comparada contra ela mesma).
- **Dado** um produto **sem nenhuma compra** na janela, **quando** ele for lançado,
  **então** o sistema **fica quieto** — sem base, nenhum alerta.
- **Dado** que ele trocou de marca (Omo → Tixan, mais barato), ou de embalagem (500 g →
  2,3 kg), ou da lata avulsa para o fardo, **quando** lançar, **então** o sistema **não**
  anuncia queda: são produtos diferentes, cada um com o seu histórico.
- **Dado** a janela usada aqui, **quando** for calculada, **então** é a **rolante** — os
  três meses que terminam hoje, **com o mês em curso dentro**.

**Regras de negócio envolvidas:** `requisitos §Regras` — limiar de 10%; comparação produto
com produto, sempre no preço da unidade base; janela **rolante**; produto sem marca sobe
para o tipo.

**Fronteira SQL × Dart (`R7`):** o SQL devolve preços e datas; **o limiar de 10% e o
recorte da janela vivem no `domain`**, testados.

**Estados a implementar:** herda os de H7, mais o estado "sem base de comparação".

**Depende de:** H7.

**Estimativa:** 1,5 d | **Prioridade:** Essencial · 14ª na ordem

---

### H16 — Comparação de preço entre mercados `(origem: Requisito Essencial 6)`

**Como** quem quer pagar menos, **quero** ver onde cada produto sai mais barato, **para**
escolher o mercado com informação.

**Telas envolvidas:** Tela 5 `#5`, **aba Comparação de preço** (visões "por produto" e
"tipo inteiro")

**Critérios de aceitação:**
- **Dado** "acém moído", **quando** ele abrir a comparação, **então** vê o **preço mais
  recente de cada mercado** onde comprou nos **últimos 3 meses** (janela **rolante**), do
  mais barato para o mais caro.
- **Dado** um mercado onde ele só comprou há 8 meses, **quando** a lista for montada,
  **então** ele **não aparece**.
- **Dado** cada linha, **quando** o preço for exibido, **então** vem acompanhado da
  **data da compra que o originou**, no formato `dd/MM` — a data informa, **não ordena**.
- **Dado** "sabão em pó", **quando** ele abrir, **então** vê os mercados **separados por
  produto** — o Omo 500 g de cada mercado de um lado, o Tixan 1 kg de outro —, e não uma
  mistura que faria o mercado do Tixan parecer o mais barato.
- **Dado** a mesma tela, **quando** ele alternar para **tipo inteiro**, **então** a visão
  ignora marca e embalagem e responde só "onde o sabão em pó sai mais barato o quilo" — é
  ela que põe o pacote de 500 g de um mercado ao lado do de 2,3 kg de outro, e o fardo ao
  lado da lata avulsa, todos como preço por unidade base.
- **Dado** um produto sem marca, **quando** a comparação for feita, **então** ela sobe
  para o tipo, pelo mesmo motivo de H15.

**Regras de negócio envolvidas:** `requisitos §Regras` — preço mais recente por mercado,
nunca a média; janela **rolante** de 3 meses; comparação produto com produto, com a visão
do tipo inteiro ao lado; toda comparação pelo preço da unidade base.

**Estados a implementar:** carregando · **vazio** (produto sem compra na janela, ou um
mercado só) · erro de rede · erro do servidor · sucesso.

**Depende de:** H7, H11.

**Estimativa:** 2 d | **Prioridade:** Essencial · 15ª na ordem

---

### H17 — Sugerir itens a partir do consumo dos últimos meses `(origem: Requisito Essencial 8)`

**Como** quem vai montar a lista, **quero** que o sistema ofereça o que costumamos
comprar, com a quantidade, **para** não depender da memória.

**Telas envolvidas:** Tela 2 `#2` (Sugestão de itens)

**Critérios de aceitação:**
- **Dado** 5, 7 e 6 kg de acém nos três meses fechados anteriores, **quando** ele pedir a
  sugestão, **então** o sistema oferece "acém moído — 6 kg"; aceito, o item entra na lista
  **com a quantidade preenchida**, ajustável.
- **Dado** o café, comprado **antes** da janela e com uma única compra de 2 kg nela,
  **quando** a média for calculada, **então** ela divide por **3** e sugere ~0,7 kg — os
  dois meses sem compra contam zero.
- **Dado** o achocolatado, **primeira compra em junho** (2 kg, nada depois), **quando** a
  média for calculada, **então** ela divide por **2** e sugere 1 kg — o divisor é
  proporcional à **vida do produto** dentro da janela, no máximo 3.
- **Dado** o iogurte, **primeira compra neste mês** (3 L), **quando** a média for
  calculada, **então** ela é o **total comprado no mês em curso**, sem divisão nenhuma —
  é a única exceção.
- **Dado** a janela usada aqui, **quando** for calculada, **então** é a **fechada** — os
  três meses fechados anteriores, **sem** o mês em curso.
- **Dado** a lista de sugestões, **quando** for exibida, **então** vem **agrupada por
  categoria** e, dentro de cada uma, em **ordem alfabética** — nunca "do mais comprado
  para o menos comprado".
- **Dado** um tipo comprado ao menos **uma vez** na janela, **quando** a lista for montada,
  **então** ele aparece: **nada é filtrado por ser compra rara**.
- **Dado** um tipo cuja **primeira compra foi no mês em curso**, **quando** a lista for
  montada, **então** ele **também é oferecido** — não tem compra na janela fechada, e é
  justamente quem mais precisa aparecer.
- **Dado** a tela recém-aberta, **quando** ela for exibida, **então** vem **com tudo
  desmarcado**: nada é pré-selecionado, senão `[ Adicionar selecionados ]` despejaria a
  sugestão inteira na lista com um toque — o oposto de "quem decide o que é rotina é ele".
- **Dado** um tipo **já presente na lista** (inclusive o marcado como "não encontrei"),
  **quando** ele aparecer na sugestão, **então** vem como "já está na lista" e **não pode
  ser adicionado de novo**.
- **Dado** um tipo desativado, **quando** a sugestão for montada, **então** ele fica de
  fora (H10).

**Regras de negócio envolvidas:** `requisitos §Regras` — média mensal = total da janela
fechada ÷ meses fechados de vida do produto (máx. 3); "produto sem nenhum mês fechado não
divide nada"; a sugestão preenche o campo e **não manda na baixa** depois disso.

**Fronteira SQL × Dart (`R7`, escrita e a respeitar):** o SQL devolve, por tipo, o **total
consumido no intervalo recebido por parâmetro** e a **data da primeira compra** daquele
tipo. Com esses dois números, **o Dart** calcula quantos meses fechados de vida o produto
tem na janela e faz a divisão. Um `CASE` no SQL decidindo "divide por 2 ou por 3" é a
regra migrando para o lado sem teste.

**Estados a implementar:** carregando · **vazio** (base nova, sem histórico) · erro de rede
· erro do servidor · sucesso. **Saída própria** (`R11`).

**Depende de:** H4, H6, H7. **Só mostra valor depois de alguns meses de compras lançadas**
— no `dev`, é o seed de 4 meses (H0) que torna isso testável.

**Estimativa:** 2 d | **Prioridade:** Essencial · 16ª na ordem

---

### H18 — Falta comprar este mês `(origem: Requisito Essencial 18)`

**Como** quem quer planejar o mês, **quero** ver quanto ainda falta comprar de cada tipo
contra o que costumamos consumir, **para** não descobrir a falta no corredor.

**Telas envolvidas:** Tela 6 `#6` (Falta comprar este mês) · **diálogo de edição do item**
(reusado, já preenchido)

**Critérios de aceitação:**
- **Dado** 5, 7 e 6 kg de acém nos três meses fechados e 4 kg comprados este mês,
  **quando** a tela abrir, **então** mostra "acém moído — faltam 2 quilos"; lançando mais
  2 kg, o acém **sai da tela**.
- **Dado** o café, comprado uma única vez na janela, **quando** a tela abrir, **então**
  ele aparece com o saldo da média baixa dele — **não é escondido por ser compra rara**.
- **Dado** o refrigerante, que já passou da média do mês, **quando** a tela abrir,
  **então** ele **não aparece**; tocando em "ver todos", reaparece como "12 de 10 L".
- **Dado** um produto cuja **primeira compra foi neste mês**, **quando** a tela abrir,
  **então** ele **nunca aparece como faltando** — fica na faixa de baixo, com o consumido
  sobre a média.
- **Dado** um tipo qualquer, **quando** ele tocar, **então** abre o **mesmo diálogo do
  item da lista**, já com a quantidade que falta preenchida — e ele confirma, corrige ou
  cancela. **A tela informa; não marca item, não dá baixa e não tira nada de lugar
  nenhum.**
- **Dado** um tipo que **ainda não está na lista**, **quando** o diálogo abrir, **então**
  a opção "não encontrei" **não aparece** — marcar como não encontrado o que ninguém
  pediu não quer dizer nada. Num tipo que **já está** na lista, o diálogo abre **editando
  o item existente**, nunca criando um segundo.
- **Dado** um item **já na lista sem quantidade** e a tela mostrando "faltam 2 kg",
  **quando** ele tocar, **então** o diálogo abre com os 2 kg preenchidos **e a linha**
  "este item está na lista sem quantidade — confirmar passa a pedir 2 kg"; confirmar troca
  a regra de baixa daquele item. **A tela não muda a regra em silêncio.**
- **Dado** a virada do mês, **quando** ela acontecer, **então** o comprado volta a zero e
  cada "falta" volta a ser a média inteira, sozinho.
- **Dado** o leite, com **6 litros pedidos na lista** e **8 litros faltando** pela média
  do mês, **quando** as duas telas forem lidas, **então** elas não se confundem: a lista diz "6 litros" (o que ele pediu) e
  esta diz "faltam 8 litros" (o que costumam consumir), com a lista logo abaixo do número.

**Regras de negócio envolvidas:** **é a mesma média de H17** — janela fechada, divisor
proporcional. `requisitos §Regras` — "informa e nada mais"; esconde quem já atingiu a
média, com "ver todos" que não bloqueia ninguém.

**Estados a implementar:** carregando ("Somando o que vocês já compraram este mês...") ·
**nada faltando** ("Vocês já compraram tudo que costumam comprar em agosto", com o
`[ Ver todos ]` de pé) · **vazio** (base nova, sem histórico para tirar média) · erro de
rede · erro do servidor · **sem conexão** (a tela não abre) · sucesso.

**Depende de:** H17 (**a conta é a mesma; não escrever duas vezes** — é o motivo declarado
de as duas serem vizinhas na ordem de construção), H6.

**Estimativa:** 1,5 d | **Prioridade:** Essencial · 17ª na ordem

---

### H19 — Calculadora de custo proporcional `(origem: Requisito Essencial 17)`

**Como** quem está lançando, **quero** comparar na hora qual opção rende mais por real,
**para** aprender qual tamanho compensa.

**Telas envolvidas:** painel `#3a` (Comparar custo, ancorado embaixo sobre a Tela 3)

**Critérios de aceitação:**
- **Dado** um tipo com **duas opções ou mais**, **quando** a Tela 3 exibir o campo
  Produto, **então** o botão `[ Comparar custo ]` aparece logo abaixo; com **uma só
  opção**, ele **some da tela**. "Opção" é **qualquer produto ativo do tipo**, embalado ou
  vendido a peso.
- **Dado** "Omo 500 g" a R$ 10,00 e "Omo 2,3 kg" a R$ 33,00, **quando** as duas linhas
  tiverem preço, **então** o painel responde R$ 20,00 o quilo contra **R$ 14,35** o quilo
  e diz que o 2,3 kg sai **28% mais barato o quilo**.
- **Dado** três opções de refrigerante — lata 350 ml a R$ 4,00, garrafa 2 L a R$ 10,00 e
  fardo 12x350ml a R$ 42,00 —, **quando** o painel calcular, **então** a garrafa de 2 L é
  o **melhor custo**, **56%** mais barata que a lata e **50%** mais barata que o fardo.
- **Dado** cada linha, **quando** ela abrir, **então** vem com **o valor pago por _uma_
  embalagem na última compra** — o total do item **dividido pela quantidade** —, em
  qualquer mercado; embalagem nunca comprada abre **vazia**.
- **Dado** um tipo com 20 embalagens cadastradas, **quando** o painel abrir, **então**
  mostra só as **compradas nos últimos 3 meses** (janela **rolante**), com "ver todas do
  tipo" para o resto — **e se esse recorte deixar menos de duas linhas, abre inteiro**.
- **Dado** o painel recém-aberto, **quando** as linhas forem exibidas, **então** **só a
  do produto que estava sendo lançado abre marcada** — quem monta a comparação, de duas
  linhas para cima, é ele. Linha não marcada **não concorre ao melhor custo e não mostra
  custo por unidade base nem diferença**, mesmo com o preço preenchido.
- **Dado** as linhas com preço, **quando** o painel montar a resposta, **então** ela é
  uma **lista ordenada do menor para o maior custo por unidade base**, com o melhor custo
  marcado — e **cada linha perdedora mostra, ao lado, quanto o melhor custo sai mais
  barato que ela**, em porcentagem. **Sempre**, com duas opções ou com dez: é uma fórmula
  só, e não há exceção por contagem de linhas. O rodapé repete a maior diferença em frase.
- **Dado** menos de duas linhas marcadas **com preço**, **quando** o painel calcular,
  **então** nenhum melhor custo é eleito, o rodapé pede o preço da segunda opção e o
  botão `[ Usar… ]` fica **travado**. Linha marcada sem preço fica esperando e não entra
  na conta; **duas linhas com preço já bastam** para haver resposta.
- **Dado** um produto **vendido a peso** na comparação, **quando** ele digitar o preço,
  **então** esse valor **já é o da unidade base** — o quilo da mussarela do balcão, o
  litro do azeite a granel —, porque não há conteúdo a dividir.
- **Dado** um produto **desativado**, **quando** o painel montar a lista, **então** ele
  fica de fora.
- **Dado** um produto que **não existe no cadastro**, **quando** ele quiser compará-lo,
  **então** **não há caminho por aqui**: ele vira produto pela Tela 4 primeiro. A
  calculadora não cria cadastro por porta lateral.
- **Dado** que ele corrige um preço, **quando** digitar, **então** o resultado **se refaz
  na hora**, sem botão de calcular e sem tela de resultado; com **sete opções** e a lista
  rolando, **a resposta continua visível** no rodapé.
- **Dado** duas opções separadas por **menos de 1%**, **quando** o painel calcular,
  **então** ele responde "custo praticamente igual" e **não coroa vencedor** — e ele ainda
  consegue usar uma delas sem fechar o painel.
- **Dado** o vencedor, **quando** ele tocar em usar essa opção, **então** volta ao
  lançamento **com o produto já trocado**, o cursor na quantidade, e o preço sugerido e o
  aviso de alta **refeitos contra o histórico da opção nova**.
- **Dado** o painel aberto, **quando** ele fechar sem escolher nada, **então** o item
  continua exatamente como estava, com o cursor onde estava.
- **Dado** R$ 9,50 digitado ali para corrigir pela etiqueta, **quando** ele lançar o
  produto depois, **então** o histórico registra **só o valor do lançamento** — o que ele
  digitou no painel **não deixa rastro nenhum**.
- **Dado** a porcentagem, **quando** for calculada, **então** ela sai dos **valores
  cheios** (R$ 14,3478), não dos arredondados na tela.

**Regras de negócio envolvidas:** `requisitos §Regras` — "é uma conta de tela, não um
registro"; fórmula única `(preço da linha − melhor preço) ÷ preço da linha`, nos dois na
unidade base; empate abaixo de 1%; a calculadora informa e **não decide a compra**.

**Risco declarado (do próprio requisito):** ela é usada em casa, no lançamento, e não na
prateleira — o app não funciona sem internet dentro do mercado. Na 1ª versão serve para
**aprender para a próxima ida**.

**Estados a implementar:** carregando ("Buscando os preços que vocês pagaram...", com o
cabeçalho já visível e o rodapé vazio) · **menos de duas linhas com preço** · **empate
técnico** (abaixo de 1%) · **sem compra nenhuma do tipo na janela** (abre com todas as
embalagens e o rodapé pede os preços da etiqueta) · erro do servidor · sucesso. **Saída
própria pelo `[ X ]`** (`R11`), sem animação. **Tipo com uma opção só:** o painel não
abre — o botão nem aparece na Tela 3.

**Depende de:** H2 (embalagens cadastradas), H7 (histórico de preço). **É a última de
propósito:** antes de haver histórico, ela abriria com todos os campos vazios e daria mais
trabalho do que resposta.

**Estimativa:** 2,5 d | **Prioridade:** Essencial · 18ª na ordem

---

## 4. Ordem de entrega

A sequência é a **ordem de construção declarada nos requisitos** —
`14 → 1, 15 → 2, 11, 13 → 3 → 12, 16 → 4, 7 → 9, 10 → 5, 6, 8 → 18 → 17` —, quebrada em
entregas que deixam algo utilizável na mão dos dois. **Os dois já usam o sistema para
valer a partir da Entrega 2**, que é o que faz o hábito de lançar pegar.

| Entrega | Histórias | O que eles conseguem fazer ao final | Dias ideais |
|---|---|---|---|
| **0 — Chão** | S1, H0 | Nada visível. Sai daqui a resposta de se o PWA se sustenta, e os dois ambientes + deploy automático de pé | 3,5 |
| **1 — Vocabulário** | H1, H2, H3 | Abrir o app nos dois celulares na mesma base, cadastrar produtos em cinco níveis e os mercados | 5,5 |
| **2 — Lista no corredor** | H4, H5, H6 | **Usar de verdade:** lista comum agrupada por categoria, os dois editando, marcando e vendo o do outro. **Ressalva:** item ainda sai só à mão — a baixa automática chega na Entrega 3 | 5 |
| **3 — Lançar** | H7, H8 | Lançar a compra em 2 minutos, com baixa da lista e rascunho a prova de queda de sinal | 6 |
| **4 — Consertar** | H9, H10 | Corrigir e apagar compra (desfazendo o efeito na lista) e arrumar o cadastro improvisado | 6 |
| **5 — Para onde foi o dinheiro** | H11, H12 | Relatório de gasto e consumo por período, com o peso de cada categoria | 3 |
| **6 — Controle do mês** | H13, H14 | Teto com os dois avisos e o aviso de item repetido | 3 |
| **7 — Estou pagando caro?** | H15, H16 | Alerta de alta no lançamento e comparação entre mercados | 3,5 |
| **8 — Planejar** | H17, H18 | Sugestão da lista pelo consumo e "falta comprar este mês" | 3,5 |
| **9 — Conveniência** | H19 | Calculadora de custo proporcional | 2,5 |
| | | **Total** | **~41,5 d** |

**Três coisas não seguem a ordem e precisam ser feitas cedo:**

- **S1 antes de tudo.** Se a digitação no iPhone 12 não servir, a decisão de PWA cai no
  primeiro dia, não no fim.
- **A pendência 3 (Cloudflare Pages) sobe para dentro da S1**, porque sem hospedagem
  HTTPS não há como pôr o formulário no iPhone e adicioná-lo à tela de início.
- **O rastro do que a compra mexeu na lista nasce na H7**, não na H9. Acrescentá-lo a
  compras já lançadas não tem como ser reconstruído (`R14`).

As Entregas 7 e 8 **só mostram algo de valor depois de alguns meses de compras lançadas**
— isso é da natureza delas, não do sistema. No `dev`, quem torna isso testável é o seed de
4 meses da H0.

---

## 5. Backlog (Desejável / Futuro)

Sem detalhamento — refinados se e quando forem priorizados.

- Uso pelo computador, em tela grande, para os relatórios `(origem: Desejável 1)`.
  **Hoje está fora do alvo por decisão técnica também** (decisão 16): sem layout de tela
  larga, sem teste e sem critério de aceite.
- Leitura automática do cupom fiscal, por código ou foto `(origem: Futuro 1)`
- Aviso do teto chegando no celular com o app fechado `(origem: Futuro 2)`.
  **Ressalva de plataforma:** o WebKit não executa nada com o PWA fechado (`R16`) — isso
  não é só desenvolver a notificação, é reabrir a decisão de plataforma.

---

## 6. Fora de escopo

Não construir, mesmo que pareça fácil:

- **Relatório de compra por impulso** — descartado pelo cliente, para não acrescentar
  trabalho no lançamento
- **Lembrete cobrando o lançamento da compra**
- **Funcionar sem internet dentro do mercado** — o app exige sinal; sem ele, a lista não
  abre. A **única** exceção é o rascunho do lançamento (H8)
- **Marcação de promoção e desconto** — registra-se só o valor pago
- **Separar feira e açougue do supermercado nos relatórios** — cada um é um mercado
  cadastrado, mas não há relatório que separe "gasto de feira" de "gasto de supermercado"
- **Ordem de corredor configurada por mercado** — o agrupamento por categoria basta
- **Login, senha, conta, convite e perfil de acesso** (`tecnico §2`)
- **App nativo, loja, Android e desktop** (decisões 2, 10, 16)
- **Analytics, crash reporting e log remoto** na 1ª versão (decisão 12)
- **Backup da base de produção** — a perda é aceita por escrito (decisão 15, `R13`)
- **Teste de integração ponta a ponta** (`tecnico §8.2`)

---

## 7. Dados e volumetria

| Entidade | Origem | Volume estimado | Observação |
|---|---|---|---|
| Categoria | Cadastrada pelos dois, onde dá falta | Dezenas | `ativo`, nome único normalizado |
| Tipo de produto | Idem, no `#1a` e na Tela 4 | Poucas centenas | **É o nível que soma.** Carrega a **unidade base**; `ativo`, nome único normalizado |
| Marca | Cadastrada dentro do cadastro de produto | Poucas centenas | Opcional no produto; `ativo`, nome único normalizado |
| Cadastro de produto | Tela 4 | Centenas | `tipo + marca + descrição`, **único**; descrição em branco conta como valor. `ativo` próprio — desativá-lo desativa todas as folhas |
| Produto (folha) | Uma linha por embalagem do cadastro | Uma ou mais por cadastro — quantas ele listar (o refrigerante do exemplo cria 4) | **É quem a compra aponta**; preço e histórico próprios. `ativo` próprio (decisão 23) — é ele que "desativar a embalagem" atinge. **Vendido a peso não tem folha de embalagem** |
| Mercado | Diálogo dentro da Tela 3 | Dezenas | `ativo`, nome único normalizado |
| Item da lista | Os dois, o tempo todo | Dezenas simultâneas | Guarda tipo, preferências, quantidade, **data de entrada**, pego e "não encontrei" |
| Compra | Lançamento | **> 8 por mês** | Data (`date`), mercado, **quem lançou**, chave gerada no aparelho |
| Item de compra | Lançamento | **até 20 por compra** → ~170/mês, **~2 mil/ano** | Produto, quantidade, quantidade convertida, valor total pago |
| Rastro da baixa | Gravado junto da compra | 1 por item que abateu | Qual item abateu, quanto, e se derrubou um "não encontrei" |
| Teto | Configurações | 1 linha por **alteração** | `vigente_desde` sempre dia 1 |
| Aviso de teto | Escrita automática | 1 linha por **mês** | `aviso_80_em`, `aviso_100_em` |
| Rascunho do lançamento | Hive, local | 1 por aparelho, dezenas de KB | **Nunca sincroniza**; descartável entre versões |
| Etiqueta de quem está usando | Hive, local | 1 por aparelho | Não é conta nem identidade |

**Ritmo:** mais de 8 idas ao mercado por mês, feitas pelos dois, com até 20 itens cada —
muitas compras pequenas e frequentes, e não uma compra grande mensal. **É isso que torna
os 2 minutos inegociáveis:** o que é tolerável uma vez por mês é insuportável oito.

**Consequência de volume:** paginação só no **histórico de compras**; lista, produtos e
mercados carregam inteiros (`tecnico §1.9`).

---

## 8. Schema e consultas por história

Não há API REST documentada: **o schema versionado em `supabase/migrations/` é o
contrato** (`tecnico §1.3`), e o PostgREST o expõe em runtime. A tabela abaixo é o mapa
história → estrutura, e o "status" diz se a estrutura já está decidida ou ainda precisa
ser fechada na migration.

| História | Tabelas / consultas | Status |
|---|---|---|
| H0 | Todas as tabelas de §7, `supabase/seed.sql` | [ ] a escrever na 1ª migration |
| H1 | `compra.lancado_por`; etiqueta no **Hive** (não vai ao banco) | [x] decidido |
| H2 | `categoria`, `tipo_produto`, `marca`, `cadastro_produto`, `produto`; índice único sobre **coluna gerada normalizada** | [x] decidido · [ ] função `IMMUTABLE` a criar |
| H3 | `mercado` + índice único normalizado | [x] decidido |
| H4 | `item_lista` (+ `entrou_em`); canal **Realtime** na tabela | [x] decidido |
| H5 | Leitura de `item_lista` × `tipo_produto` × `categoria` | [x] decidido |
| H6 | `item_lista` (quantidade, marca/produto preferidos, `nao_encontrei`) | [x] decidido |
| H7 | `compra`, `compra_item`, **rastro da baixa**; escrita **transacional única**, chave gerada no aparelho | [x] escrita — `create_purchase`, que desde a H13 recebe `p_cap_alerts` |
| H8 | Nenhuma tabela nova — Hive local + o mesmo `INSERT` de H7 | [x] decidido |
| H9 | `compra`, `compra_item`, rastro, `item_lista` (e `aviso_teto` **a partir de H13**); desfazer + reaplicar na **mesma transação** | [x] escrita — `update_purchase` e `delete_purchase`, e desde a H13 as duas recebem `p_cap_alerts` e chamam `apply_cap_alerts` **dentro** da transação |
| H10 | `ativo` nos seis cadastros; `UPDATE` de nome e de classificação | [x] decidido |
| H11 | Consulta por período, **três agregações do mesmo intervalo** (por parâmetro): total consumido e total gasto **por categoria**, **por tipo** e, dentro do tipo, **por marca** | [x] escrita — `report_period(p_from date, p_to date)`, em `supabase/migrations/20260830120000_period_report.sql` |
| H12 | **Nenhuma consulta nova** — o percentual sai em Dart, sobre o total por categoria que a consulta de H11 já devolve | [x] decidido |
| H13 | `teto`, `aviso_teto` | [x] escrita — `cap_states(p_months jsonb)` lê teto vigente, gasto e marcas de um ou mais meses; `save_spending_cap(p_amount, p_effective_from, p_alerts)` grava o teto e o rearme numa transação; `apply_cap_alerts(p_alerts)` é a única escrita de marca e é chamada de **dentro** das quatro funções de escrita. Em `supabase/migrations/20260830130000_spending_cap.sql` |
| H14 | Consulta de compras do mesmo dia por `lancado_por` diferente | [x] escrita — `same_day_types(p_date date, p_registered_by text, p_type_ids uuid[])`, na mesma migration da H13. Função e não *embed* do PostgREST: o filtro cai em `product_registration.product_type_id`, três níveis abaixo na cadeia |
| H15 | Preços por produto no intervalo (parâmetro), sem limiar no SQL | [ ] a escrever |
| H16 | Preço **mais recente por mercado** no intervalo, com a data | [ ] a escrever |
| H17 | **Por tipo: total consumido no intervalo + data da primeira compra** — o divisor é do Dart | [ ] a escrever |
| H18 | Mesma consulta de H17 + consumido no mês corrente | [ ] a escrever |
| H19 | Último valor pago por embalagem = total do item ÷ quantidade | [ ] a escrever |

**Regras que valem para toda consulta:**

- **Nenhum `now()` nem `current_date`.** O "hoje" nasce em Dart e viaja como parâmetro
  `date` (decisão 13, `R9`).
- **Nenhum limiar numérico** (10%, 80%, 100%, 1%, 3 meses) e **nenhuma conversão de
  grandeza** dentro do SQL (decisão 7, `R7`).
- **`numeric` em todo dinheiro e toda quantidade**; nunca `float8` (decisão 24, `R15`).
- **Erro do PostgREST nunca chega à UI**: vira `Failure` selado na camada `data`
  (`tecnico §1.8`).

**Dois pontos de schema a fixar na H0** (decisão técnica, não pergunta ao cliente):

1. **Como o produto vendido a peso vira folha.** A compra aponta sempre para `produto`,
   mas a decisão 23 diz que o vendido a peso **não tem folha de embalagem**. O caminho
   mais simples é a folha existir com as colunas de embalagem nulas, para a compra ter
   sempre um alvo único — decidir **antes** da primeira migration, porque muda toda
   consulta de preço.
2. **Como a marca ausente entra no índice único** de `cadastro_produto`: sentinela ou
   `NULLS NOT DISTINCT`. `NULL` não é igual a `NULL` no Postgres, e sem isso dois
   "Coca-Cola sem descrição" passam pela trava (`tecnico §3`).

---

## 9. Restrições

- **Sem prazo de entrega** — projeto pessoal. A ordem de entrega é sequência, não
  cronograma.
- **Sem orçamento de infraestrutura**: tudo em plano gratuito (Supabase, Cloudflare
  Pages, GitHub Actions). Nenhuma conta de loja será criada — economiza US$ 25 + US$ 99/ano
  e a política de privacidade obrigatória.
- **Só celular, em retrato, e só Safari no iOS** (iPhone 12 e iPhone 15, iOS 17+). Sem
  Android, sem tablet, sem desktop. Paisagem **não é evitável** e fica torta, sem teste.
- **Sem integração com terceiros** na 1ª versão.
- **Sem obrigação legal aplicável:** não há dado pessoal sensível, não há loja, não há
  público — sem política de privacidade e sem consentimento no app (`tecnico §9`).
- **Um desenvolvedor só**, que também é o cliente e quem homologa. Sem QA, sem PR formal,
  sem board.
- **Instalar na tela de início é obrigatório** — é o que tira o app da contagem de 7 dias
  do Safari e lhe dá armazenamento próprio (decisão 11, `R5`). **Testar sempre no app
  instalado**, nunca em aba: os dois têm armazenamento separado.
- **Todo deploy demora uma sessão para chegar ao aparelho** (`tecnico §6.8`): o service
  worker do Flutter baixa a versão nova em segundo plano e ela **só passa a valer na
  abertura seguinte**. Ou seja, uma correção publicada agora não é a que ela está usando
  agora — vale lembrar disso antes de concluir que o defeito continua de pé.

---

## 10. Glossário do domínio

Estes são os termos do cliente. **Código, nome de classe, nome de tabela e conversa do
time usam estas palavras** — é a linguagem ubíqua do projeto.

- **Hierarquia**: os cinco níveis — categoria → tipo do produto → marca → descrição →
  embalagem
- **Categoria**: o grupo maior ("Limpeza", "Carnes"). Única pelo nome normalizado
- **Tipo do produto**: a divisão dentro da categoria ("sabão em pó") e **o nível que
  soma**. Carrega a **unidade base**. Único pelo nome normalizado
- **Marca**: o fabricante (Omo, Tirolez). Cadastro próprio, escolhida de lista, opcional
- **Descrição**: texto livre ("lavagem perfeita"). Não soma e não aparece em relatório,
  mas **separa um cadastro do outro**
- **Medida da peça**: quanto tem **uma peça**, digitada com a unidade ao lado (g/kg ou
  ml/L, conforme a unidade base). Guardada nas **duas formas**: a digitada e a convertida
- **Embalagem**: o quinto nível — **quantas peças × quanto tem cada peça** (`500g`, `2L`,
  `12x350ml`, `12un`). É o que o comércio chama de SKU
- **Conteúdo total**: quanto a embalagem tem na unidade base (12x350ml = 4,2 L).
  **Calculado, nunca digitado**
- **Cadastro de produto**: `tipo + marca + descrição`. É o que **não pode se repetir**
- **Produto**: a folha — cadastro **+ embalagem**. É o que a compra aponta, com preço e
  histórico próprios
- **Custo proporcional** (= **preço por unidade base**): preço ÷ conteúdo total
- **Melhor custo**: a opção com o menor custo proporcional — não a mais barata no total
- **Preferência da lista**: marca e embalagem que quem escreveu gostaria de levar.
  Opcionais, **não mandam na baixa**
- **Lançar a compra**: registrar produto, quantidade e **valor total pago** em cada item
- **Unidade base**: a medida em que o tipo é sempre contado (quilo, litro, unidade)
- **Mercado**: qualquer lugar de compra — supermercado, feira, açougue, hortifrúti
- **Vendido a peso / por peça**: como o produto é comprado, **marcado no cadastro**. É o
  que decide se o lançamento pede a quantidade do cupom ou a contagem de embalagens
- **Não encontrei**: marcação do item que estava na lista e não tinha no mercado. Mora no
  **diálogo**, cai sozinha na primeira compra do tipo, e **volta** se a compra for apagada
- **Teto de gasto**: o valor máximo que eles pretendem gastar no mês
- **Quem está usando**: a etiqueta local do aparelho ("Leandro" / "esposa"). **Não é conta
  nem login**
- **Janela de referência**: os 3 meses que o sistema olha para trás. **São duas, e nunca
  se misturam** — **rolante** (três meses terminando hoje, com o mês em curso) para
  alerta de alta, comparação entre mercados e a lista curta da calculadora; **fechada**
  (três meses fechados anteriores) para média mensal, sugestão e "falta comprar no mês"
- **Média mensal**: consumo do tipo na **janela fechada** ÷ **meses fechados de vida** do
  produto ali dentro (máx. 3). Produto nascido no mês em curso: a média é a própria compra
  do mês
- **Falta comprar no mês**: média mensal − comprado no mês corrente. **Informa e nada
  mais.** Não confundir com o **saldo do item da lista** ("restam 2 de 6 kg"), que esse
  sim tira o item
- **Gasto**: quanto dinheiro saiu · **Consumo**: quanta quantidade entrou, na unidade base

---

## 11. Definição de pronto

Vale para toda história. Acordado uma vez, aplicado sempre.

- [ ] Todos os critérios de aceitação passam — eles são os **"Pronto quando"** do
      documento de requisitos, um a um
- [ ] Os estados de tela estão implementados: **carregando · vazio · erro de rede · erro
      do servidor · sucesso**, mais **sem conexão** onde a tela depende do servidor
- [ ] **A tela e cada diálogo têm saída própria desenhada** — em tela cheia no iOS não
      existe botão Voltar do navegador nem gesto de recarregar (`R11`)
- [ ] **Teste de unidade no `domain`, obrigatório e sem exceção**, para toda regra que
      erra em silêncio: limiar de 10%, as **duas** janelas de 3 meses, divisor
      proporcional, conversão para unidade base, identidade do produto, comparações que
      ignoram maiúsculas/espaço/acento, **baixa da lista inteira**, preço médio como
      total ÷ quantidade, porcentagem da calculadora sobre valor cheio e empate de 1%,
      "hoje ou ontem" do aviso de repetido, e o **rearme do teto nos dois sentidos**
- [ ] Widget test da tela e dos diálogos que ela abre, com `flutter_test` + `mocktail`
- [ ] **Acessibilidade básica** (`tecnico §7.5`): alvo de toque de **48 px**, contraste do
      Material 3 e rótulo semântico em todo botão só de ícone. Sem meta de conformidade
      formal
- [ ] **Nenhum limiar, nenhuma conversão de grandeza e nenhum `now()`/`current_date` no
      SQL** (`R7`, `R9`)
- [ ] **Nenhum `double` em dinheiro ou quantidade** (`R15`)
- [ ] Migration versionada em `supabase/migrations/` — nunca estrutura editada pelo painel
- [ ] Rodado **no iPhone 12, com o app instalado na tela de início** (não em aba do
      Safari — o armazenamento é outro)
- [ ] Deploy de preview publicado e apontando para o Supabase `dev`

---

## 12. Riscos e pontos de atenção

Os riscos técnicos estão detalhados em `tecnico §11` (`R1`…`R16`) e não se repetem aqui.
Abaixo, os que mais mexem com **a ordem e o conteúdo das histórias** — mais três de
escopo, que são julgamento deste documento.

| # | Risco | Impacto | Sinal de alerta |
|---|---|---|---|
| `R10` | **Digitação do Flutter Web no Safari do iPhone** — teclado cobrindo campo, foco escapando, cursor fora de lugar. É o **risco principal**: o requisito 3 é exatamente 20 campos em 2 minutos | Alto, e **não se resolve cortando campo** | S1 mede antes de qualquer tela. Se a digitação for ruim, a decisão de PWA cai no dia 1 |
| `R1` | Desempenho do Flutter Web no iPhone 12 (piso) | Médio | Cronometrar a Tela 3 assim que ela existir, não no fim |
| `R14` | **Corrigir compra não é editar registro: é refazer o efeito sobre a lista** | Alto | Se a H7 for para produção sem o **rastro**, a H9 vira impossível de acertar — o rastro não se reconstrói |
| `R2` | Sem sinal, o PWA pode nem abrir, e aí o rascunho fica inalcançável | Alto | Teste em **modo avião, app fechado**, antes de dar H8 por pronta |
| `R9` | "Hoje" calculado no servidor (UTC) erra o dia às 21h em UTC−4 | Alto e silencioso | Qualquer `current_date` que apareça numa consulta de H14, H15, H16, H17 ou H18 |
| `R15` | `double` em dinheiro e quantidade: `12 × 0,35 = 4,199999...` | Médio, e não aparece em teste feliz | Embalagem duplicada passando pela trava de H2; centavo do relatório que não fecha |
| `R5` | Safari apaga armazenamento após 7 dias sem uso | Médio | Perder a etiqueta de quem está usando depois de férias. Instalar na tela de início é o que reduz |
| `R13` | **Sem backup de produção**, e o histórico é o dado insubstituível | Alto se acontecer, **aceito por escrito** | Qualquer migration rodada no `prod` sem ter passado pelo `dev` |
| E1 | **Os 18 requisitos são todos essenciais e não há prazo.** As comparações de preço (H15, H16) — uma das três dores originais — só chegam na Entrega 7 | Médio | Se o projeto parar no meio, para antes de entregar a dor "estou pagando caro?". A mitigação é a ordem de entrega: da Entrega 2 em diante sempre há algo utilizável na mão |
| E2 | **H17 e H18 leem o mesmo número** (média mensal por tipo, janela fechada, divisor proporcional) | Médio | Duas implementações da mesma conta divergindo. Escrever **uma vez** no `domain`, e é o motivo de as duas serem vizinhas na ordem |
| E3 | **Cinco telas do app não têm wireframe** — as **quatro atrás do `≡`** (histórico, correção de compra, manutenção do cadastro, configurações) mais a de **primeira abertura**, que não fica no menu: é estado da Tela 1 (`tecnico §3`) | Médio | Elas carregam H1, H9, H10 e H13 — três das quais mexem em dado já gravado. São as que mais arriscam prender o usuário sem saída (`R11`) e as que chegam sem nenhuma decisão de layout tomada |

---

## 13. Lacunas devolvidas ao cliente

Percebidas ao escrever as histórias. **Não foram preenchidas por conta própria** — já
estão registradas em "Pontos em aberto" do documento de requisitos (27/08/2026). Nenhuma
delas trava o início: cada uma pode ser respondida até a história que a usa.

| # | Lacuna | Bloqueia qual história | Status |
|---|---|---|---|
| L1 | **Como o seletor de Produto da Tela 3 ordena e filtra.** Os requisitos dizem "os produtos de sempre já sugeridos" e "o mais comprado daquele tipo aparece primeiro", mas não dizem **em que janela** se mede "mais comprado", como se desempata, nem se o seletor lista todos os produtos ou só os do tipo já em contexto. É o campo mais tocado do app e o primeiro dos três toques por item — mexe direto na meta de 2 minutos | H7 (parcial) | Aberta |
| L2 | **Como o produto sem marca aparece na divisão por marca** do relatório. O requisito 4 promete "abrir o tipo mostra a divisão por marca, com quantidade e valor de cada uma", e o acém moído não tem marca nenhuma. Rótulo "sem marca"? Linha própria? Fica fora? | H11 (detalhe) | **Respondida em 30/08/2026: fica fora do detalhamento** |
| L3 | **Ordenação dentro de cada categoria na lista de compras**, e a ordem entre as categorias. O requisito 8 declara "agrupada por categoria e, dentro de cada uma, em ordem alfabética — a mesma organização da lista de compras", mas a lista em si (requisito 11) só declara o agrupamento. Se a intenção é a ordem do corredor, alfabética pode não ser o que ele quer | H5 (detalhe) | Aberta |
| L4 | **Fuso horário.** `tecnico §7.4` assume **America/Porto_Velho (UTC−4)** como premissa do documento técnico; os requisitos não registram cidade. Três regras dependem de "hoje" (mês do teto, aviso de item repetido, janela rolante), e o erro é silencioso (`R9`) | Nenhuma trava o início — o "hoje" nasce no relógio do aparelho (decisão 13). **Confirmar até H13**, o primeiro consumidor na ordem entre as regras que erram em silêncio (mês do teto, 12ª); H14, H15, H16, **H17**, H18 e H19 vêm depois — a janela **fechada** da H17 também precisa saber qual é o mês em curso | **Respondida em 30/08/2026: America/Porto_Velho (UTC−4)** — e não vira código: o único `now()` da H13 é o carimbo de `warned_80_at`/`warned_100_at`, que ninguém lê de volta |

**Nenhuma outra pergunta de negócio aberta.** O documento de requisitos fechou as sete
últimas em 26/08/2026 e o questionário técnico fechou as decisões 1 a 25 em 27/08/2026.
O resto do que está em aberto — operacional, técnico e de documento — está consolidado
em §14.

---

## 14. Painel do que está em aberto

Levantado na revisão de 27/08/2026, contra os três documentos-fonte. **Este é o lugar
para olhar antes de começar**: §13 tem só as perguntas de negócio, e elas são a menor
parte. Nada aqui é decisão nova — é inventário.

### 14.1 Perguntas de negócio (4) — as únicas que dependem de decisão do cliente

`L1`…`L4` do §13. Nenhuma trava o início; cada uma pode ser respondida até a história que
a usa. A mais urgente é `L1`, que mexe no campo mais tocado do app e portanto na meta de
2 minutos.

### 14.2 Pendências operacionais (6) — `tecnico §13`, todas com status "Aberta"

Todas do mesmo responsável, todas antes da 1ª linha de código ou do 1º deploy:

| # | Pendência | Quando |
|---|---|---|
| 1 | Criar os projetos Supabase `dev` e `prod`; anotar URL e chave anônima | Antes da 1ª linha de código |
| 2 | **Teste de digitação no iPhone 12** (`S1`) — três campos e cronômetro, medindo `R1` e `R10` juntos | Antes da 1ª tela de verdade |
| 3 | Criar o projeto no Cloudflare Pages e definir o subdomínio **não adivinhável** | Antes do 1º deploy (a `S1` já a antecipa) |
| 4 | Preencher `web/manifest.json` e os campos de template do `index.html`; **trocar os 4 PNG** de `web/icons/` | Antes do 1º deploy |
| 5 | Acrescentar `<meta name="apple-mobile-web-app-capable" content="yes">` | Antes do 1º deploy |
| 6 | Criar `web/robots.txt` e acrescentar `<meta name="robots" content="noindex">` | Antes do 1º deploy |

**A pendência 2 é a que pode derrubar tudo:** se a digitação do Flutter Web no Safari não
servir, a decisão de PWA cai no dia 1 (`R10`, o risco principal).

### 14.3 Decisões técnicas ainda não tomadas (2) — §8

Não são pergunta ao cliente, mas **precisam ser fechadas antes da 1ª migration**, porque
mudam o schema inteiro e não se corrigem depois:

- **Como o produto vendido a peso vira folha.** A compra aponta sempre para `produto`,
  mas o a-peso não tem embalagem (decisão 23). Muda toda consulta de preço.
- **Como a marca ausente entra no índice único** de `cadastro_produto` — sentinela ou
  `NULLS NOT DISTINCT`. Sem decidir, dois "Coca-Cola sem descrição" passam pela trava.

### 14.4 Trabalho declarado e ainda não escrito — §8

11 linhas da tabela de schema seguem `[ ]`: a **1ª migration**, a **função `IMMUTABLE`**
que envolve `unaccent()`, as **duas transações** (salvar compra com rastro, na H7;
desfazer e reaplicar, na H9) e **7 consultas** (H11, H14, H15, H16, H17, H18, H19).
Mais o **`supabase/seed.sql` com 4 meses sintéticos** — sem ele, metade dos relatórios só
seria testável em produção, meses depois.

**Eram 12 e 8 na 1.3.** A H12 saiu da conta na 1.4: a consulta da H11 já devolve o total
por categoria, e o percentual do peso de cada uma é aritmética de Dart sobre um número
que chegou pronto. Escrever uma segunda consulta ali seria a mesma soma em dois lugares.

### 14.5 Três coisas que nenhum documento registra como abertas

Achadas nesta revisão. **São as que mais merecem decisão na próxima sessão**, porque hoje
passam despercebidas:

1. **O questionário técnico não está congelado.** O cabeçalho dele diz
   `Status: [x] Respondido  [ ] Congelado para desenvolvimento`. As 25 decisões estão
   tomadas, mas o documento nunca foi marcado como fechado — e é ele que este handoff
   trata como fonte da verdade técnica.
2. **O checklist dos wireframes v2.0 afirma "nenhuma suposição em aberto no arquivo"**, e
   isso era verdade em 26/08. Em 27/08 os requisitos reabriram quatro perguntas, e **duas
   são de tela**: a ordem do seletor de Produto (Tela 3, `L1`) e a ordem dos itens dentro
   da categoria (Tela 1, `L3`). O rascunho de telas está desatualizado nesse ponto e
   pediria uma v2.1.
3. **O texto da Tela 3 promete mais do que a plataforma entrega.** "Esta compra será salva
   quando o sinal voltar" — o WebKit não tem Background Sync, então isso só acontece com
   o app aberto ou na abertura seguinte (`R16`). O risco está aceito por escrito, mas a
   reconciliação do texto ficou pendente: o próprio `R16` diz que "é o rascunho de telas
   que se ajusta", e ele ainda não se ajustou. **Decisão a tomar:** ajustar o texto agora
   ou depois de medir o comportamento nos dois aparelhos.

### 14.6 O que **não** está em aberto

Para não se reabrir por engano numa próxima leitura:

- **Suposições dos requisitos** — as últimas caíram em 26/08/2026; o documento declara
  "não resta suposição em aberto".
- **Decisões técnicas 1 a 25** — congeladas em 27/08/2026 (a ressalva é o status do
  documento, item 14.5.1, não o conteúdo das decisões).
- **Escopo** — os 18 requisitos são todos Essenciais por decisão do cliente. Desejável e
  Futuro estão em §5; o que não se constrói está em §6.
- **Prazo** — não existe, por ser projeto pessoal. A ordem de entrega do §4 é sequência,
  não cronograma.
