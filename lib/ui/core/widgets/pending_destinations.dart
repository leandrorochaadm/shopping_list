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
  Routes.reports: 'Os relatórios chegam na H11.',
  Routes.remainingThisMonth: '"Falta comprar este mês" chega na H18.',
};

/// `/settings` is deliberately absent: it exists since H1 (minimal, with the
/// device label) and is completed in H13. So are `/purchases/new` (H7),
/// `/purchases` and `/purchases/:id/edit` (H9) and `/catalog` (H10) — the
/// four this delivery took out of the map.
bool isPending(String route) => pendingDestinations.containsKey(route);
