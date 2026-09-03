---
name: new-feature-checklist
description: Os 11 passos, em ordem, para criar uma feature nova do zero
quando-ler: ao começar uma feature, tela ou CRUD novo
---

# Ao criar uma feature nova

0. traduzir o vocabulário de negócio para inglês (`Agendamento` → `Appointment`)
1. `domain/models/<x>.dart` — entidade + regras + exceções + `fromJson`/`toJson` + `copyWith` + `==`
2. `data/repositories/<x>/<x>_repository.dart` — abstract, devolvendo `IList<T>`, com
   métodos em inglês (`fetchAll`, `cancel`, `create`)
3. `..._local.dart` com dados fake e latência de ~400ms
4. `..._remote.dart`
5. registrar provider e overrides em `config/dependencies.dart`
6. `ui/core/app_failure.dart` — uma vez por projeto, não por feature
7. `ui/<x>/view_model/<x>_view_model.dart` — `AsyncNotifier` com `retry: (retryCount, error) => null`
8. `ui/<x>/widgets/<x>_screen.dart` — `ConsumerWidget`
9. `test/domain/<x>_test.dart` — cada regra, incluindo os limites
10. `domain/use_cases/` nasce vazia com `.gitkeep`
