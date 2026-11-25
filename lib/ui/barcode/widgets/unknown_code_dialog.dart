import 'package:flutter/material.dart';

/// "Nenhum produto com o código …": offers to register the product or close.
/// The sentence comes ready from the caller.
final class UnknownCodeDialog extends StatelessWidget {
  const UnknownCodeDialog({super.key, required this.message});

  final String message;

  /// True when the person chose to register; closing by any means is false.
  static Future<bool> show(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UnknownCodeDialog(message: message),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(message),
      actions: [
        FilledButton(
          key: const ValueKey('unknown-code-register'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cadastrar produto'),
        ),
        TextButton(
          key: const ValueKey('unknown-code-close'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
