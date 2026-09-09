---
name: stack
description: Os pacotes de runtime permitidos e as versões mínimas de Flutter e Dart
quando-ler: antes de acrescentar qualquer dependência ao pubspec
---

# Stack

Riverpod **3 ou superior**, escrito **à mão**: sem `@riverpod`, sem `riverpod_annotation`,
sem `build_runner`. Nada de `freezed` nem `json_serializable` — `fromJson`/`toJson`,
`copyWith` e `==` são escritos no arquivo.

`fast_immutable_collections` para as coleções: repository, ViewModel e View trabalham
com `IList<T>`, não `List<T>`.

**Dependências de runtime, e nada além disto** (`tecnico §3`, decisão registrada):

| Pacote | Para quê |
|---|---|
| `supabase_flutter` | backend inteiro: Postgres, PostgREST e Realtime. Traz o cliente HTTP |
| `flutter_riverpod` 3.x | estado e injeção de dependência |
| `go_router` | as 11 rotas nomeadas |
| `hive_ce` + `hive_ce_flutter` | duas coisas só: o rascunho do lançamento e a etiqueta de quem está usando |
| `intl` | formatação pt-BR de data e moeda |
| `fast_immutable_collections` | `IList` — **acréscimo à lista congelada**, ver `docs/decisoes-divergencias.md` |
| `http` | só pelo `ClientException`: o `postgrest` fala por ele e é assim que falha de transporte chega |
| `flutter_localizations` | os delegates pt-BR do Material. Vem do SDK — **acréscimo à lista congelada**, ver `docs/decisoes-divergencias.md` |
| `web` | só os eventos `online`/`offline` do navegador, atrás de um *conditional import* — **acréscimo à lista congelada**, ver `docs/decisoes-divergencias.md` |
| `tekton_core` | o `AppTextField` de todo campo digitável e as máscaras `UnitSpec` — **acréscimo à lista congelada**, ver `docs/decisoes-divergencias.md` (**L-d**). Vem do **git**; o `pubspec_overrides.yaml` local, git-ignored, aponta para o clone ao lado |

Em desenvolvimento: `flutter_test`, `mocktail`, `flutter_lints` ^6.0.0.

**Sem `connectivity_plus`** (decisão 22): em web os eventos `online`/`offline` chegam
pelo pacote `web` que o SDK já traz, e a reconexão do canal do Supabase é o segundo sinal.

Versões mínimas: **Flutter 3.44.0 stable · Dart 3.12.0**.
