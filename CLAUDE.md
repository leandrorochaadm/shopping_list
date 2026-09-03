# Lista de compras de supermercado

PWA em Flutter Web para **dois iPhones**, sem login, com base única no Supabase.
Casal que quer saber quanto gasta em quê, não esquecer item e não pagar caro.

**As fontes da verdade estão em `docs/`, nesta ordem de precedência:**

1. `docs/requisitos-lista-de-compras.md` — 18 requisitos essenciais, é o que o cliente lê
2. `docs/tecnico-lista-de-compras.md` — questionário técnico, **decisões 1 a 25 congeladas**
3. `docs/wireframes-lista-de-compras.md` — 6 telas + 6 diálogos + painel `#3a`
4. `docs/handoff-lista-de-compras.md` — 19 histórias (H1–H19), ordem de entrega, glossário

Onde este arquivo, `.claude/rules/` ou `docs/estado-atual.md` divergirem dos três
primeiros, **são eles que valem**. Mudar qualquer linha de `tecnico §12` (decisões
congeladas) é **alteração de escopo** — pergunte antes.

Cliente, desenvolvedor e homologador são a mesma pessoa. Sem QA, sem board, sem prazo.

A arquitetura é o **MVVM do guia oficial do Flutter**, com Riverpod 3 escrito à mão, sem
codegen. As regras moram em `.claude/rules/`, um arquivo por assunto. As quatro abaixo
entram sempre; as outras doze são **leitura obrigatória sob demanda** — o índice diz
quando cada uma vale, e "não abri o arquivo" não é desculpa para quebrar o que ele diz.

---

@.claude/rules/language.md
@.claude/rules/layers.md
@.claude/rules/inviolable-rules.md
@.claude/rules/errors.md

---

# Índice das regras — leia o arquivo ANTES de mexer no assunto

| Arquivo | Leia quando |
|---|---|
| `.claude/rules/stack.md` | antes de acrescentar qualquer dependência ao `pubspec` |
| `.claude/rules/glossary.md` | **obrigatório** antes de traduzir qualquer termo novo de negócio — e acrescente o termo depois de escolher |
| `.claude/rules/equality-chain.md` | ao escrever `==`/`hashCode` de uma entidade, ou ao cogitar `freezed`/`equatable` |
| `.claude/rules/new-feature-checklist.md` | ao começar uma feature, tela ou CRUD novo |
| `.claude/rules/riverpod-3.md` | ao criar ou editar qualquer `Notifier`, `AsyncNotifier` ou `Provider` |
| `.claude/rules/routes.md` | ao acrescentar rota, mudar navegação ou passar `extra` entre telas |
| `.claude/rules/ui-conventions.md` | ao escrever widget com SnackBar, lista com pull-to-refresh ou texto de tela |
| `.claude/rules/business-rules.md` | ao mexer em dinheiro, quantidade, data, cadastro dos seis, ou em qualquer SQL |
| `.claude/rules/supabase-error.md` | ao escrever ou editar qualquer método de um repository `_remote` |
| `.claude/rules/testing.md` | **SEMPRE** antes de rodar `flutter test` ou `flutter analyze` — a suíte inteira só a pedido |
| `.claude/rules/do-not-without-asking.md` | antes de introduzir qualquer padrão, pacote ou abstração que ainda não esteja no projeto |
| `.claude/rules/observability.md` | só se existir `lib/data/services/observability/` |

# Onde foi parar o resto

O que era história do projeto, e não regra, mudou para `docs/`:

| Arquivo | O que é |
|---|---|
| `docs/estado-atual.md` | **o que existe hoje**, história por história, mais o ambiente, o deploy e as migrations. **Atualizar a cada entrega** |
| `docs/decisoes-divergencias.md` | as ~50 decisões A–I já em vigor no código. **Não reabrir sem o usuário pedir** |
| `docs/historico-entregas.md` | o que cada entrega mudou fora das telas dela, e as armadilhas que cada uma revelou |

Antes de planejar qualquer coisa, leia `docs/estado-atual.md` — é ele que diz o que já
está pronto. Antes de discordar de algo que o código faz, leia
`docs/decisoes-divergencias.md` — a chance de já ter sido decidido é alta.
