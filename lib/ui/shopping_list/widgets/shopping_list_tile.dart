import 'package:flutter/material.dart';

import '../../../domain/models/shopping_list_item.dart';

/// One line of the list, with **two touch targets and no numeric field**.
///
/// That is an acceptance criterion of H6, and the reason is in the wireframe: a
/// field on the line would open the keyboard by accident in the aisle and push
/// half the list off the screen.
///
/// | Part | Gesture | Effect |
/// |---|---|---|
/// | the checkbox | tap | picked ↔ empty, **never** "não encontrei" |
/// | the text | tap | opens the item dialog |
class ShoppingListTile extends StatelessWidget {
  const ShoppingListTile({
    required this.item,
    required this.onTogglePicked,
    required this.onOpen,
    super.key,
  });

  final ShoppingListItem item;
  final VoidCallback onTogglePicked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = item.quantityLabel;

    return ListTile(
      // Comfortably above the 48-pixel target the checklist asks for.
      minTileHeight: 56,
      onTap: onOpen,
      leading: Semantics(
        label: item.picked
            ? '${item.label}, pego'
            : '${item.label}, não pego',
        child: Checkbox(
          value: item.picked,
          // The rule is the entity's: the caller asks the ViewModel, which
          // asks `item.togglePicked()`. Nothing here decides anything.
          onChanged: (_) => onTogglePicked(),
        ),
      ),
      title: Text(
        item.label,
        // Picking something up is only a visual strike-through: it registers
        // no purchase and never takes the item off the list.
        style: item.picked
            ? theme.textTheme.bodyLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.disabledColor,
              )
            : theme.textTheme.bodyLarge,
      ),
      subtitle: item.notFound
          ? const Text('(não encontrei)')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.notFound)
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.error,
              semanticLabel: 'não encontrei',
            ),
          if (quantity != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(quantity, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}
