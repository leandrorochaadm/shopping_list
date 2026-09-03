---
name: equality-chain
description: A corrente da igualdade — quem deve o == (Riverpod, IList e nós), e por que não freezed nem equatable
quando-ler: ao escrever == / hashCode de uma entidade, ou ao cogitar freezed / equatable
---

# A corrente da igualdade — quem deve o `==`

A regra 8 exige `==`/`hashCode` cobrindo todos os campos, e a pergunta que sempre volta é
se algum pacote poupa esse trabalho. **Não poupa** — e o motivo é que a igualdade é uma
corrente de três elos, cada um com um dono diferente.

O `==` do `AsyncValue` **já vem pronto do Riverpod**
(`riverpod-3.4.2/lib/src/core/async_value.dart:654-664`): compara `runtimeType`,
`_loading`, `_errorFilled` e o valor — e o valor ele **delega ao `==` do seu `T`**.
`AsyncResult`, `AsyncData` e `AsyncError` herdam esse `==` sem redefinir nada. Ou seja:
**nunca se escreve o `==` de um `AsyncValue`**, e não há o que um gerador faça nele. O
único `==` que pode faltar é o do valor que viaja dentro do envelope.

| Elo | Dono | Já resolvido? |
|---|---|---|
| `AsyncData<T>` / `AsyncError<T>` | Riverpod | **sim**, `async_value.dart:654` |
| `IList<E>` | `fast_immutable_collections` | **sim**, `isDeepEquals: true` é o default |
| `E` — a entidade ou a classe | **nós** | **não**, escrito à mão |

Os dois formatos de `T` que o projeto usa mostram onde cada elo entra:

```
T é a coleção — AsyncNotifier<IList<Store>>
  AsyncData<IList<Store>>.==  ->  IList.==  ->  Store.==
       (Riverpod)                  (FIC)       (À MÃO)

T é uma classe que contém coleções — AsyncNotifier<CatalogOptions>
  AsyncData<CatalogOptions>.==  ->  CatalogOptions.==  ->  IList.==  ->  Category.==
       (Riverpod)                        (À MÃO)          (FIC)       (À MÃO)
```

**O `IList` fecha um elo, nunca a corrente.** Ele garante que uma coleção de mesmo
conteúdo seja `==`, e é por isso que um campo de coleção se compara com
`other.categories == categories`, sem `listEquals` e sem laço. Mas **abaixo** ele apenas
transporta a pergunta para o elemento, que continua devendo o seu `==`; e **acima** ele
não age: uma classe sem `==` compara por referência e a corrente arrebenta no primeiro
elo, sem as `IList` internas chegarem a ser consultadas. É o bug silencioso da regra 8 —
o Riverpod para de filtrar update, a tela repinta a cada refresh e nenhum erro aparece.

**Por que não `freezed` nem `equatable`** (os dois seguem proibidos em "Não fazer sem eu
pedir"):

- **`equatable` não elimina o erro.** O `props` é uma lista escrita à mão: esquecer um
  campo ali é o mesmo esquecimento de deixá-lo fora do `==`. Troca linhas por risco
  idêntico, e o teste campo a campo continua obrigatório do mesmo jeito.
- **`freezed` elimina**, porque o gerador enumera os campos sozinho — mas traz de volta o
  `build_runner` que a Stack recusou, e criaria duas convenções no mesmo repositório: as
  entidades atuais têm `==`, `copyWith` e `fromJson`/`toJson` escritos à mão. Adotá-lo só
  nas classes novas é pior do que qualquer um dos extremos.

Adotar qualquer um dos dois é **alteração de escopo**, não decisão de implementação. Se um
dia o número de classes com `==` manual passar da ordem de 40–50, a conta muda e vale
reabrir; hoje não.

A rede que de fato pega o campo esquecido é o **teste**: duas instâncias de campos iguais
são `==` e têm o mesmo `hashCode`, mais um caso trocando **um** campo por vez.
