---
name: testing
description: O que testar, e como rodar teste, analyze e cobertura sempre no escopo mínimo
quando-ler: SEMPRE antes de rodar flutter test ou flutter analyze — nunca rodar a suíte inteira sem pedir
---

# Testes

- Regra de negócio: teste puro em `test/domain/`, incluindo os **limites**
  (exatamente no prazo, exatamente encostado) e a transição de status.
- Nomes de teste, helpers e classes espiãs em inglês:
  `test('allows canceling more than 24h ahead', ...)`.
- ViewModel: espião herdando do `_local` com `failNextCall`, sem mocktail.
  Cobrir os dois caminhos de erro (**com** e **sem** dado anterior), o `refresh()` que dá
  **certo**, e a classificação de cada status em `AppFailure` — sem esses três, o alvo
  de 85% não fecha. Mais o toque duplo e o desembrulho de `ProviderException`: os dois
  precisam **falhar** se a guarda ou o laço forem removidos.
- Domínio: **toda** transição de status tem teste, mesmo a que a tela ainda não chama,
  mais o `toString()` das exceções de regra. É o que falta para os 95%.
- Teste de widget que renderize data ou moeda precisa de
  `setUpAll(() => initializeDateFormatting('pt_BR'))` — `main()` não roda em teste.
- Usar `ProviderContainer.test(...)`, não `ProviderContainer()` + `addTearDown`.
- Nunca `DateTime.now()` em teste: instante fixo sempre.

## Como rodar os testes — escopo mínimo, sempre

**Nunca rodar `flutter test` sem caminho.** A suíte inteira leva minutos e enche o
contexto com centenas de linhas que não têm relação com o que está sendo editado.
Rodar **só o arquivo ou a pasta que está sendo mexida**:

```bash
flutter test test/domain/purchase_test.dart          # um arquivo
flutter test test/ui/edit_purchase_screen_test.dart  # um arquivo
flutter test test/domain/                            # uma pasta, quando mexi em várias
flutter test test/ui/catalog_view_model_test.dart --name 'guards against double tap'
```

**`--name` não tem abreviação `-n`** neste Flutter — `flutter test --help` só lista
`--name=<regexp>`, e o `-n` é engolido como caminho.

**Achar o teste do arquivo editado é palpite mais confirmação, não tabela.** O palpite é o
basename (`purchase.dart` → `purchase_test.dart`, `new_product_screen.dart` →
`new_product_screen_test.dart`), e ele acerta na maioria — mas **erra na família do
catálogo**, onde `category.dart`, `brand.dart`, `product_type.dart` e `catalog_entry.dart`
são cobertos por um `test/domain/catalog_test.dart` só. Então confirme antes de rodar:

```bash
find test -name 'purchase_test.dart'   # o palpite existe?
grep -rl 'PurchaseItem' test/          # quem mais toca o que editei
```

O `grep` pelo símbolo é o que vale quando o palpite falha, quando o arquivo é um helper de
`test/helpers/`, ou quando a entidade é montada por várias telas. Para rodar todos de uma
vez, **`xargs -r`** — sem o `-r`, um grep que não acha nada chama `flutter test` sem
argumento nenhum e dispara justamente a suíte inteira que esta seção proíbe:

```bash
grep -rl 'PurchaseItem' test/ | xargs -r flutter test
```

**O mesmo vale para o `flutter analyze`**, que aceita arquivo solto (0,2s de análise,
~3s de relógio com o `pub get` na frente):
`flutter analyze lib/domain/models/purchase.dart` ou `flutter analyze lib/ui/purchase/`,
não o projeto inteiro.

**A cobertura também é medida no escopo mínimo**, com uma ressalva que muda como o número
é lido:

```bash
flutter test --coverage --coverage-path coverage/scoped.info test/domain/purchase_test.dart
awk -F: '/^SF:/{f=$2} /^LF:/{lf=$2} /^LH:/{printf "%6.1f%%  %s\n", lf?100*$2/lf:0, f}' \
  coverage/scoped.info | grep 'models/purchase.dart'
```

**Filtre pelo arquivo editado; não leia a lista inteira.** O relatório parcial traz toda
biblioteca que a cadeia de imports **carregou**, não só a testada: `uuid_test.dart`
sozinho produz 26 entradas, e 25 delas aparecem com 0,0% apenas por terem sido
importadas. Ordenar isso por percentual põe justamente esse ruído no topo e parece um
projeto sem teste nenhum.

**O número parcial é PISO, não a cobertura do arquivo.** Um arquivo de produção costuma
ser exercitado por vários testes — `Purchase` aparece em cinco (`purchase_test`,
`purchase_types_test`, `purchase_repository_remote_test`, `new_purchase_screen_test`,
`edit_purchase_view_model_test`) —, e medir só um deles credita apenas as linhas que
aquele arquivo alcançou. Serve para responder *"o que acabei de escrever tem teste?"*;
**não** serve para dizer que um arquivo está abaixo do piso. Para essa conclusão, o
`grep -rl` acima define o conjunto, e ele inteiro entra na medição.

**O `--coverage-path` não é opcional.** Sem ele o `--coverage` **sobrescreve**
`coverage/lcov.info` com apenas as bibliotecas que aquele teste tocou — o relatório do
projeto inteiro vira o de um arquivo, e a conta dos 90% passa a mentir para menos sem
nenhum aviso. Rodar parcial sempre em `coverage/scoped.info`, que é git-ignored junto com
o resto de `coverage/`.

**A única hora de rodar tudo** — e é o usuário quem pede: antes de um commit que fecha uma
história ou um plano. Aí sim `flutter analyze` sem caminho e `flutter test --coverage` sem
caminho, porque **o piso de 90% do `deploy.yml` é do projeto inteiro** e nenhuma soma
parcial responde por ele.

Fora disso, **peça** antes de rodar a suíte completa.
