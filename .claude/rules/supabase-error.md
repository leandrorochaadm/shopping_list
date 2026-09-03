---
name: supabase-error
description: O tradutor de erro do Supabase — rethrowAsKnownFailure e a armadilha do SQLSTATE lido como status HTTP
quando-ler: ao escrever ou editar qualquer método de um repository _remote
---

# O tradutor de erro do Supabase — `data/services/supabase_error.dart`

**Todo método de `_remote` fecha seu I/O com `rethrowAsKnownFailure(e, st)`.** Sem isso a
`PostgrestException` sobe crua e o `AppFailure` a joga em `UnexpectedFailure`.

A armadilha que ele resolve: o PostgREST põe o **SQLSTATE** em `code`, não um status HTTP.
`'23505'` (a trava de duplicidade do cadastro) lido como número vira "status 23505", cai
no ramo `>= 500` e o usuário lê *"o servidor está indisponível"* quando o que houve foi
*"esse produto já existe"*. Estado novo mapeado entra em `_httpStatusBySqlState`, com teste.
