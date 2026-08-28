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
    appBar: AppBar(title: Text(title), leading: _exit(context)),
    body: MessageView(
      'Tela ainda não construída.\nEla chega na história $story.',
    ),
  );

  /// In standalone mode on iOS there is no browser Back button and no refresh
  /// gesture (`R11`): every screen needs an exit of its own. Which one it
  /// shows depends on whether there is anything to pop back to.
  ///
  /// There is no arm for the shopping list here any more: since H4 the root
  /// route renders the real screen, so this placeholder is never the one the
  /// home button would point at itself.
  Widget? _exit(BuildContext context) {
    if (context.canPop()) return BackButton(onPressed: context.pop);
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Ir para a lista',
      onPressed: () => context.go(Routes.shoppingList),
    );
  }
}
