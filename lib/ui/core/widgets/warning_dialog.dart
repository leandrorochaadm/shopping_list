import 'package:flutter/material.dart';

/// The confirmation screen the wireframe of screen 3 draws: the warnings a
/// purchase produced, **stacked**, with a single `[ Entendi ]`.
///
/// It is not a decision and it is not a question — the purchase has already
/// been registered. Whoever reads it acknowledges it and moves on, which is
/// why there is one button and no way to cancel.
///
/// `SingleFieldDialog` does not serve here and was checked first: that one is
/// an ENTRY dialog, with a field, a duplicate guard and a `[ Reativar ]`.
///
/// The `⚠` is drawn HERE and not carried in the sentence: it is presentation,
/// and `CapThreshold.message` is domain (rule 1).
Future<void> showWarnings(BuildContext context, List<String> messages) {
  // Nothing to say, nothing to open — the caller does not have to check.
  if (messages.isEmpty) return Future<void>.value();

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('warnings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠ '),
                  // Expanded, so a long sentence wraps instead of overflowing
                  // the row — the product type's name comes from the catalog
                  // and has no length limit.
                  Expanded(child: Text(message)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('acknowledge-warnings'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
