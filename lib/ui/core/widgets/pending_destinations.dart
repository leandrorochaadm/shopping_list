import '../../../routing/routes.dart';

/// Which story delivers each screen that does not exist yet, and the sentence
/// the user reads on tapping it.
///
/// The `handoff` is explicit about this: "destino inexistente fica desabilitado
/// e explicado — nunca um toque que não faz nada e não diz por quê".
///
/// **Remove one entry per story delivered**; an empty map is the sign that this
/// file can be deleted.
const pendingDestinations = <String, String>{
  Routes.suggestions: 'A sugestão de itens chega na H17.',
  Routes.newPurchase: 'O lançamento de compra chega na H7.',
  Routes.purchaseHistory: 'O histórico de compras chega na H9.',
  // The `≡` lists this one as "corrigir compra", and it has TWO reasons to be
  // disabled: the screen is H9's, and `/purchases/:id/edit` does not navigate
  // without an id — which only the history knows.
  Routes.editPurchase: 'A correção de compra chega na H9.',
  Routes.reports: 'Os relatórios chegam na H11.',
  Routes.remainingThisMonth: '"Falta comprar este mês" chega na H18.',
  Routes.catalog: 'A manutenção do cadastro chega na H10.',
};

/// `/settings` is deliberately absent: it exists since H1 (minimal, with the
/// device label) and is completed in H13.
bool isPending(String route) => pendingDestinations.containsKey(route);
