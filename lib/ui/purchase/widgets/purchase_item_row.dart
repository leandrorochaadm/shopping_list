import 'package:flutter/material.dart';

import '../../../domain/models/purchase_item.dart';
import '../../core/formatting.dart';

/// One line of "Itens desta compra": what was bought, how much, what it cost,
/// and the `[ed]` that reopens it in the form below.
///
/// It draws itself from the line ALONE — the leaf travels inside
/// [PurchaseItem] — so a purchase recovered from Hive in airplane mode is
/// readable with no catalog and no network.
class PurchaseItemRow extends StatelessWidget {
  const PurchaseItemRow({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    this.editing = false,
    super.key,
  });

  final PurchaseItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// True while this very line is loaded in the form below — the form is the
  /// only place it can be corrected, and without a mark on the row there is
  /// nothing on screen saying which line is being edited.
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      key: ValueKey('purchase-item-${item.id}'),
      dense: true,
      selected: editing,
      title: Text(item.label),
      subtitle: Text(
        '${item.quantityLabel} · ${formatMoney(item.paid)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Corrigir ${item.label}',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remover ${item.label}',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
