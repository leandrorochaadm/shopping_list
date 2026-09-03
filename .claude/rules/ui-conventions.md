---
name: ui-conventions
description: SnackBar e contexto, listas roláveis em todos os estados, e a régua dos textos de tela em pt-BR
quando-ler: ao escrever qualquer widget que mostre SnackBar, lista com pull-to-refresh ou texto para o usuário
---

# Convenções de tela

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
