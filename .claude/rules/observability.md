---
name: observability
description: Regras de log, crash report e analytics — só valem se existir lib/data/services/observability/
quando-ler: ao mexer em logger, crash reporter ou analytics, ou ao fazer build de release ofuscado
---

# Observabilidade — só se o projeto tiver Sentry/PostHog

Se existir `lib/data/services/observability/`, estas regras valem em toda feature nova:

- O padrão dos providers (`loggerProvider`, `crashReporterProvider`, `analyticsProvider`)
  é **`Noop`**. Nenhum teste faz rede; não mude isso para "facilitar" um teste.
- **Nada de dado pessoal sai do dispositivo**: nem nome, e-mail, telefone, CPF, endereço,
  nem o corpo de resposta da API. Mande `id`, `statusCode` e a rota.
- **Nenhum `toString()` de exceção carrega payload** — é essa string que o Sentry envia.
- Erro de ação: log + `recordHandled` dentro do `catch`, **antes** de traduzir.
- Bloqueio por regra de negócio **não** é erro — não reporte.
- Nada de `await` em `track`/`identify`/`recordHandled` no caminho do usuário.
- Nome de evento: inglês, snake_case, no passado (`appointment_canceled`).
- Build de release com `--obfuscate` ou `--split-debug-info` **exige**
  `dart run sentry_dart_plugin` depois do `flutter build` — sem os símbolos, o stack trace
  de produção é uma lista de endereços. O `auth_token` vem de `SENTRY_AUTH_TOKEN` no
  ambiente, nunca do `pubspec.yaml`.

Detalhes e código: `11_observabilidade` na skill `flutter-mvvm`.
