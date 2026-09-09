import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

/// One registration, as this dialog offers it: the id it returns and the
/// label the person reads. A `final class` with `==`/`hashCode` over both
/// fields, never a record (rule 16).
final class RegistrationChoice {
  const RegistrationChoice({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistrationChoice && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// "De qual produto é a embalagem?" — the one question the maintenance screen
/// has to ask before screen 4 can do the rest.
///
/// A packaging is a LEAF of a registration: creating one without saying whose
/// it is has no answer. What comes after the answer is not written here —
/// it is `/products/new` with `registrationId`, the very door
/// `RegistrationEditDialog` already opens.
///
/// It carries no rule and no I/O: the list arrives ready from the screen,
/// which already holds the six catalogs.
abstract final class PickRegistrationDialog {
  static Future<String?> show(
    BuildContext context, {
    required IList<RegistrationChoice> choices,
  }) => showDialog<String>(
    context: context,
    builder: (context) => _PickRegistrationDialog(choices: choices),
  );
}

class _PickRegistrationDialog extends StatefulWidget {
  const _PickRegistrationDialog({required this.choices});

  final IList<RegistrationChoice> choices;

  @override
  State<_PickRegistrationDialog> createState() =>
      _PickRegistrationDialogState();
}

class _PickRegistrationDialogState extends State<_PickRegistrationDialog> {
  String? _id;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova embalagem'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.choices.isEmpty)
            const Text(
              'Nenhum produto cadastrado ainda. Cadastre o produto primeiro: '
              'a embalagem é sempre a embalagem de um produto.',
            )
          else ...[
            // The only field here opens a menu and never calls the keyboard,
            // so there is no fold for it to fall under — the rule of
            // `ui-conventions.md` is about the keyboard, and it still comes
            // first in the dialog.
            DropdownButtonFormField<String>(
              key: const ValueKey('field-registration'),
              initialValue: _id,
              decoration: const InputDecoration(labelText: 'Produto'),
              items: [
                for (final choice in widget.choices)
                  DropdownMenuItem(value: choice.id, child: Text(choice.label)),
              ],
              onChanged: (id) => setState(() => _id = id),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'A embalagem é sempre de um produto. Escolha o produto e a '
                'tela seguinte pergunta o tamanho.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('pick-registration'),
        onPressed: _id == null ? null : () => Navigator.of(context).pop(_id),
        child: const Text('Continuar'),
      ),
    ],
  );
}
