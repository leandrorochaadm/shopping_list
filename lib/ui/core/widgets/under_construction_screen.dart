import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'message_view.dart';

/// Placeholder for a route whose screen has not been written yet.
///
/// It exists so the router can register the eleven routes from day one: every
/// story replaces one of these with the real screen, and until then a link to
/// an unbuilt screen lands somewhere that says so — instead of a dead end or a
/// route that does not exist.
///
/// **Delete this widget when the last screen is written.**
class UnderConstructionScreen extends StatelessWidget {
  const UnderConstructionScreen({
    required this.title,
    required this.story,
    super.key,
  });

  /// pt-BR, like every screen title.
  final String title;

  /// Which story delivers this screen ('H4', 'H11'), shown on the screen so
  /// the sequence is visible while developing.
  final String story;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      // In standalone mode on iOS there is no browser Back button and no
      // refresh gesture (`R11`): every screen needs an exit of its own.
      leading: context.canPop()
          ? BackButton(onPressed: context.pop)
          : IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Ir para a lista',
              onPressed: () => context.go(Routes.shoppingList),
            ),
    ),
    body: MessageView(
      'Tela ainda não construída.\nEla chega na história $story.',
    ),
  );
}
