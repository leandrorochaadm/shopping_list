---
name: ui-conventions
description: O alvo é um PWA em iPhone 12, campo de digitação no topo, SnackBar e contexto, listas roláveis em todos os estados, e a régua dos textos de tela em pt-BR
quando-ler: ao escrever qualquer widget que tenha campo digitável, mostre SnackBar, lista com pull-to-refresh ou texto para o usuário
---

# Convenções de tela

## Onde este app roda

É um **PWA**, instalado na tela de início de **dois iPhones** — não é desktop, não é
tablet, e não é aba de navegador. A régua é o **iPhone 12: 390 × 844 pontos**, e toda
tela é desenhada e conferida nessa medida. O que só cabe num monitor não cabe aqui.

## Campo de digitação fica no topo

**Todo campo digitável fica no topo**, antes de lista, resumo, total ou botão. O diálogo
entra na mesma regra: o teclado cobre um diálogo do mesmo jeito que cobre uma tela.

O motivo: numa altura de 844 pontos, o teclado do iPhone leva perto da metade, e o campo
que estava no meio da tela vai parar embaixo dele. **`padding` não resolve isso** —
padding acomoda o conteúdo dentro do espaço que ainda existe, e o problema é justamente
que o espaço deixou de existir. Quem resolve é a **ordem** dos elementos: o que se digita
vem primeiro, o que se lê vem depois e pode rolar.

Conferir sempre com o teclado **aberto** — no aparelho, com o PWA instalado, como
`.claude/rules/business-rules.md` já manda; teclado fechado no navegador do computador
não mostra o problema.

### As duas exceções, e o que cada uma exige em troca

1. **Campo dentro de linha repetível** — as embalagens da Tela 4, as linhas do painel
   `#3a`. Não existe topo para ele: o campo é um por linha de uma lista. O que a regra
   exige em troca é que **a área que rola termine onde o teclado começa** — no `#3a` é o
   `padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)` do painel,
   e é ele que o teste `with the keyboard up no line falls under it` protege. Dentro do
   bloco, o que se **digita** continua vindo antes do que já está gravado.
2. **A frase que EXPLICA o campo vazio** fica acima dele, não abaixo. A seção do teto de
   gasto é o caso: sem teto definido ela diz *"Nenhum teto definido. O relatório do mês
   não mostra a linha…"*, e explicação abaixo do campo que ela explica é legenda órfã. A
   exceção só vale onde o campo **não chega perto da dobra do teclado** — ali a seção é a
   última de uma tela que rola, e o campo sobe sozinho ao ganhar foco.

## SnackBar e contexto

`ScaffoldMessenger.of(context)` precisa de um context **abaixo** do `Scaffold` —
usar `Builder` no `body`. E capturar o messenger **antes** do `await`.

## Listas na tela

`RefreshIndicator` exige filho rolável **em todos os estados**. Usar
`physics: AlwaysScrollableScrollPhysics()` no `ListView` e `MessageView` (rolável)
para vazio e erro — `Center` puro quebra o pull-to-refresh.

## Textos de tela

O único conteúdo em português do código. Escrever em português correto para **esta**
entidade: artigo e plural não saem de substituição mecânica. "Nenhuma reserva", não
"Nenhum reserva"; "Animais", não "Animals". O identificador do widget que mostra o texto
continua em inglês (`MessageView`, `emptyLabel`).

**Mandatório:** todo texto de tela é **português do Brasil**, em **linguagem simples e
direta**, escrita para o **usuário leigo** — o casal que usa o app, não um desenvolvedor.
Nada de termo técnico (`token`, `cache`, `payload`, `sincronizar`, `endpoint`), nada de
inglês solto, nada de frase longa ou construção rebuscada. Título, botão, estado vazio e
mensagem de erro traduzida seguem esta regra sem exceção — inclusive as que hoje já
existem: revisar ao tocar na tela.
