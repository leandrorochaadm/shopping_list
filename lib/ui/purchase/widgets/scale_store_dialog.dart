import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/store.dart';

/// "Esta etiqueta existe em mais de um mercado. Qual?" — answers the id of the
/// store tapped, or null.
class ScaleStoreDialog extends StatefulWidget {
  const ScaleStoreDialog({
    super.key,
    required this.storeIds,
    required this.stores,
  });

  static Future<String?> show(
    BuildContext context, {
    required IList<String> storeIds,
    required IList<Store> stores,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ScaleStoreDialog(storeIds: storeIds, stores: stores),
  );

  final IList<String> storeIds;
  final IList<Store> stores;

  @override
  State<ScaleStoreDialog> createState() => _ScaleStoreDialogState();
}

class _ScaleStoreDialogState extends State<ScaleStoreDialog> {
  bool _closed = false;

  /// The ONLY way out — see `ScaleLinkDialog._closeWith`.
  void _closeWith(String? id) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final store in widget.stores) store.id: store};

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Esta etiqueta existe em mais de um mercado. Qual?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('scale-store-close'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                  onPressed: () => _closeWith(null),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final id in widget.storeIds)
                    if (byId[id] case final store?)
                      ListTile(
                        key: ValueKey('scale-store-$id'),
                        title: Text(store.name),
                        onTap: () => _closeWith(id),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
