---
name: language
description: Regra zero — todo o código em inglês americano; só o texto de tela é pt-BR
quando-ler: antes de nomear qualquer classe, método, variável, arquivo, teste ou comentário
---

# Idioma do código — regra zero

**Todo o código é escrito em inglês americano.** Classes, métodos, variáveis, campos,
constantes, enums, nomes de arquivo e de pasta, comentários e descrições de teste.

**Única exceção:** o texto que o usuário final lê na tela (títulos, botões, estado vazio,
mensagens de erro traduzidas) fica em **português do Brasil**.

| Item | Idioma |
|---|---|
| `class Appointment`, `canCancel(now)`, `clientName` | inglês |
| `appointment_repository_local.dart` | inglês |
| `// The rule comes from the domain.` | inglês |
| `test('blocks canceling less than 24h ahead', ...)` | inglês |
| `throw ArgumentError('baseUrl is empty...')` | inglês (lê o dev) |
| `Text('Cancelar')`, `'Nenhum agendamento.'` | português (lê o usuário) |
| `'Cancelamento exige $hours horas de antecedência.'` | português (lê o usuário) |

Regra em português vira nome em inglês antes do primeiro arquivo: "só cancela com 24h de
antecedência" → `canCancel(DateTime now)` com `minCancellationNotice`. Chave de JSON
espelha o contrato real da API; o campo Dart continua em inglês
(`clientName: json['nome_cliente'] as String`). Vocabulário sem tradução consagrada
(`CPF`, `PIX`, `boleto`) fica como está.
