import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/catalog_entry.dart';
import '../../core/widgets/single_field_dialog.dart';
import '../view_model/catalog_maintenance_view_model.dart';

/// Renaming, deactivating and reactivating one of the FOUR name-based
/// catalogs — category, product type, brand and store.
///
/// It is a thin shell over [SingleFieldDialog]: the wording, the two extra
/// actions and the footnote. Every rule it makes hold — the duplicate guard
/// ignoring the row being renamed, the blank name — lives in the ViewModel it
/// calls.
///
/// **The product's two halves do not come through here.** A registration has
/// no name (its guard is the triple identity) and a packaging has none at all
/// (it has content), so each has a dialog of its own.
abstract final class CatalogEntryEditDialog {
  /// The one sentence the whole screen exists to make unnecessary to ask:
  /// nothing is ever deleted (decision 19).
  static const footnote =
      'Cadastro não se apaga: renomear vale para todo o histórico, e '
      'desativar tem volta.';

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required CatalogKind kind,
    required CatalogEntry entry,
  }) => showDialog<String>(
    context: context,
    builder: (dialogContext) => SingleFieldDialog(
      title: 'Editar ${kind.noun}',
      fieldLabel: 'Nome',
      initialValue: entry.name,
      footnote: footnote,
      onSubmit: (name) => ref
          .read(catalogMaintenanceViewModelProvider.notifier)
          .renameNamed(kind, entry.id!, name),
      leadingActions: [
        _ActiveToggle(
          kind: kind,
          entry: entry,
          onDone: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// `[ Desativar ]` when the row is on, `[ Reativar ]` when it is off — the
/// same transition either way (rule 7), and never a delete.
///
/// **Deactivating a TYPE is not done here** when the type is on the list: the
/// screen asks the count first, shows what `TypeInUseOnList` derives, and
/// only the confirmation removes anything. That is `ProductTypeEditDialog`'s
/// job, and it is why this widget refuses the type outright.
class _ActiveToggle extends ConsumerStatefulWidget {
  const _ActiveToggle({
    required this.kind,
    required this.entry,
    required this.onDone,
  });

  final CatalogKind kind;
  final CatalogEntry entry;
  final VoidCallback onDone;

  @override
  ConsumerState<_ActiveToggle> createState() => _ActiveToggleState();
}

class _ActiveToggleState extends ConsumerState<_ActiveToggle> {
  bool _running = false;

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('toggle-active'),
    onPressed: _running ? null : _toggle,
    child: Text(widget.entry.active ? 'Desativar' : 'Reativar'),
  );

  Future<void> _toggle() async {
    // Captured BEFORE the await: after it this context may be gone.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _running = true);
    final error = await ref
        .read(catalogMaintenanceViewModelProvider.notifier)
        .setActive(widget.kind, widget.entry.id!, !widget.entry.active);
    if (!mounted) return;
    setState(() => _running = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onDone();
  }
}
