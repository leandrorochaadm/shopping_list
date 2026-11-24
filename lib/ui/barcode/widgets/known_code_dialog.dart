import 'package:flutter/material.dart';

import '../../../domain/models/barcode_owner.dart';

/// What the person chose when told the code already has an owner.
enum KnownCodeChoice { readAnother, edit }

/// "Já cadastrado" on screen 4: says who owns the code and offers two ways out.
final class KnownCodeDialog extends StatelessWidget {
  const KnownCodeDialog({required this.owner, super.key});

  final BarcodeOwner owner;

  /// Null when the dialog is dismissed from outside.
  static Future<KnownCodeChoice?> show(BuildContext context, BarcodeOwner owner) => showDialog<KnownCodeChoice>(
    context: context,
    builder: (_) => KnownCodeDialog(owner: owner),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Text('Já cadastrado: ${owner.label}.'),
    actions: [
      TextButton(
        key: const ValueKey('known-code-read-another'),
        onPressed: () => Navigator.of(context).pop(KnownCodeChoice.readAnother),
        child: const Text('Ler outro'),
      ),
      FilledButton(
        key: const ValueKey('known-code-edit'),
        onPressed: () => Navigator.of(context).pop(KnownCodeChoice.edit),
        child: const Text('Abrir para editar'),
      ),
    ],
  );
}
