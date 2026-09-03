---
name: layers
description: As pastas do projeto e o que mora em cada uma (config, routing, domain, data, ui)
quando-ler: ao criar qualquer arquivo novo em lib/, para decidir onde ele mora
---

# Camadas

- `config/` — `dependencies.dart` (os providers de infraestrutura e **os overrides** de
  todos os repositories) e `environment.dart` (`--dart-define`). O `Provider` de cada
  repository é **declarado no arquivo do contrato**, em `data/`, e sobrescrito aqui.
- `routing/` — `routes.dart` (os 11 paths) e `router.dart` (o `GoRouter`).
- `domain/models/` — entidades, **todas as regras de negócio** e as exceções de regra. Dart puro.
- `domain/use_cases/` — só quando a lógica usa 2+ repositories ou é repetida em 2+ ViewModels.
- `data/repositories/<feature>/` — abstract + `_local` (fake) + `_remote` (API).
- `data/services/` — cliente HTTP. Sempre membro **privado** do repository.
- `ui/<feature>/view_model/` — orquestração, estado.
- `ui/<feature>/widgets/` — telas e componentes.
