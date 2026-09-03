---
name: business-rules
description: As regras do negócio que o código tem de honrar — dinheiro sem double, sem now() no domínio, soft delete, duplicidade normalizada
quando-ler: ao mexer em dinheiro, quantidade, data, cadastro dos seis, ou em qualquer SQL
---

# Regras do projeto que o código ainda vai ter de honrar

Não são da arquitetura, são do negócio — e cada uma já derrubou uma versão de documento:

- **Dinheiro e quantidade nunca são `double`.** `numeric` no Postgres, decimal no Dart.
  Conteúdo de embalagem comparado em **inteiros na menor unidade**; arredondar só na
  formatação (decisão 24, `R15`).
- **`DateTime.now()` não desce para o domínio nem para o widget.** A data da compra é
  `date` sem fuso; o "hoje" nasce no ViewModel, no relógio do aparelho, e viaja como
  parâmetro (decisão 13). **Nenhum `now()` ou `current_date` no SQL** (decisão 7).
- **Nenhum limiar numérico no SQL.** O Postgres soma e agrupa; toda regra é Dart.
- **Soft delete nos seis cadastros** (categoria, tipo, marca, produto, embalagem,
  mercado): renomear vale para todo o histórico, e a compra aponta por chave, nunca
  copia o nome. Nenhum `DELETE` neles.
- **A trava de duplicidade compara normalizado** — sem maiúsculas, sem espaço sobrando,
  sem acento — e **quem responde ao usuário é o Dart**; o índice único é a rede embaixo.
- **O item da lista guarda a data em que entrou**, e só sai da lista se entrou antes ou
  no mesmo dia da compra lançada.
- **A lista nunca se mexe debaixo do dedo**: o que chega do outro celular entra por uma
  faixa de aviso, e é o toque dela que refaz a tela.
- **Teste sempre no PWA instalado na tela de início**, nunca em aba: o armazenamento é
  separado, e o deploy só passa a valer na abertura seguinte do app.
