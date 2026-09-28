**Cadastro base de produtos de supermercado**

Produtos genéricos, sem marca, na estrutura do app. Escopo: mercado completo, exceto
bazar/utilidades e bebidas alcoólicas.

## Como ler e editar

- `## Categoria` — a categoria do app ("Frutas", "Carne bovina", "Limpeza").
- `### Tipo (unidade)` — o tipo do app, o nível que **soma** nos relatórios. A unidade
  é do tipo e vale para tudo abaixo dele: `g`, `ml`, `un` ou `cm`.
- `- descrição` — cada linha é um cadastro (tipo + descrição). Tipo sem nenhuma linha
  abaixo é um cadastro só, com a descrição vazia.

Regras que o app cobra, e que este arquivo precisa respeitar:

- **Nome de categoria não repete, e nome de tipo não repete no catálogo inteiro** — nem
  entre categorias diferentes. A comparação ignora maiúscula, acento e espaço sobrando.
- **Um tipo tem uma unidade só.** Se dois produtos não somam na mesma unidade (creme
  dental em g e escova em un), são dois tipos.
- **Marca, embalagem e o campo Vendido** (solto ou em embalagem) não estão aqui: são
  escolhidos no cadastro real, no app.

---

## Frutas

### Banana (g)

- maçã

### Maçã (g)

- gala

### Laranja (g)

- pera

### Mamão (g)

- formosa
- papaya

### Abacaxi (un)

- pérola

### Melancia (g)

### Uva (g)

- itália

### Limão (g)

- taiti

### Manga (g)

- tommy

### Abacate (g)

### Açaí (g)

### Polpa de fruta (g)

- de maracujá

## Legumes e verduras

### Tomate (g)

- italiano

### Cebola (g)

- branca
- roxa

### Cenoura (g)

### Chuchu (g)

### Abobrinha (g)

- d'água

### Abóbora (g)

- cabotiá

### Pimentão (g)

- verde

### Pepino (g)

- japonês

### Vagem (g)

### Alface (un)

- crespa

### Couve (un)

- manteiga

### Rúcula (un)

### Repolho (g)

- verde

### Brócolis (g)

- ninja
- congelado

### Espinafre (un)

### Batata (g)

- inglesa

### Batata-doce (g)

### Mandioca (g)

- descascada

### Alho (g)

### Cheiro-verde (un)

### Batata pré-frita (g)

### Seleta de legumes (g)

## Carne bovina

### Músculo (g)

### Acém (g)

### Patinho (g)

### Coxão mole (g)

### Alcatra (g)

### Picanha (g)

### Costela bovina (g)

### Carne moída (g)

- de segunda

### Fígado (g)

- bovino

### Hambúrguer (g)

- bovino

## Carne suína

### Pernil (g)

### Costelinha suína (g)

### Lombo (g)

### Bisteca (g)

### Linguiça (g)

- toscana
- calabresa

## Carne de ave

### Frango inteiro (g)

- congelado

### Peito de frango (g)

- com osso
- filé

### Coxa e sobrecoxa (g)

### Asa de frango (g)

### Coração de frango (g)

### Linguiça de frango (g)

### Nugget (g)

- de frango

### Ovo (un)

- branco

## Carne de peixe

### Tilápia (g)

- filé

### Salmão (g)

- posta

### Tambaqui (g)

### Pintado (g)

- posta

### Merluza (g)

- filé

### Sardinha (g)

- inteira

### Bacalhau (g)

- dessalgado

### Camarão (g)

- cinza limpo

### Lula (g)

- em anéis

### Mexilhão (g)

### Peixe empanado (g)

- filé

## Padaria

### Pão francês (g)

### Pão de forma (g)

- tradicional
- integral

### Bisnaguinha (g)

### Pão doce (un)

### Bolo (g)

- de fubá
- de chocolate

### Pudim (g)

- de leite

### Esfiha (un)

- de carne

### Empada (un)

- de frango

### Torta salgada (g)

- de palmito

### Coxinha (un)

- de frango
- congelada

### Pastel (un)

- de queijo

### Pão de queijo (g)

### Pizza (g)

## Frios, laticínios

### Mussarela (g)

- fatiada

### Queijo prato (g)

- fatiado

### Parmesão (g)

- ralado

### Queijo minas (g)

- frescal

### Queijo coalho (g)

### Provolone (g)

### Cheddar (g)

- fatiado

### Requeijão (g)

- cremoso

### Cream cheese (g)

### Presunto (g)

- cozido fatiado

### Apresuntado (g)

### Mortadela (g)

- fatiada

### Salame (g)

- italiano

### Peito de peru (g)

- defumado

### Bacon (g)

- em cubos

### Salsicha (g)

### Iogurte (g)

- natural integral
- grego

### Bebida láctea (ml)

- de morango

### Petit suisse (g)

### Manteiga (g)

- com sal

### Margarina (g)

- cremosa

### Leite (ml)

- longa vida integral
- longa vida desnatado
- pasteurizado integral

### Leite em pó (g)

- integral

### Bebida vegetal (ml)

- de amêndoas

### Leite condensado (g)

### Creme de leite (g)

- UHT


## Grãos e massas

### Arroz (g)

- branco tipo 1
- parboilizado
- integral

### Feijão (g)

- carioca
- preto

### Lentilha (g)

### Grão-de-bico (g)

### Milho de pipoca (g)

### Aveia (g)

- em flocos

### Macarrão (g)

- espaguete
- parafuso
- penne integral
- de arroz

### Massa de lasanha (g)

- seca
- fresca

### Macarrão instantâneo (g)

### Massa de pastel (g)

### Nhoque (g)

- fresco

### Massa folhada (g)

### Lasanha (g)

## Farinhas e confeitaria

### Farinha de trigo (g)

### Farinha de mandioca (g)

### Fubá (g)

### Farinha de rosca (g)

### Amido de milho (g)

### Fermento químico (g)

- em pó

### Açúcar (g)

- refinado
- mascavo

### Coco ralado (g)

### Mistura para bolo (g)

### Granulado (g)

- de chocolate

### Chantilly (g)

- em pó

### Chocolate em pó (g)

- 50% cacau

## Óleos, temperos e molhos

### Óleo (ml)

- de soja
- de girassol

### Azeite (ml)

- extra virgem

### Banha de porco (g)

### Sal (g)

- refinado
- grosso

### Vinagre (ml)

- de álcool
- de maça

### Pimenta-do-reino (g)

- moída

### Colorau (g)

### Cominho (g)

- em pó

### Tempero completo (g)

### Caldo (g)

- de galinha

### Orégano (g)

### Louro (g)

- em folha

### Extrato de tomate (g)

### Polpa de tomate (g)

### Molho de tomate (g)

### Tomate pelado (g)

### Maionese (g)

### Ketchup (g)

### Mostarda (g)

### Shoyu (ml)

### Molho de pimenta (ml)

## Enlatados e instantâneos

### Milho verde (g)

### Ervilha (g)

### Sardinha em lata (g)

- em óleo
- em molho tomate

### Atum (g)

- ralado em óleo

### Azeitona (g)

- verde sem caroço

### Palmito (g)

- pupunha

### Sopa (g)

- instantânea

### Purê de batata (g)

- instantâneo

### Escondidinho (g)

## Matinais

### Café (g)

- torrado e moído
- solúvel
- em grãos

### Achocolatado (g)

- em pó

### Granola (g)

### Flocos de milho (g)

- cuscuz

### Geleia (g)

- de morango

### Creme de avelã (g)

### Mel (g)

## Biscoitos e snacks

### Biscoito recheado (g)

- de chocolate

### Biscoito maisena (g)

### Rosquinha (g)

- de coco
- de leite
- de banana c/ canela

### Wafer (g)

- de chocolate

### Biscoito (g)
- Cream cracker 
- água e sal

### Torrada (g)

- tradicional
- integral

### Biscoito de polvilho (g)

### Salgadinho (g)

- de milho
- de trigo

### Batata frita de pacote (g)

### Pipoca de micro-ondas (g)

### Amendoim (g)

- torrado

### Castanha de caju (g)

### Castanha-do-pará (g)

### Barra de cereal (g)

## Doces e sobremesas

### Chocolate (g)

- ao leite

### Bombom (g)

- sortido

### Bala de goma (g)

### Chiclete (g)

### Pirulito (un)

### Gelatina (g)

### Pudim em pó (g)

### Goiabada (g)

### Doce de leite (g)

### Sorvete (ml)

- de creme

### Picolé (un)

- de fruta

## Bebidas

### Refrigerante (ml)

- de cola
- de guaraná

### Água tônica (ml)

### Suco (ml)

- de laranja integral
- néctar de uva
- concentrado de maracujá

### Suco em pó (g)

- sabor limão

### Xarope de groselha (ml)

### Água mineral (ml)

- sem gás
- com gás

### Água de coco (ml)

### Energético (ml)

- tradicional

### Isotônico (ml)

- sabor limão

### Chá mate (ml)

- gelado

### Chá em sachê (un)

- de camomila

## Higiene e beleza

### Creme dental (g)

### Escova de dente (un)

### Fio dental (cm)

### Enxaguante bucal (ml)

### Sabonete em barra (g)

### Sabonete líquido (ml)

- adulto
- infantil

### Esponja de banho (un)

### Shampoo (ml)

- adulto
- infantil

### Condicionador (ml)

### Creme de pentear (g)

### Tintura de cabelo (un)

### Desodorante (ml)

- aerossol
- roll-on

### Absorvente (un)

- com abas
- protetor diário

### Hidratante corporal (ml)

### Protetor solar (ml)

### Álcool em gel (ml)

- 70%

### Aparelho de barbear (un)

- descartável

### Espuma de barbear (ml)

### Papel higiênico (cm)

- folha dupla

### Lenço de papel (un)

## Limpeza

### Sabão em pó (g)

### Sabão líquido (ml)

### Amaciante (ml)

- concentrado

### Alvejante (ml)

- sem cloro

### Sabão em barra (g)

### Detergente (ml)

- neutro

### Esponja de louça (un)

- dupla face

### Palha de aço (un)

### Desinfetante (ml)

### Água sanitária (ml)

### Limpador multiuso (ml)

### Limpa-vidros (ml)

### Lustra-móveis (ml)

### Inseticida (ml)

- aerossol

### Limpador de vaso sanitário (ml)

### Pedra sanitária (un)

### Papel toalha (cm)

### Saco de lixo (un)

- 30 litros

### Papel alumínio (cm)

### Filme plástico (cm)

## Infantil

### Fralda (un)

- descartável tamanho M

### Lenço umedecido (un)

### Pomada para assadura (g)

### Fórmula infantil (g)

- em pó

### Papinha (g)

- de fruta

### Cereal infantil (g)

## Pet

### Ração (g)

- seca para cães adultos
- seca para gatos
- úmida para cães

### Petisco (un)

- mastigável para cães

### Areia sanitária (g)

- para gatos

### Tapete higiênico (un)

---

# Decisões de classificação

Estes itens não têm resposta única. Foi escolhido um critério e mantido:

- **Categoria larga, do tamanho de um corredor de mercado.** São 20. O detalhe fino
  (pão × salgado, queijo × frios) já aparece no relatório pelo **tipo**, que é o nível
  que soma. A exceção são as carnes, separadas por bicho, sempre com o prefixo "Carne":
  bovina, suína, de ave e de peixe. Frutos do mar entram em Carne de peixe.
- **Mesmo produto em dois lugares vira um tipo só**, na categoria principal, com a
  variação na descrição: brócolis congelado fica em Legumes e verduras, coxinha
  congelada em Padaria, massa de lasanha fresca em Grãos e massas, shampoo e sabonete
  infantis em Higiene e beleza, os três leites em um tipo só. A soma do relatório junta
  as variações.
- **Brócolis ficou em `g`**, e não em `un`: o congelado só se compra por peso, e um tipo
  tem uma unidade só.
- **Produto processado é outro tipo**, porque não é o mesmo produto: `Sardinha` e
  `Sardinha em lata`, `Pudim` e `Pudim em pó`, `Batata` e `Batata pré-frita`.
- **Miúdos vão para o bicho de origem**: fígado bovino em Carne bovina, coração de
  frango em Carne de ave.
- **Linguiça de frango** é um tipo próprio, em Carne de ave. A `Linguiça` sem
  complemento, em Carne suína, é a de porco.
- **Todo leite, iogurte e manteiga** ficou em Frios, laticínios — de geladeira ou
  de prateleira. Leite condensado e creme de leite também. **O ovo ficou em Carne de
  ave**, junto do bicho de origem.
- **Salgadinho** é um tipo só, com o sabor da massa na descrição (de milho, de
  trigo).
- **Bebida vegetal** ficou junto do leite, por ser substituta dele.
- **Massa fresca** (massa de pastel, nhoque) ficou em Grãos e massas, não em Frios.
- **Óleo, azeite, tempero, derivado de tomate e molho pronto** ficaram numa categoria só.
  O caldo de galinha entrou aqui, como tempero.
- **Sopa e purê instantâneos** ficaram em Enlatados e instantâneos; o macarrão
  instantâneo, em Grãos e massas, junto do macarrão.
- **Café** ficou em Matinais; **chá em sachê**, em Bebidas.
- **Castanhas e barra de cereal** ficaram em Biscoitos e snacks.
- **Chocolate em pó** ficou em Farinhas e confeitaria, e não em Doces: é ingrediente
  de receita, como o granulado.
- **Abóbora e abobrinha** são dois tipos: cabotiá é abóbora, não abobrinha, e as duas
  não se substituem na receita.
- **Não existe categoria Congelados.** Congelado é jeito de conservar, não tipo de
  produto: cada item foi para a categoria do que ele é. Hambúrguer em Carne bovina,
  nugget em Carne de ave, peixe empanado em Carne de peixe, pizza e pão de queijo em
  Padaria, lasanha pronta e massa folhada em Grãos e massas, batata pré-frita e seleta
  em Legumes e verduras, açaí e polpa em Frutas, sorvete e picolé em Doces e sobremesas.
- **Escondidinho** ficou em Enlatados e instantâneos, junto dos outros preparos rápidos:
  é prato pronto, e o recheio varia.
- **Papel higiênico** ficou em Higiene e beleza; **papel alumínio, filme plástico, papel
  toalha e saco de lixo**, em Limpeza. Alguns mercados tratam estes como bazar.
- **Sardinha e atum enlatados** ficaram em Enlatados e instantâneos, não em Carne de peixe.
- **Vendidos por metro** (papel higiênico, papel toalha, papel alumínio, filme plástico,
  fio dental) usam `cm`, para comparar rolos de tamanhos diferentes pelo custo por metro.
