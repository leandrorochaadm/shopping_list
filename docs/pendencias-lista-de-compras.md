# Pendências — o que depende de você

**Data:** 27/08/2026 · **Fonte:** `tecnico §13`, `handoff §13` e `handoff §14`
**Este arquivo não é fonte da verdade** — é o inventário do que está aberto e **só você
pode fechar**. Tudo o que é código está no plano, não aqui.

Cada item diz **o que trava** e tem um espaço de **Resposta** para preencher. O que
estiver marcado `[x]` já foi verificado como feito no repositório.

---

## Resumo

| Bloco | Itens | Bloqueia |
|---|---|---|
| A — Contas e aparelhos | 3 | a 1ª migration e o 1º deploy |
| B — Decisões de schema | 2 | a 1ª migration (**não se corrige depois**) |
| C — Perguntas de negócio | 4 | H5, H7, H11 e H13 — nenhuma trava o início |
| D — Status dos documentos | 3 | nada; são higiene de documento |
| E — Riscos aceitos | 2 | nada; são confirmação por escrito |

**Os únicos que travam o próximo passo são o A e o B.** O bloco C pode ser respondido até
a história que o usa.

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

**Trava:** a 1ª migration e qualquer `flutter run` fora dos fakes.

**Resposta:**
- `dev` — URL: ` ` · chave anônima: ` `
- `prod` — URL: ` ` · chave anônima: ` `
- O `project_ref` do `.mcp.json` é o: ( ) dev ( ) prod

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

**Eu posso ajudar:** eu escrevo o formulário de três campos e o publico junto com o
primeiro deploy. **Cronometrar nos dois aparelhos é você.**

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

**Resposta:**
- Subdomínio: ` `
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

**Sobra desta pendência:** as duas metas do `index.html` e o `robots.txt`
(`tecnico §13`, pendências 5 e 6). **São arquivos do repositório — eu faço**, estão como
passo 1 do plano.

---

## B. Decisões de schema — antes da 1ª migration

`handoff §14.3`. **Não são pergunta ao cliente, são decisão técnica** — mas mudam o
schema inteiro e não se corrigem depois, então precisam do seu "ok" antes de eu escrever
a migration. Já trago a recomendação: **basta você confirmar ou trocar.**

### B1 — Como o produto vendido a peso vira folha

**O problema:** a compra aponta **sempre** para `product` (a folha). Mas a decisão 23 diz
que o vendido a peso **não tem folha de embalagem** — o acém moído não tem "350 ml".

**Recomendação (é o que o `handoff §8` chama de caminho mais simples):** a folha existe
sempre, e no vendido a peso as colunas de embalagem ficam **nulas**. Assim a compra tem
sempre um alvo único e nenhuma consulta de preço precisa de dois caminhos.

**Alternativa descartada:** a compra apontar ora para o cadastro, ora para a folha — isso
duplica toda consulta de preço, de relatório e de comparação entre mercados.

**Decisão:** ( ) folha sempre, com embalagem nula **(recomendado)** ( ) outra: ` `

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

**Decisão:** ( ) `NULLS NOT DISTINCT` **(recomendado)** ( ) marca sentinela ( ) outra: ` `

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

**Resposta:** janela ` ` · desempate ` ` · lista ( ) todos ( ) só os do tipo

---

### C2 (L2) — Como o produto sem marca aparece na divisão por marca → **H11**

O requisito 4 promete "abrir o tipo mostra a divisão por marca, com quantidade e valor de
cada uma", e o acém moído não tem marca nenhuma.

**Resposta:** ( ) linha "Sem marca" ( ) fica fora do detalhamento ( ) outra: ` `

---

### C3 (L3) — Ordem dentro de cada categoria na lista de compras → **H5**

O requisito 8 declara "agrupada por categoria e, dentro de cada uma, em ordem
alfabética", mas a lista em si (requisito 11) só declara o agrupamento. **Se a intenção é
a ordem do corredor, alfabética pode não ser o que você quer.**

**Resposta:** dentro da categoria ( ) alfabética ( ) ordem de entrada ( ) manual
· entre categorias: ` `

---

### C4 (L4) — Fuso horário → confirmar até **H13**

O `tecnico §7.4` assume **America/Porto_Velho (UTC−4)** como premissa; os requisitos não
registram cidade. Três regras dependem de "hoje" — mês do teto, aviso de item repetido e
a janela rolante — e o erro é **silencioso** (`R9`).

**Mitigação já em vigor:** o "hoje" nasce no relógio do aparelho, em Dart, e viaja como
parâmetro (decisão 13). Nenhum `now()` no SQL.

**Resposta:** cidade/fuso: ` `

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
  Tela 1). **Ação:** responder C1 e C3 e publicar a v2.1. `[ ] feito`
- **D3 — O texto da Tela 3 promete mais do que a plataforma entrega.** "Esta compra será
  salva quando o sinal voltar" — o WebKit não tem Background Sync, então isso só acontece
  com **o app aberto** ou **na abertura seguinte** (`R16`). O risco está aceito por
  escrito, mas o texto não se ajustou. **Decisão:** ( ) ajustar o texto agora
  ( ) medir nos dois aparelhos primeiro

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
