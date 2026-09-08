# Questionário técnico — Lista de compras de supermercado

Versão: 1.4 | Data: 27/08/2026
Respondido por: Leandro Rocha — eu mesmo (dono técnico e único desenvolvedor)
Status: [ ] Em coleta  [x] Respondido  [ ] Congelado para desenvolvimento

**Legenda:** 💰 = impacta orçamento · ⛔ = bloqueia o início do desenvolvimento

> **Documento interno.** Escrito em linguagem técnica, para o desenvolvedor.
> Não é o documento que o cliente lê — esse é `requisitos-lista-de-compras.md`.
>
> Não houve Fase A (proposta) neste projeto: é projeto pessoal, sem contrato e sem
> prazo, e o entrevistado é o próprio desenvolvedor. Por isso os itens 💰 foram
> respondidos aqui mesmo, e não importados de uma proposta anterior.

**Entrada:** `requisitos-lista-de-compras.md` (18 requisitos essenciais, aprovados) e
`wireframes-lista-de-compras.md` (6 telas, 6 diálogos e o painel `#3a`). **Os dois são a
fonte da verdade**: onde este documento divergir deles, é este que está errado.

**Atenção ao que a entrada não cobre.** O checklist dos wireframes diz, com todas as
letras, "6 telas principais desenhadas — **não o app inteiro**", e o mapa de navegação
declara quatro telas atrás do menu `≡` que ficaram fora de propósito. Elas atendem
requisitos essenciais e entram na conta deste documento — ver a decisão registrada no
fim do §3.

**O que mudou na 1.4** — revisão do documento contra as duas fontes, sem nova
decisão de negócio. Sete achados:

- **§4.4 contradizia o rascunho de telas.** A Tela 3 promete, com todas as
  letras, "esta compra será salva quando o sinal voltar", e o botão vira
  `[ Salvar quando voltar o sinal ]`. Este documento dizia "sem reenvio
  automático". Quem manda é o rascunho — ver §4.4, decisão 22 e R16.
- **O cadastro tem dois níveis, e este documento tratava como um.** O glossário
  separa *cadastro de produto* (tipo + marca + descrição) de *produto* (a folha,
  com a embalagem). A compra aponta para a folha; a trava de duplicidade vive no
  de cima — ver §3 e decisão 23.
- **A trava de duplicidade não funciona como `UNIQUE` puro no Postgres**, porque
  marca e descrição são opcionais e `NULL` não é igual a `NULL` — §3.
- **Faltava a data de entrada do item na lista**, que sustenta a regra do
  lançamento atrasado e é refeita ao corrigir a data da compra — §3 e R14.
- **Faltava decidir a representação decimal** de dinheiro e quantidade. Em
  `double`, 12 × 0,35 não dá 4,2, e é isso que compara embalagem e calcula a
  porcentagem da calculadora — decisão 24 e R15.
- **§5 cobria só metade do rearme do teto:** faltava o teto criado já acima dos
  100% e faltava a correção de compra que derruba o mês para baixo de um corte.
- **§8.1 contava 11 telas e esquecia os 6 diálogos e o painel `#3a`**, que é
  onde mora o requisito 17 inteiro.

---

## 1. Backend e integrações

| # | Pergunta | Resposta |
|---|---|---|
| 1.1 💰 ⛔ | O backend já existe ou vai ser construído? Por quem? | **Não existe. Supabase**, configurado por mim. Não há backend próprio escrito em código: Postgres gerenciado + PostgREST + Realtime. O requisito 14 (base única fora do celular, dois aparelhos na mesma lista) é o que obriga a existir servidor. |
| 1.2 💰 | Qual a stack do backend? | Postgres gerenciado pelo Supabase. Acesso pelo PostgREST (o próprio schema é a API). Agregações dos relatórios em **views e funções PL/pgSQL**. Atualização da lista comum pelo **Supabase Realtime** (websocket). |
| 1.3 ⛔ | Tem documentação de API? Onde? | Não haverá OpenAPI escrito à mão. **O schema SQL versionado em `supabase/migrations/` é o contrato**, e o PostgREST expõe o schema em runtime. Toda mudança de estrutura entra como migration no repositório — nunca editada direto pelo painel. |
| 1.4 | O contrato da API está estável ou ainda muda? Quem versiona? | Muda enquanto as telas são construídas. Versionado por mim, por migration numerada. |
| 1.5 ⛔ | Tem ambiente de homologação separado de produção? URLs? | **Dois projetos Supabase no plano gratuito: `dev` e `prod`.** Base única foi descartada: uma migration errada apagaria histórico de compra real, que é justamente o dado que não se recupera (não existe cupom guardado — é a dor de origem do projeto). URLs a preencher ao criar os projetos (pendência 13.1). |
| 1.6 ⛔ | Como o app obtém credenciais de acesso aos ambientes? | `SUPABASE_URL` e `SUPABASE_ANON_KEY` por `--dart-define` no build, nunca commitadas no repositório. **A chave anônima é pública por decisão** — ela vai dentro do JS do PWA e não há como escondê-la (ver §9 e R3). O `--dart-define` serve para separar `dev` de `prod`, não para proteger. |
| 1.7 💰 | Integra com sistemas de terceiros? Quais? | **Nenhum na 1ª versão.** Leitura do cupom fiscal (código ou foto) está declarada em "Futuro" no documento de requisitos. |
| 1.8 | Formato de erro padronizado da API? | Erro do PostgREST (`code`, `message`, `details`, `hint`), mapeado na camada `data` para um `Failure` selado do `domain`. A UI nunca vê `PostgrestException`. |
| 1.9 | Paginação: offset/limit, cursor, outro? | `range` do PostgREST (limit/offset) **só no histórico de compras** (tela atrás do `≡`, ver §3). Volume não pede mais: os requisitos dizem **mais de 8 idas por mês** × até 20 itens ≈ 170 itens/mês, ~2 mil/ano. Lista, produtos e mercados carregam inteiros. |
| 1.10 | Tem rate limit? Qual? | O do plano gratuito. Sem efeito prático em dois usuários. |
| 1.11 | Websocket / SSE / polling para tempo real? | **Realtime (websocket) apenas na Tela 1 (lista de compras).** É o único lugar onde os requisitos pedem atualização com a tela aberta — e a regra decidida em 26/08/2026 é: a lista **não se mexe sozinha debaixo do dedo**; a mudança do outro chega como **faixa de aviso**, e a lista só se reordena quando ele toca na faixa. Relatórios e histórico carregam sob demanda. |
| 1.12 ⛔ | Backup e restauração da base de produção | **Nenhum, e a perda é aceita por escrito** (decisão de 27/08/2026). O plano gratuito do Supabase **não tem backup automático** — isso é recurso dos planos pagos. Ou seja: o histórico de compras que §1.5 chama de "dado que não se recupera" também não se recupera de um projeto apagado, corrompido ou pausado tempo demais. Aceito pelo mesmo critério da chave anônima pública: é lista de supermercado, e o custo de resolver (plano pago ou rotina de `pg_dump`) não se paga em dois usuários. **O que a decisão realmente compra é a separação `dev`/`prod` de §1.5** — ela continua sendo a única proteção contra a migration errada, e por isso deixa de ser conforto e vira obrigatória. Ver R13. |

**Pendências de acesso:**

| Item | Responsável | Prazo |
|---|---|---|
| Criar os projetos Supabase `dev` e `prod` e anotar URL + anon key | Leandro | Antes da 1ª linha de código |
| Criar o projeto no Cloudflare Pages e definir o subdomínio | Leandro | Antes do 1º deploy |

---

## 2. Autenticação e autorização

| # | Pergunta | Resposta |
|---|---|---|
| 2.1 💰 ⛔ | Autenticação própria, Firebase Auth, OAuth, SSO, outro? | **Nenhuma.** Decisão de negócio do requisito 14: sem login, sem senha, sem convite e sem cadastro de usuário — o app abre direto na Tela 1. Acesso pela chave anônima com RLS permissiva. |
| 2.2 | Login social? | Não se aplica. |
| 2.3 | Token: JWT? Expiração? Refresh? | Não se aplica. A chave anônima não expira e não é sessão. |
| 2.4 | Onde o token é guardado no dispositivo? | Não se aplica. |
| 2.5 | O que acontece quando o token expira com o app aberto? | Não se aplica. |
| 2.6 💰 | Quantos perfis de usuário existem? Permissões vêm do backend? | **Nenhum perfil e nenhuma permissão.** Os dois têm exatamente os mesmos poderes — a diferença é de combinado, não de sistema. O "quem está usando" (`Leandro` / `esposa`) é **etiqueta local**, guardada no Hive daquele aparelho, gravada no campo `lancado_por` de cada compra. Não é identidade, não controla nada e é trocável na tela de configurações e pelo atalho `👤` da Tela 1. Sustenta **dois** requisitos: o 10 (aviso de item já comprado no mesmo dia) e o 14, porque é ela que faz o histórico mostrar quem lançou cada compra. |
| 2.7 | Logout remoto / revogação de sessão? | Não se aplica — não há sessão. |
| 2.8 💰 | Biometria para reentrar no app? | Não. Contraria o "abre direto" do requisito 14. |
| 2.9 | Múltiplos dispositivos simultâneos: permitido? | **Sim — é o requisito:** os dois celulares na mesma base, ao mesmo tempo. **Só os dois celulares** — o desktop está fora do alvo (§7.2). |

---

## 3. Arquitetura e stack Flutter

| # | Pergunta | Resposta |
|---|---|---|
| 3.1 ⛔ | Projeto novo ou base existente? | **Novo**, já criado: `shopping_list`, com `lib/main.dart` ainda no template. **Criado só com a plataforma `web`** (confirmado em `.metadata`) — não existem pastas `android/` nem `ios/`, o que já casa com a decisão de plataforma (§7.3). |
| 3.2 | Arquitetura: Clean Architecture? | **Não. MVVM oficial do Flutter**, em `ui/`, `data/` e `domain/` — padrão dos meus projetos Flutter. As regras de negócio (limiar de 10%, duas janelas de 3 meses, divisor proporcional, conversão para unidade base, identidade do produto) moram no `domain`, em Dart puro e sem dependência de Flutter nem de Supabase. |
| 3.3 | Gerência de estado: Riverpod? Versão? | **Riverpod 3, providers escritos à mão, sem anotação e sem codegen.** |
| 3.4 | Navegação: GoRouter? Deep link e rota protegida? | **GoRouter**, com rota nomeada para cada tela — as 6 do rascunho e as 5 que ele não desenhou (decisão no fim deste capítulo). **Nenhuma rota protegida** — não há sessão para proteger. **Existe um único `redirect`**, e ele não é de sessão: enquanto a etiqueta de "quem está usando" não estiver no Hive, toda rota cai na tela de primeira abertura (§3, requisito 14). É estado local do aparelho, não identidade — depois de marcado uma vez, o `redirect` nunca mais dispara. Deep link não se aplica; a URL por rota vem de graça por ser web, mas não é usada como recurso — o desktop está fora do alvo (§7.2) e o app instalado no iPhone não mostra barra de endereço. Os 6 diálogos são `showDialog`/`showModalBottomSheet` sobre a tela de origem, não rotas. |
| 3.5 | Injeção de dependência: Riverpod ou get_it? | **Riverpod.** Sem `get_it`. |
| 3.6 | Cliente HTTP: Dio ou http? Interceptors? | **`supabase_flutter`**, que já traz o cliente. Sem Dio e sem interceptor de auth (não há token). Retry e log ficam no repositório da camada `data`. |
| 3.7 | Modelagem: freezed + json_serializable? Codegen permitido? | **Sem codegen.** Modelos com `fromJson`/`toJson`/`copyWith` escritos à mão, classes seladas do Dart 3 para os estados. Consequência aceita: mais boilerplate por modelo. |
| 3.8 ⛔ | Versão mínima do Flutter e do Dart | **Flutter 3.44.0 stable · Dart 3.12.0** (o que está instalado). `pubspec.yaml` já fixa `sdk: ^3.12.0`. |
| 3.9 | Flavors: dev / homolog / prod? | Sem flavors nativos — não existem em build web. A separação é por `--dart-define` (§1.6) e por dois deploys distintos no Cloudflare Pages (preview e produção). |
| 3.10 | Design system próprio ou Material padrão? Tema claro e escuro? | **Material 3 padrão, tema claro apenas.** Sem design system próprio. Os wireframes são preto e branco de propósito, mas isso vale para o rascunho de validação, não para o app final. |
| 3.11 | Padrão de tratamento de erro (Result/Either ou exceção)? | **`Result` selado escrito à mão** (`sealed class Result<T>` com `Ok`/`Err`), sem pacote externo. Exceção só atravessa a fronteira da camada `data`, onde vira `Failure`. |
| 3.12 | Log e observabilidade em runtime | `debugPrint` em desenvolvimento. Sem observabilidade em produção na 1ª versão (§5.6). |
| 3.13 | Lint: qual pacote e regras? | `flutter_lints: ^6.0.0`, já no `pubspec.yaml`, com o `analysis_options.yaml` padrão. |

**Dependências previstas** (nenhuma delas exige codegen):

`supabase_flutter` · `flutter_riverpod` (3.x) · `go_router` · `hive_ce` + `hive_ce_flutter` · `intl`

**Nenhum pacote a mais para saber que o sinal voltou** (decisão 22): em web, os eventos
`online`/`offline` do navegador chegam pelo pacote `web` que o SDK já traz, e a
reconexão do canal do `supabase_flutter` é o segundo sinal. Sem `connectivity_plus`, que
em web faria o mesmo por baixo.

O "sem codegen" do Hive tem uma condição: **o rascunho é gravado como `Map`/lista de
`Map` de tipos primitivos**, nunca como objeto tipado. Objeto tipado exige `TypeAdapter`
— gerado ou escrito à mão —, e aí o §3.7 cai. A serialização do rascunho é a mesma
`toJson`/`fromJson` dos modelos.

**Decisão registrada — as telas do app são 11, e não 6.**
Os wireframes desenharam as 6 telas do dia a dia e dizem no próprio checklist que isso
"**não é o app inteiro**". Abaixo do mapa de navegação eles declaram, com dono e
requisito, **quatro telas atrás do menu `≡`** que ficaram fora do rascunho por escolha
de escopo daquele documento — não por não existirem. Some-se a tela de primeira
abertura, descrita nos estados da Tela 1. Todas atendem requisitos **essenciais**, e
portanto entram na 1ª versão:

| Tela | Requisito | O que ela faz |
|---|---|---|
| Histórico de compras lançadas | 12, 14 | Lista as compras e mostra **quem lançou cada uma**. É a única tela paginada (§1.9) |
| Correção ou exclusão de compra | 12 | Abre uma compra do histórico para corrigir ou apagar |
| Manutenção do cadastro | 16 | Renomear, reclassificar, desativar e reativar categoria, tipo, marca, produto, embalagem e mercado; acrescentar embalagem a produto existente |
| Configurações | 9 | Define e altera o teto do mês; troca "quem está usando" |
| Primeira abertura | 14 | "Quem está usando? ( ) Leandro ( ) esposa", uma vez por aparelho, antes da Tela 1 |

Não são telas novas inventadas aqui: são as telas que os requisitos já exigiam e que o
rascunho visual adiou. O que muda neste documento é a conta — rotas (§3.4), widget
tests (§8.1) e saída própria por tela (R11) valem para as 11, não para 6.

**Duas delas mandam no schema, e por isso a decisão não é só de escopo:**

- **A manutenção do cadastro obriga soft delete e referência por chave.** Os requisitos
  são explícitos: renomear "Carrefur" para "Carrefour" **vale para todo o histórico**;
  embalagem com compra lançada **não pode ser apagada, só desativada**; e desativar
  **tem volta**. Isso quer dizer que a compra aponta para o cadastro por chave
  estrangeira e **nunca copia o nome**, e que categoria, tipo, marca, produto,
  embalagem e mercado têm coluna `ativo` — nenhum `DELETE` nesses seis. Um cadastro
  desnormalizado "para o relatório ficar simples" quebraria a renomeação retroativa, que
  é requisito, não conveniência.
- **Corrigir uma compra tem de refazer o efeito dela sobre a lista** — ver R14.

**Decisão registrada — "produto" são dois níveis, e a compra aponta para o de baixo.**
Este documento vinha escrevendo "produto" e "embalagem" como se fossem duas colunas da
mesma linha. O glossário dos requisitos separa os dois com nome próprio, e a separação
manda no schema:

- **cadastro de produto** = `tipo + marca + descrição`, preenchido uma vez. É o nível
  que **não pode se repetir** e o que a Tela 4 abre para acrescentar embalagem;
- **produto** (a folha) = o cadastro **mais uma embalagem**. É ele que tem preço e
  histórico próprios, é ele que a compra aponta, e são quatro deles que nascem de um
  cadastro só de refrigerante.

Os dois níveis têm `ativo` próprio, porque os requisitos desativam os dois em frases
diferentes: "desativa um produto que não compra mais" e "embalagem com compra lançada
não pode ser apagada, só desativada". Produto **vendido a peso não tem folha de
embalagem** — o cadastro é a própria coisa comprada —, e é isso que faz a calculadora
(`#3a`) dizer *"produtos", e não "embalagens"*: a mussarela do balcão é uma linha sem
embalagem nenhuma. Modelar um nível só obrigaria a repetir tipo, marca e descrição em
cada embalagem, e aí a trava de duplicidade não teria onde morar.

**A trava de duplicidade não é um `UNIQUE` simples.** Marca e descrição são opcionais, e
no Postgres duas linhas com `NULL` na mesma coluna **não** violam índice único — dois
"Coca-Cola sem descrição" passariam, que é exatamente o que os requisitos mandam barrar
("em branco também conta como valor"). O caminho é índice único sobre valor normalizado,
nunca sobre a coluna crua: descrição guardada como **texto vazio, nunca `NULL`**, marca
ausente resolvida por um sentinela ou por `NULLS NOT DISTINCT`, e a comparação
**ignorando maiúsculas, espaço sobrando e acento** aplicada antes — `unaccent(lower(trim(…)))`
numa coluna gerada. **Atenção a uma armadilha do dia 1:** `unaccent()` é `STABLE`, não
`IMMUTABLE`, porque depende do dicionário, e o Postgres recusa índice e coluna gerada em
cima dela — o caminho é uma função `IMMUTABLE` própria envolvendo a chamada, criada na
mesma migration. Mesmo assim, **quem responde ao usuário é o Dart**: a Tela 4 trava o
salvar assim que a descrição sai do foco, e o índice é a rede embaixo, não a mensagem.
Vale para as quatro comparações do projeto — tipo, categoria, marca e mercado —, que os
requisitos mandam serem a mesma.

**Decisão registrada — o item da lista guarda a data em que entrou nela.**
Os requisitos pedem isso por escrito em *Informações e volume*, e uma regra inteira
depende dela: *"só sai da lista o item cuja entrada aconteceu antes ou no mesmo dia da
compra lançada"* — é o que impede o lançamento atrasado do dia 13 apagar a falta que
nasceu no dia 12. Sem essa coluna a regra é impossível de escrever, e ela não pode ser
reconstruída depois. Ela também é metade de R14: corrigir a **data** de uma compra refaz
essa comparação item por item, e não só o total do relatório.

---

## 4. Dados locais, offline e sincronização

| # | Pergunta | Resposta |
|---|---|---|
| 4.1 💰 | Precisa funcionar offline? Quais telas exatamente? | **Só o rascunho do lançamento (Tela 3).** O documento de requisitos é explícito: o app exige internet, e "funcionar sem sinal dentro do mercado" está declarado como fora de escopo, com o risco aceito. A **única** exceção é o requisito 3: o lançamento em andamento sobrevive a queda de conexão e a app fechado — 18 de 20 itens digitados não podem se perder, porque perder um lançamento inteiro uma vez mata o hábito, que é o maior risco declarado do projeto. **Consequência a registrar:** sem sinal ele **guarda e continua**, mas não **acrescenta** — escolher produto e mercado depende das listas que vêm do servidor, e o rascunho recuperado abre com os campos em "Carregando..." (estado desenhado na Tela 3). O critério de aceite dos requisitos é justamente esse: os 18 itens continuam lá "prontos para salvar", não "prontos para virarem 20". |
| 4.2 | Persistência local: Hive, Isar, Drift, SharedPreferences? | **Hive** (`hive_ce`, o fork mantido). Guarda duas coisas e nada mais: o rascunho do lançamento — **com a marca de "pendente de envio"** da decisão 22, que é parte do rascunho e não um terceiro dado — e a etiqueta de quem está usando o aparelho. **Em web, o Hive grava em IndexedDB** — ver R2 e R5. |
| 4.3 | Cache de rede: tem? Por quanto tempo? | **Não há cache de dados.** Sem sinal, a lista não abre — comportamento decidido e registrado. Na Tela 1, o Realtime mantém o dado fresco enquanto a tela está aberta. |
| 4.4 💰 | Escrita offline com fila de sincronização? | **Sim, mas de uma compra só — e a versão 1.3 deste documento dizia o contrário, errado.** A Tela 3 promete na tela: *"Esta compra está guardada no aparelho e será salva quando o sinal voltar"*, com o botão virando `[ Salvar quando voltar o sinal ]↻`. Então existe, sim, estado **"pendente de envio"**: o rascunho no Hive ganha uma marca de que ele já foi mandado salvar, e o app tenta de novo quando a conexão volta. O que **não** existe é fila: **um rascunho por aparelho**, nunca uma pilha de compras esperando. Isso mantém §4.5 de pé — a escrita continua sendo uma só, transacional, e não há dois caminhos de gravação concorrendo. **O limite é o iOS**, e ele é intransponível: o WebKit não tem Background Sync, então "quando o sinal voltar" só acontece **com o app aberto** ou **na abertura seguinte** — nunca com o app fechado no bolso. Ver decisão 22 e R16. |
| 4.5 💰 | Resolução de conflito: último vence, servidor vence, merge manual? | **Último a escrever vence** — o comportamento natural do Postgres, e não há caminho para conflito real: cada item da lista é uma linha própria, e dois marcando o mesmo item ao mesmo tempo convergem no mesmo estado ("pego"). **O rascunho pendente de §4.4 não abre exceção:** ele é um `INSERT` de compra nova, nunca um `UPDATE` sobre linha que o outro possa ter mexido, e a única coisa que ele reaplica é a baixa da lista — que já é idempotente pela regra da data de entrada (§3). O que precisa de cuidado é o outro lado: **a chave da compra nasce no aparelho**, para o reenvio que chegou duas vezes não virar compra duplicada. |
| 4.6 | Volume de dados guardado no dispositivo | Um rascunho de até 20 itens: dezenas de KB. |
| 4.7 | O que acontece com os dados locais no logout? | Não se aplica — não há logout. |
| 4.8 | Migração de schema local entre versões do app | O rascunho é **descartável**: mudando a estrutura, a chave do box é versionada (`rascunho_v2`) e o rascunho antigo é ignorado e apagado. Não vale escrever migração para um dado que vive horas. |

---

## 5. Serviços de plataforma

| # | Pergunta | Resposta |
|---|---|---|
| 5.1 💰 ⛔ | Gateway de pagamento | Não se aplica — o app não cobra nada de ninguém. |
| 5.2 💰 | Assinatura recorrente | Não se aplica. |
| 5.3 💰 | Push notification: FCM? Quem dispara? | **Nenhuma na 1ª versão.** O aviso do teto (requisito 9, 80% e 100%) é **aviso dentro do app**. Notificação com o app fechado está declarada em "Futuro" no documento de requisitos. |
| 5.4 | Deep link / universal link | Não se aplica. As URLs de rota do GoRouter existem por ser web, mas não há link externo apontando para dentro do app. |
| 5.5 | Analytics | Nenhum. Dois usuários conhecidos; não há o que medir que uma conversa não responda. |
| 5.6 | Crash reporting: Crashlytics, Sentry? | **Nenhum na 1ª versão.** Erro reproduzido na hora por quem também escreve o código. Revisitar se a esposa começar a relatar falha que eu não reproduzo. |
| 5.7 | Remote config / feature flag | Não. |
| 5.8 💰 | Mapa | Não se aplica — mercado é cadastro de nome, sem endereço nem localização (requisito 15). |
| 5.9 💰 | Upload de arquivo/foto/vídeo | **Nenhum.** Não há imagem no projeto — a própria especificação do rascunho de telas registra isso. A foto do cupom fiscal está em "Futuro". |

**Decisão registrada — o teto mora no Postgres, em duas tabelas: vigência e avisos.**
O item 5.3 responde *como o aviso chega* (dentro do app), mas não *onde o teto mora* —
e ele não pode morar no Hive: §4.2 guarda duas coisas e nada mais, e o teto é do casal,
não do aparelho.

O que os requisitos pedem são **duas coisas com vida diferente**, e é isso que decide a
modelagem:

- o **teto** é *"um valor só, que vale para todo mês"*, alterável, valendo *"do mês
  corrente em diante"*, com o sistema guardando *"o valor que vale hoje e o que valia em
  cada mês passado"*. Ou seja: **atravessa meses sozinho**, sem ninguém tocar em nada;
- os **avisos de 80% e 100%** são do mês: dão-se uma vez cada, e **alterar o teto zera os
  dois avisos do mês corrente e reavalia na hora**.

Juntar as duas numa linha por mês foi um erro de uma versão anterior deste documento:
setembro sem linha ficaria sem teto, e agosto teria de ser copiado para setembro por
alguém — no banco isso pediria `current_date`, que a decisão 13 proíbe. Separadas, cada
uma faz só o seu trabalho:

**`teto`** — uma linha por **alteração**, não por mês:

| Coluna | Para quê |
|---|---|
| `vigente_desde` (`date`, sempre dia 1) | A chave. O teto do mês `M` é o `valor` da última linha com `vigente_desde <= M` |
| `valor` | O teto que passou a valer naquele mês |

É essa consulta que entrega as duas metades do requisito de uma vez: "o valor que vale
hoje" é a última linha, e "o que valia em cada mês passado" cai de graça — o relatório de
um mês fechado continua achando o teto da época, e nunca muda de resposta. **Mês
anterior à primeira linha é mês sem teto para sempre**: nenhum aviso, e o relatório sem o
"de Y", que é exatamente o que os requisitos mandam.

**`aviso_teto`** — uma linha por **mês**, criada quando o primeiro aviso daquele mês é
dado:

| Coluna | Para quê |
|---|---|
| `mes` (`date`, sempre dia 1) | A chave |
| `aviso_80_em`, `aviso_100_em` (`date`, nulos) | Marcam que aquele aviso já foi dado naquele mês |

**O rearme é código explícito, não efeito colateral:** salvar um teto novo grava a linha
em `teto` e **apaga a linha de `aviso_teto` do mês corrente**, na mesma transação. Os
meses fechados não são tocados — o rearme é só do mês corrente, como os requisitos
dizem.

E há um caso que a versão anterior deixava cair: **salvar um teto que o mês já
ultrapassou avisa ali mesmo**, e *"esse aviso conta como o dos 80%"*. Então a mesma
transação, depois de apagar a linha, reavalia o mês e **já grava `aviso_80_em`** se o
gasto estiver acima do corte — senão o aviso apareceria na tela e voltaria a aparecer no
lançamento seguinte. **E se o mês já estiver acima dos 100%, grava os dois:** os
requisitos dizem que a configuração do teto é uma das *três coisas que fazem o mês cruzar
um corte* — plural —, e um teto nascido em 120% que só consumisse o aviso dos 80%
soltaria o "estourou" no lançamento seguinte, sobre um estouro que já era passado.

**O rearme tem uma segunda porta, e ela vem da correção de compra.** Os requisitos são
explícitos: *"se uma correção ou exclusão de compra derrubar o mês para baixo de um dos
cortes, aquele aviso volta a ficar disponível e dispara de novo quando o corte for
cruzado outra vez"*. Ou seja, `aviso_80_em` e `aviso_100_em` não são marcas definitivas:
toda escrita que mexe no total do mês — lançar, corrigir, apagar — reavalia os dois
cortes e **limpa a marca do corte que o mês deixou de cruzar**, na mesma transação de
R14. Sem isso, um R$ 38 digitado como R$ 3,80 e corrigido depois consumiria o aviso do
mês em silêncio, e o estouro de verdade passaria sem nada na tela. É a mesma
transação, não um segundo passo: o mapa de navegação dos wireframes já registra que
corrigir uma compra *"pode disparar ou rearmar os avisos de teto"*.

Nada aqui é regra de negócio: os limiares de 80% e 100%, a comparação e a decisão de
qual aviso disparar continuam no `domain`, em Dart, pela fronteira do §12.7 (ver R7). O
Postgres guarda a vigência e a marca; quem lê "está em 87%" é o Dart.

---

## 6. Build, distribuição e publicação

| # | Pergunta | Resposta |
|---|---|---|
| 6.1 💰 ⛔ | Contas Google Play e Apple Developer | **Nenhuma, e não serão criadas.** O alvo é PWA. Economiza US$ 25 (Play) + US$ 99/ano (Apple), a ficha das lojas e a política de privacidade obrigatória — nada disso entrega valor para dois usuários. |
| 6.2 ⛔ | Quem publica — eu ou o cliente? | Eu. "Publicar" aqui é deploy no **Cloudflare Pages**. |
| 6.3 ⛔ | Quem guarda a keystore Android e os certificados iOS? | Não se aplica — não há build nativo assinado. |
| 6.4 | Bundle id / application id definido? | Não se aplica. A identidade do app é o **subdomínio + `web/manifest.json`**: `name`, `short_name`, `description`, `background_color`, `theme_color` e os ícones de 192 e 512 px. O `start_url` (`.`) e o `display` (`standalone`) do template **já estão certos** e não precisam de mudança; o que está com valor de template é o resto — nome `shopping_list`, descrição "A new Flutter project" e o azul `#0175C2` em `background_color` e `theme_color`. **No iOS, quem manda no ícone e no nome é o `index.html`, não só o manifest**: o `<link rel="apple-touch-icon">` e o `<meta name="apple-mobile-web-app-title">` — os dois já existem no template, apontando para `Icon-192.png` e para o nome `shopping_list`. No mesmo arquivo ainda estão de template o `<title>` e o `<meta name="description">`. O título aparece cortado embaixo do ícone depois de ~12 caracteres, então o nome curto precisa caber aí. **Três coisas do template já estão certas e não se mexe:** `start_url`, `display` e `"orientation": "portrait-primary"` no manifest — este último sem efeito nenhum no iPhone (§7.2) —, mais o `apple-mobile-web-app-status-bar-style: black` do `index.html`, que é o que hoje mantém o conteúdo abaixo do recorte (R12). **Falta uma linha que o template não tem:** `<meta name="apple-mobile-web-app-capable" content="yes">` — ver abaixo. |
| 6.5 | CI/CD: existe? Qual? Quem mantém? | **GitHub Actions**, mantido por mim. **Atenção:** o builder padrão do Cloudflare Pages não tem Flutter — não adianta apontar o repositório e mandar buildar. O caminho é a Action instalar o Flutter, rodar `flutter build web --release --dart-define=...` e publicar `build/web` com o `wrangler`. |
| 6.6 | Distribuição de build de teste | As **URLs de preview** do Cloudflare Pages, geradas por branch, apontando para o Supabase `dev`. |
| 6.6.1 ⛔ | Como o app entra no celular | **Safari → Compartilhar → Adicionar à Tela de Início.** **Antes disso, uma linha no `index.html`:** o template do Flutter 3.44 traz só `<meta name="mobile-web-app-capable">` e não traz mais o `apple-mobile-web-app-capable`, que era o que garantia tela cheia no iOS. O reconhecimento do nome genérico pelo WebKit é recente, e os aparelhos estão em "iOS 17 ou superior" — faixa onde isso não é certo. Como a decisão 11 depende de standalone **de verdade** (é ele que dá armazenamento próprio, R5), a tag antiga entra junto: custa uma linha e não conflita com a nova. Confirmar nos dois aparelhos. No iOS não existe banner de instalação (o `beforeinstallprompt` não é suportado), então o passo é sempre manual. **Desde o iOS 16.4, Chrome, Edge e Firefox no iPhone também conseguem adicionar à tela de início**, e o resultado é um web app em tela cheia igual ao do Safari — a instrução usa o Safari por ser o caminho mais curto, não por ser o único. É passo único por aparelho, mas **não é opcional**: fora da tela de início o app fica exposto à limpeza de armazenamento a cada 7 dias parado (R5) e ganha a barra do navegador de volta. **Atenção ao efeito colateral:** o app na tela de início tem **armazenamento próprio, separado do da aba do Safari**. O rascunho e a etiqueta de "quem está usando" gravados enquanto se testava pelo navegador **não aparecem** no app instalado, e vice-versa — o que significa que os testes de R2 e R5 valem no app instalado, e só nele. |
| 6.7 | Versionamento e changelog | `version` do `pubspec.yaml` em semver. Sem changelog formal — projeto pessoal, um desenvolvedor. |
| 6.8 | Precisa de atualização forçada de versão mínima? | Não, mas o comportamento precisa ser conhecido: o service worker do Flutter baixa a versão nova em segundo plano e **ela só passa a valer na abertura seguinte**. Ou seja, um deploy corretivo demora uma sessão para chegar ao celular dela. Aceitável; se algum dia incomodar, o caminho é um aviso de "versão nova disponível, recarregue". |
| 6.9 | Ficha das lojas, política de privacidade: quem produz? | Não se aplica — não vai a loja nenhuma. |

---

## 7. Compatibilidade

| # | Pergunta | Resposta |
|---|---|---|
| 7.1 💰 | Versão mínima de Android e de iOS | Não se aplica (sem app nativo). O que vale é **navegador, e o navegador é um só: Safari no iOS**. Os dois aparelhos são iPhone — **12 e 15** —, os dois rodam iOS 17 ou superior, e no iOS todo navegador usa o mesmo motor do Safari por baixo. **Android sai do alvo**: não há aparelho Android na casa, e testar nele seria testar o que ninguém usa. Isso concentra o teste (um motor só, dois aparelhos reais) e ativa quatro ressalvas próprias do iOS — R5, R10, R11 e R12. |
| 7.2 💰 | Suporte a tablet? Orientação paisagem? | Layout de **celular em retrato**, e nada mais. **O desktop está fora do alvo** (decisão de 27/08/2026): o "Desejável 1" (relatórios no computador) continua desejável e continua adiado, exatamente como os requisitos dizem em *Limites* ("só celular por enquanto"). Sem tela de mesa, sem layout de tela larga, sem teste e sem critério de aceite. A build web abre num navegador de computador por ser web — isso é consequência técnica, não entrega, e não é verificado. Tablet e paisagem seguem a mesma régua: não são alvo — **mas paisagem não é evitável, e isso precisa estar escrito.** O `manifest.json` já traz `"orientation": "portrait-primary"`, e o Safari **ignora** esse campo; a `Screen Orientation API` também não tem `lock()` no iOS. Ou seja: o app **vai** girar quando o aparelho girar, e "não é alvo" não impede nada. A decisão é **aceitar que a paisagem fica torta e não é testada** — sem critério de aceite e sem correção de layout. Se um dia incomodar, o caminho é travar em retrato no Dart, não no manifest. |
| 7.3 | Precisa de web ou desktop? | **Web é o único alvo.** O projeto já foi criado só com a plataforma `web`. Sem app nativo, sem desktop empacotado. Consequência assumida: tudo depende da performance do Flutter Web no celular (R1). |
| 7.4 💰 | Internacionalização: idiomas, data, moeda, fuso? | **pt-BR apenas.** `intl` com locale `pt_BR`: R$ com vírgula decimal, data `dd/MM/aaaa`. Fuso **America/Porto_Velho (UTC−4)** — premissa do documento técnico, não dos requisitos, que não registram cidade. **A data da compra é `date` no Postgres, nunca `timestamptz`**: guardada com fuso, uma compra do **dia 30 às 21h** vira dia 31 em UTC e, na virada do mês, cai no mês seguinte — quebrando o relatório do período e o aviso do teto de uma vez só. Ver R8. |
| 7.5 | Acessibilidade | Básico: alvos de toque de 48 px, contraste do Material 3, rótulo semântico nos botões só de ícone. Sem meta de conformidade formal. |
| 7.6 | Aparelhos de referência para teste | **iPhone 12** (dele) e **iPhone 15** (dela), os dois com o app na tela de início — não em aba do Safari (§6.6). O iPhone 12 é o piso de desempenho e é nele que a meta de 2 minutos vale. **Nenhum outro aparelho entra na lista** — sem Android e sem computador (§7.2). |

---

## 8. Qualidade e testes

| # | Pergunta | Resposta |
|---|---|---|
| 8.1 | Cobertura esperada e obrigatória em quais camadas | **`domain` com teste obrigatório**, sem exceção — é onde moram as regras que erram em silêncio: limiar de 10% do alerta de preço, as **duas** janelas de 3 meses (rolante × fechada), divisor proporcional da média, conversão para unidade base (350 ml → 0,35 L), identidade do produto (tipo + marca + descrição, com descrição em branco contando como valor) e as comparações que ignoram maiúsculas, espaço sobrando e acento. **Mais cinco que a lista da 1.3 deixava de fora, e que erram do mesmo jeito silencioso:** a **baixa da lista** inteira (compra parcial abate e não zera, item sem quantidade sai na primeira compra, compra com data anterior não mexe em item que entrou depois, "não encontrei" caindo na primeira compra do tipo); o **preço médio** como total ÷ quantidade, nunca média de médias (R$ 32 o quilo, não R$ 36); a **porcentagem da calculadora** calculada sobre valor cheio e o empate abaixo de 1%; o **"hoje ou ontem"** do aviso de item repetido; e o **rearme do teto** nos dois sentidos (§5). Widget test nas **11 telas** (§3) **e nos 6 diálogos mais o painel `#3a`** — o `#3a` sozinho carrega o requisito 17 inteiro, e o mini-cadastro de tipo é o caminho mais usado do app segundo os próprios wireframes. Sem meta numérica de percentual. |
| 8.2 | Stack de teste | `flutter_test` + `mocktail`. Teste de integração ponta a ponta fica fora da 1ª versão. |
| 8.3 💰 | Existe QA do lado do cliente? Quem homologa? | Eu escrevo e eu homologo. A esposa é a segunda usuária real — e é o melhor teste de usabilidade que o projeto tem, porque ela não conhece a implementação. |
| 8.4 | Critério de aceite de uma entrega | Os **"Pronto quando"** do documento de requisitos, um a um. Já são critérios executáveis, incluindo o cronômetro dos 2 minutos com 20 itens. |
| 8.5 | Ambiente e massa de dados para teste | Supabase `dev` com seed. **O seed precisa de 4 meses de compras sintéticas**, senão alerta de preço, comparação entre mercados, sugestão da lista e "falta comprar no mês" não têm o que mostrar — as duas janelas de 3 meses não existem em base nova. Sem isso, metade dos relatórios só pode ser testada em produção, meses depois. **O seed segue o mesmo regime do schema** (§1.3): arquivo versionado em `supabase/seed.sql`, aplicado só no projeto `dev`, nunca digitado à mão pelo painel. Seed que não está no repositório não é reproduzível, e um teste de janela de 3 meses que não é reproduzível não vale nada. |
| 8.6 | Code review: quem revisa? Padrão de branch e PR | Desenvolvedor único. Branch por funcionalidade, merge em `main` sem PR formal. |

---

## 9. Segurança, dados sensíveis e LGPD

| # | Pergunta | Resposta |
|---|---|---|
| 9.1 💰 | O app trata dado pessoal sensível? Quais? | **Não.** Compras de supermercado e dois rótulos fixos ("Leandro", "esposa") que não identificam ninguém fora do casal. Sem e-mail, telefone, documento ou localização. |
| 9.2 | Existe política de privacidade e termos de uso? | Não, e não é exigida: sem loja, sem público e sem dado de terceiro. |
| 9.3 | Precisa de consentimento explícito dentro do app? | Não. |
| 9.4 | Exclusão de conta e de dados pelo usuário | Não se aplica — não há conta. |
| 9.5 | Criptografia em repouso e em trânsito | Trânsito: HTTPS ponta a ponta (Cloudflare e Supabase). Repouso: o padrão do Supabase. **O IndexedDB local não é criptografado** — e não precisa: guarda um rascunho de compra. |
| 9.6 | Certificate pinning, ofuscação, proteção contra root/jailbreak | Não se aplica em web. |
| 9.7 | Retenção e anonimização de log | Nenhum log guardado. |
| 9.8 | Auditoria ou compliance específico do setor | Nenhum. |

**Decisão registrada — a base é aberta a quem tiver a URL.**
Sem login (requisito 14), a chave anônima do Supabase viaja dentro do JavaScript do
PWA e **não há como escondê-la**: qualquer pessoa com a URL pode ler e escrever na
base inteira. Isso foi decidido e aceito — o documento de requisitos já registra a
consequência ("quem abrir o app vê tudo") e o dado é lista de supermercado.
Barreira única: **a URL não é divulgada**. Duas mitigações baratas que valem a pena
mesmo assim, por reduzirem a chance de a URL vazar sozinha:

- subdomínio não adivinhável (não usar `shopping-list` puro);
- `robots.txt` bloqueando indexação e `<meta name="robots" content="noindex">`.

Se um dia o app deixar de ser só dos dois, o que muda é este item — e aí volta a
conversa de login, que hoje está descartada de propósito.

---

## 10. Pessoas e comunicação

| # | Pergunta | Resposta |
|---|---|---|
| 10.1 ⛔ | Quem é o dono técnico do lado do cliente? | Leandro — cliente e desenvolvedor são a mesma pessoa. |
| 10.2 ⛔ | Canal oficial e tempo de resposta | Conversa direta. A esposa é a segunda interessada e responde na hora. |
| 10.3 | Quem aprova entregas do ponto de vista de negócio | Leandro, pelos "Pronto quando" do documento de requisitos. |
| 10.4 | Quem resolve dúvida de API quando o backend é de terceiro | Não se aplica: o "backend" é o schema do Supabase, escrito por mim. |
| 10.5 | Cadência de reunião de acompanhamento | Não se aplica. |
| 10.6 | Onde ficam as tarefas? Tenho acesso? | Sem board. A ordem de construção do documento de requisitos faz esse papel. Handoff só se deixar de ser um desenvolvedor só. |
| 10.7 | Quem assume o app depois da entrega? Repasse técnico? | Eu mesmo. Sem repasse. |

---

## 11. Riscos técnicos identificados

Os riscos são referenciados no documento inteiro como **`R1`…`R16`**. "Risco
principal" quer dizer *o mais grave*, e não o de número 1 — os dois já se
confundiram numa versão anterior deste arquivo.

| # | Risco | Impacto | Mitigação | Dono |
|---|---|---|---|---|
| R1 | **Flutter Web pode não sustentar a meta de 2 minutos / 20 itens.** O CanvasKit baixa alguns MB na primeira abertura e a latência de toque é pior que a de app nativo. A meta já é agressiva por si só — 6 segundos por item — e é o critério de aceite do requisito 3 | **Médio** (era alto). Saber que os aparelhos são iPhone 12 e 15 derruba metade do risco: são chips A14 e A16, e o download inicial só pesa na primeira abertura, não nas oito idas ao mercado do mês | **Construir a Tela 3 cedo e cronometrar no iPhone 12**, que é o piso. Se não fechar: primeiro cortar campos do lançamento (caminho já previsto nos requisitos), e só depois reabrir a decisão de plataforma. **Não conte com "trocar o renderer":** no Flutter 3.44 sobraram `canvaskit` (padrão) e `skwasm`, e o renderer HTML acabou. O `skwasm` exige WasmGC, que só chega no Safari 18.2 — fora do "iOS 17 ou superior" declarado em §7.1 | Leandro |
| R2 | **Sem sinal, o PWA pode nem abrir** — e aí o rascunho do requisito 3 existe no IndexedDB mas fica inalcançável, porque a tela que o lê não carrega | Alto — mata justamente o critério "fecha o app, volta uma hora depois e os 18 itens estão lá" | Validar o service worker do Flutter em **modo avião**, com o app fechado, antes de dar o requisito 3 por pronto. É teste manual e precisa entrar na lista de aceite | Leandro |
| R3 | **Chave anônima pública** — quem tiver a URL lê e escreve tudo | Baixo, e aceito (§9) | URL não divulgada, subdomínio não adivinhável, `noindex` | Leandro |
| R4 | **O plano gratuito do Supabase pausa projeto inativo** (cerca de uma semana sem acesso) | Baixo — mais de 8 idas ao mercado por mês mantêm a base ativa; o `dev`, que fica parado, é o candidato a pausar | Reativar pelo painel quando acontecer. Se virar incômodo no `prod`, aí sim vale o plano pago | Leandro |
| R5 | **Safari apaga o armazenamento do site após 7 dias sem uso** — IndexedDB, service worker e tudo mais que o script escreveu. Com os dois aparelhos sendo iPhone, isso deixou de ser ressalva e virou comportamento do alvo principal | **Médio.** O rascunho vive horas e não sofre; quem sofre é o app inteiro, que a cada volta de férias baixaria tudo de novo e perderia a etiqueta de quem está usando | **Instalar na tela de início reduz drasticamente a exposição:** o limite de 7 dias é política do Safari para site aberto em aba, e o app instalado tem armazenamento próprio, fora dessa contagem. **Não é garantia** — o iOS ainda pode descartar armazenamento sob pressão de espaço, e a política é da Apple, não contrato. É o que transforma o "Adicionar à Tela de Início" (§6.6.1) de conveniência em requisito de instalação. Conferir nos dois aparelhos **já instalados**, antes de confiar | Leandro |
| R6 | **Cloudflare Pages não constrói Flutter** no builder padrão | Médio se descoberto tarde — trava o primeiro deploy | GitHub Actions instala o Flutter, builda e publica `build/web` com `wrangler` (§6.5) | Leandro |
| R7 | **Regra de negócio dividida entre SQL e Dart** (decisão "misto" do §12.7): a mesma regra escrita nos dois lugares diverge com o tempo, e a metade que está em SQL não é coberta pelos testes de unidade | Médio — erro de relatório aparece meses depois, quando ninguém lembra do porquê | **Fronteira escrita e respeitada:** o Postgres só soma e agrupa por período; **nenhum número de regra vive no SQL** — limiar de 10%, as duas janelas de 3 meses e o divisor proporcional ficam exclusivamente no `domain`, em Dart, testados. **Escrever o que o SQL devolve, para a fronteira não vazar na hora do aperto:** por tipo de produto, o **total consumido** no intervalo recebido por parâmetro e a **data da primeira compra** daquele tipo. Com esses dois números o Dart calcula sozinho quantos meses fechados de vida o produto tem dentro da janela e faz a divisão. Um `CASE` no SQL decidindo "divide por 2 ou por 3" seria a regra migrando para o lado sem teste | Leandro |
| R8 | **Data da compra guardada com fuso** jogaria a compra para o mês seguinte | Alto se acontecer — erra relatório de período e aviso de teto ao mesmo tempo, e em silêncio | Coluna `date` no Postgres e `DateTime` sem hora no Dart. Teste de unidade com compra às 21h do dia 30 (§7.4) | Leandro |
| R9 | **O "hoje" calculado no servidor traz o mesmo bug de volta pela porta dos fundos.** O banco do Supabase roda em **UTC**: às 21h do dia 30 em UTC−4, um `current_date` no SQL devolve **dia 31**. Três regras dependem de "hoje" — o "hoje ou ontem" do aviso de item repetido (requisito 10), a janela rolante de 3 meses com o mês em curso incluído, e o aviso do teto do mês | Alto, e **mais traiçoeiro que R8**: a data gravada estaria certa e ainda assim a comparação erraria, justamente na metade do código que os testes de unidade não cobrem (R7) | **O "hoje" nasce em Dart, no relógio do aparelho, e viaja como parâmetro `date`** (§7.4). Nenhuma consulta, view ou função chama `now()` ou `current_date` para decidir período — é a fronteira do §12.7 aplicada a data, e não a número. Teste de unidade com o relógio em 30/08 às 21h | Leandro |
| R10 | **Entrada de texto do Flutter Web no Safari do iPhone.** Flutter Web desenha os campos em canvas e conversa com o teclado do sistema por uma camada de compatibilidade; no Safari móvel esse é historicamente o ponto mais frágil — teclado cobrindo o campo, foco que escapa ao trocar de campo, cursor fora de lugar, autocorreção intrometida. **É o risco principal do projeto**, porque o requisito 3 é exatamente isto: 20 campos digitados em 2 minutos, no celular | **Alto.** É o mesmo requisito de R1, mas por uma causa que não se resolve cortando campo: se a digitação for ruim, cortar campos só diminui a dor | **Fazer um teste de digitação no iPhone 12 antes de construir qualquer outra tela** — um formulário com os três campos do item (produto, quantidade, valor), teclado numérico incluso, e cronômetro. Isso mede R1 e R10 de uma vez. Se a digitação não servir, a decisão de PWA cai aqui, no primeiro dia, e não no fim do projeto | Leandro |
| R11 | **Em tela cheia no iOS não existe botão Voltar do navegador**, nem gesto de recarregar. O app na tela de início não tem barra nenhuma | Médio — tela sem saída própria prende o usuário, e um erro de carregamento sem como recarregar exige fechar o app pelo multitarefa | Toda tela e todo diálogo precisam de saída própria desenhada. As 6 telas, os 6 diálogos e o painel `#3a` do rascunho já preveem, mas agora é obrigação, não estilo — e vale igual para **as 5 telas que o rascunho não desenhou** (§3), que chegam sem nada desenhado e por isso são as que mais arriscam prender o usuário. Nada de depender do gesto de voltar do sistema | Leandro |
| R12 | **Notch do iPhone 12 e Dynamic Island do 15** no topo da tela em modo tela cheia. O risco real é o **inverso** do que uma versão anterior deste documento supunha: o conteúdo **não** passa por baixo do recorte — sem `viewport-fit=cover`, o iOS confina a página à safe area, e o que aparece é uma faixa no topo com a cor de fundo | Baixo, e cosmético: uma faixa no cabeçalho das telas, não conteúdo escondido | Conferir nos dois aparelhos com o app já na tela de início e **pintar essa faixa** — é o `background_color` do manifest e o fundo do `body` (pendência 4), não `SafeArea`. **A mitigação antiga não funciona:** o Flutter Web em página inteira **remove qualquer `<meta name="viewport">` do `index.html` e injeta o seu**, sem `viewport-fit` (`full_page_embedding_strategy.dart` no SDK, que até loga "This tag will be replaced"), e `SafeArea` no web não recebe inset de recorte. Pintar até a borda exigiria embedding hospedado numa `div` própria mais CSS `env(safe-area-inset-*)` — trabalho que uma faixa colorida não justifica | Leandro |
| R13 | **A base de produção não tem backup.** O plano gratuito do Supabase não faz backup automático, e o histórico de compras é o dado que §1.5 declara insubstituível | Alto se acontecer, **e aceito por escrito** (§1.12) — perder o `prod` é perder o histórico inteiro, sem cupom guardado para reconstruir | Aceitação, não mitigação. As duas barreiras que sobram são indiretas: **`dev` separado do `prod`** (§1.5), que tira a migration errada de perto do dado real, e **nunca editar estrutura pelo painel** (§1.3). Se um dia incomodar, o caminho mais barato é um `pg_dump` agendado no GitHub Actions | Leandro |
| R14 | **Corrigir uma compra não é editar um registro: é refazer o efeito dela sobre a lista.** Os requisitos são explícitos — apagar ou corrigir uma compra deixa a lista *"como estaria se a compra nunca tivesse existido"*, ou como se tivesse nascido já corrigida: os itens voltam, o saldo parcial volta (pediu 6 L, comprou 2, sobram 4), **e a marcação "não encontrei" que aquela compra derrubou volta junto**. Vale para quantidade, item removido, produto trocado, data e mercado | **Alto.** §4.4 só descreveu a ida ("salvar é uma única escrita transacional") e nunca a volta. Sem schema para isso, o desfazer é impossível de acertar depois, e o requisito 12 existe justamente para o erro de digitação não fazer faltar leite em casa | **A compra guarda o que ela mexeu na lista** — para cada item, qual item da lista abateu, quanto abateu e se derrubou um "não encontrei". Correção e exclusão desfazem por esse registro e reaplicam, na mesma transação do §4.4. **Reaplicar não é replay cego:** a data nova volta a passar pela regra do lançamento atrasado (item que entrou na lista depois dela fica de pé — §3), e o total do mês reavalia os dois cortes do teto, limpando a marca do corte que o mês deixou de cruzar (§5). Decidir isso **junto com o schema da compra**, não depois: acrescentar o rastro a compras já lançadas não tem como ser reconstruído | Leandro |
| R15 | **Dinheiro e quantidade em ponto flutuante.** `double` não representa 0,35, e `12 × 0,35` dá 4,199999999999999. Três regras dos requisitos dependem de igualdade e de arredondamento exatos: duas embalagens são a mesma **quando o conteúdo total bate** (`1 × 0,35 L` = `1 × 350 ml`, comparação feita depois da conversão), a porcentagem da calculadora sai **do valor cheio** (R$ 14,3478, não R$ 14,35) e o preço médio é total ÷ quantidade | **Médio, e do tipo que não aparece em teste feliz:** a embalagem duplicada passa pela trava, o "custo praticamente igual" de 1% elege vencedor por ruído, e o centavo do relatório não fecha com o cupom | **`numeric` em toda coluna de dinheiro e de quantidade** no Postgres — nunca `float8`. No Dart, dinheiro e quantidade viajam como `String`/`Decimal`, e a comparação de conteúdo de embalagem é feita em inteiros na menor unidade (mililitro, grama, peça), não em fração. Arredondar **só na formatação**, no `intl` | Leandro |
| R16 | **"Será salva quando o sinal voltar" não roda com o app fechado.** A Tela 3 promete isso na tela e §4.4 assume a promessa, mas o WebKit não tem Background Sync: um PWA no iPhone não executa nada depois de o app sair da tela | Médio — ele toca no botão, guarda o celular achando que resolveu, e a compra só entra na abertura seguinte. Nada se perde (o rascunho está no Hive), mas a expectativa criada pelo texto da tela é maior do que a plataforma entrega | **Tentar na reconexão com o app aberto e na abertura seguinte**, as duas coisas, e **não prometer mais do que isso no texto da faixa**. Se o texto exato dos wireframes incomodar depois de medido no aparelho, é o rascunho de telas que se ajusta — não o contrário | Leandro |

---

## 12. Decisões congeladas

| # | Decisão | Data | Quem decidiu |
|---|---|---|---|
| 1 | **Supabase (Postgres gerenciado)** como base única. Sem backend próprio | 27/08/2026 | Leandro |
| 2 | **PWA em Flutter Web é a única plataforma** da 1ª versão. Sem Android nativo, sem iOS nativo, sem loja | 27/08/2026 | Leandro |
| 3 | **Distribuição por instalação direta**: a URL é aberta no navegador e adicionada à tela de início. Sem conta de loja e sem keystore | 27/08/2026 | Leandro |
| 4 | **Hive (`hive_ce`)** para o rascunho do lançamento e para a etiqueta de quem está usando o aparelho. Nada mais é guardado localmente | 27/08/2026 | Leandro |
| 5 | **Hospedagem no Cloudflare Pages**, com deploy por GitHub Actions | 27/08/2026 | Leandro |
| 6 | **Sem autenticação, com RLS permissiva e chave anônima pública** — a URL não divulgada é a única barreira. Consequência aceita por escrito | 27/08/2026 | Leandro |
| 7 | **Relatórios em modelo misto**: Postgres agrega por período; o `domain` em Dart aplica as regras de negócio. Nenhum limiar numérico dentro do SQL. **A conversão para a unidade base também é do Dart, inclusive na escrita**: os requisitos mandam guardar a medida da peça nas **duas** formas — a digitada ("350 ml") e a convertida (0,35 L) —, então o valor convertido é **persistido**, e quem o calcula antes de gravar é o `domain`. Nenhuma conversão de grandeza no SQL | 27/08/2026 | Leandro |
| 8 | **MVVM oficial do Flutter (`ui`/`data`/`domain`), Riverpod 3 escrito à mão, sem codegen** | 27/08/2026 | Leandro |
| 9 | **Dois projetos Supabase, `dev` e `prod`** — base única foi descartada para não arriscar histórico real numa migration | 27/08/2026 | Leandro |
| 10 | **Safari no iOS é o único navegador-alvo.** Os dois aparelhos são iPhone (12 e 15); Android sai do alvo de teste | 27/08/2026 | Leandro |
| 11 | **Instalar na tela de início é obrigatório**, não conveniência: é o que tira o app da contagem de 7 dias do Safari e lhe dá armazenamento próprio (R5) | 27/08/2026 | Leandro |
| 12 | **Sem observabilidade em produção na 1ª versão** — sem analytics, sem crash reporting, sem log remoto. `debugPrint` em desenvolvimento e nada mais | 27/08/2026 | Leandro |
| 13 | **A data da compra é `date` sem fuso, e o "hoje" é calculado em Dart, no aparelho.** Nenhuma consulta chama `now()` nem `current_date` para decidir período (R8 e R9) | 27/08/2026 | Leandro |
| 14 | **O teto mora no Postgres, em duas tabelas** (§5): `teto` com uma linha por **alteração** (`vigente_desde`), porque o teto atravessa meses sozinho; e `aviso_teto` com uma linha por **mês**, para as marcas de 80% e 100%. Salvar teto novo apaga a linha de avisos do mês corrente e reavalia na hora, na mesma transação | 27/08/2026 | Leandro |
| 15 | **A base de produção não tem backup, e a perda é aceita por escrito** (§1.12, R13). O plano gratuito não faz backup automático, e não haverá rotina própria na 1ª versão | 27/08/2026 | Leandro |
| 16 | **Desktop e tablet estão fora do alvo.** Só celular, e o layout é desenhado em retrato; o "Desejável 1" (relatórios no computador) continua adiado, como os requisitos já dizem em *Limites*. Paisagem tem regra própria — decisão 21 | 27/08/2026 | Leandro |
| 17 | **O seed de teste é versionado em `supabase/seed.sql`** e aplicado só no `dev`, no mesmo regime do schema (§1.3, §8.5) | 27/08/2026 | Leandro |
| 18 | **O app tem 11 telas, não 6.** As 6 do rascunho mais as 4 que os wireframes declararam fora dele (histórico, correção de compra, manutenção do cadastro, configurações) e a de primeira abertura. Todas atendem requisitos essenciais (§3) | 27/08/2026 | Leandro |
| 19 | **Soft delete e referência por chave nos seis cadastros** — categoria, tipo, marca, produto, embalagem e mercado têm `ativo`, e a compra nunca copia o nome. É o que faz renomear valer para todo o histórico e desativar ter volta (requisito 16, §3) | 27/08/2026 | Leandro |
| 20 | **A compra guarda o rastro do que mexeu na lista**, para corrigir e apagar refazerem o efeito dela — itens, saldo parcial e a marcação "não encontrei" (requisito 12, R14) | 27/08/2026 | Leandro |
| 21 | **Paisagem não é evitável no iPhone e fica torta, sem teste.** O `orientation` do manifest é ignorado pelo Safari e não há `lock()`; travar em retrato, se um dia precisar, é no Dart (§7.2) | 27/08/2026 | Leandro |
| 22 | **O rascunho mandado salvar sem sinal é reenviado sozinho** — um por aparelho, nunca uma fila —, com o app aberto ou na abertura seguinte. É o que a Tela 3 promete na tela, e a 1.3 deste documento negava (§4.4, R16) | 27/08/2026 | Leandro |
| 23 | **"Produto" são dois níveis no schema:** o **cadastro** (tipo + marca + descrição), onde mora a trava de duplicidade, e a **folha** (cadastro + embalagem), que tem preço, histórico e é o que a compra aponta. Os dois têm `ativo` próprio; o vendido a peso não tem folha de embalagem (§3) | 27/08/2026 | Leandro |
| 24 | **`numeric` no Postgres e decimal no Dart** para todo dinheiro e toda quantidade. Nada de `double`: conteúdo de embalagem é comparado em inteiros na menor unidade, e o arredondamento acontece só na formatação (R15) | 27/08/2026 | Leandro |
| 26 | **A unidade base É a menor unidade, e são quatro**: grama, mililitro, unidade e centímetro. Uma medida por grandeza — não existe escolher entre "g" e "kg" na tela —, toda quantidade digitada e gravada em inteiro nela, e a unidade grande (kg, L, un, m) reservada ao preço e à leitura. Amplia a decisão 24 e a B5, que diziam "inteiro na menor unidade **da** base"; acrescenta a grandeza **Tamanho** | 07/09/2026 | Leandro |
| 25 | **O item da lista guarda a data em que entrou nela**, e é ela que decide se um lançamento atrasado o abate. Corrigir a data de uma compra refaz essa comparação (§3, R14) | 27/08/2026 | Leandro |

---

## 13. Pendências que bloqueiam o início

| # | Pendência | Responsável | Prazo | Status |
|---|---|---|---|---|
| 1 | Criar os projetos Supabase `dev` e `prod`; anotar URL e chave anônima de cada um (itens 1.5 e 1.6 ⛔) | Leandro | Antes da 1ª linha de código | Aberta |
| 2 | **Teste de digitação no iPhone 12 antes de construir as telas** — três campos e cronômetro, para medir R1 e R10 juntos. É o que decide se o PWA se sustenta | Leandro | Antes da 1ª tela de verdade | Aberta |
| 3 | Criar o projeto no Cloudflare Pages e definir o subdomínio — não adivinhável, conforme §9 (item 6.2 ⛔) | Leandro | Antes do 1º deploy | Aberta |
| 4 | Preencher o `web/manifest.json` (`name`, `short_name`, `description`, `background_color`, `theme_color`) e os campos de template do `index.html` (`<title>`, `<meta name="description">`, `apple-mobile-web-app-title`) — item 6.4. O `background_color` é também a cor da faixa do recorte (R12). **Trocar também os quatro PNG de `web/icons/`** — hoje são os do template, e é esse ícone que fica na tela de início dos dois aparelhos, que a decisão 11 tornou obrigatória | Leandro | Antes do 1º deploy | Aberta |
| 5 | Acrescentar ao `index.html` o `<meta name="apple-mobile-web-app-capable" content="yes">`, que o template do Flutter 3.44 não traz — é o que garante tela cheia no iOS e, com ela, o armazenamento próprio da decisão 11 (§6.6.1, R5) | Leandro | Antes do 1º deploy | Aberta |
| 6 | Criar `web/robots.txt` bloqueando indexação e acrescentar `<meta name="robots" content="noindex">` ao `index.html` — as duas mitigações que §9 prometeu e nenhuma outra pendência cobria | Leandro | Antes do 1º deploy | Aberta |

**Fechada:** ~~confirmar se algum dos dois celulares é iPhone~~ — resolvida em
27/08/2026 (iPhone 12 e iPhone 15). Consequências aplicadas em §6.6.1, §7.1, §7.6
e nos riscos R5, R10, R11 e R12.

---

## O que vem depois deste documento

Com as pendências acima zeradas, o próximo passo é o **handoff** — as histórias
implementáveis, cruzando os 18 requisitos aprovados com as decisões técnicas daqui.
Ele só se justifica se outra pessoa for codar ou se as tarefas forem para um board;
com um desenvolvedor só, o documento de requisitos aprovado já basta, e o handoff
vira burocracia.
