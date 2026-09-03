---
name: routes
description: As 11 rotas nomeadas, quem usa go, push ou pushNamed, e por quê
quando-ler: ao acrescentar rota, mudar navegação ou passar extra entre telas
---

# Rotas — `routing/routes.dart`

São **11 telas** (`tecnico §3.4`), não as 6 do rascunho, e **desde a Entrega 8 todas as
onze têm tela**. Até ali a que ainda não tinha apontava para uma `UnderConstructionScreen`
que dizia qual história a entregava, e cada história trocava uma entrada do router pela
tela real. Aquela tela e o `pendingDestinations` ao lado dela foram apagados com as duas
últimas entradas.

`/suggestions` é a Tela 2 e a Tela 1 a abre com **`push`**: as rotas são planas, e o
wireframe manda a Tela 2 **voltar** para a lista — tanto pelo Voltar quanto pelo
`[ Adicionar selecionados ]`. `/remaining` é a Tela 6 e é o **terceiro destino
permanente** da barra de baixo, alcançado com `go` e sem Voltar nenhum, pelo mesmo motivo
de `/` e `/reports`.

`/` é a Tela 1. `/purchases/new` é a Tela 3, e é declarada **antes** de
`/purchases/:id/edit`: o `go_router` casa na ordem, e senão `new` viraria um id.

`/products/new` é a única rota que lê `state.extra`, e desde a H10 ele é um
**`NewProductRequest`**, não um `bool`: a Tela 3 a abre com
`extra: const NewProductRequest(returnsSelection: true)` para pedir a folha escolhida **de
volta**, e a manutenção do cadastro a abre com `registrationId` para dizer **qual**
cadastro carregar. Quem chega pelo menu não passa nada e cai no `const
NewProductRequest()`. **`push`, nunca `go`:** `go` trocaria a rota e levaria embora a Tela
3 com a compra digitada nela.

`/purchases` abre a correção com `pushNamed`, pelo mesmo motivo escrito ao contrário: as
rotas são **planas**, sem `routes:` aninhado, então o `go_router` não monta pilha a partir
do path — um `go` deixaria `canPop()` falso e a correção abriria com o ícone de casa em
vez do Voltar, perdendo o histórico de onde a pessoa veio.

`/reports` é o contrário dos dois acima: ela **não carrega Voltar nenhum**, nem empilhada.
É um dos **três destinos permanentes** da barra de baixo, e a nota do wireframe é
explícita — "alternar entre eles não é voltar". A Tela 1 já era assim; a Tela 5 é a
segunda, e `router_test` tem um caso para cada uma, para a próxima tela com barra não
nascer com um botão que navega para ela mesma.

**Nenhuma rota é protegida** — não há sessão. O único `redirect` do app nasce na **H1**:
enquanto a etiqueta de `deviceUser` não estiver no Hive, toda rota cai em `/welcome`.
