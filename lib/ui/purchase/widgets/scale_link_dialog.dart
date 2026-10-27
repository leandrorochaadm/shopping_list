import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/scan_resolution.dart';
import '../../../domain/models/store.dart';
import '../../core/unit_specs.dart';

/// What "Qual produto é este?" hands back: the leaf the person tapped and the
/// store the label is linked in. A value returned in a `pop` (rule 16).
final class ScaleLink {
  const ScaleLink({required this.option, required this.storeId});

  final ProductOption option;
  final String storeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleLink &&
          other.option == option &&
          other.storeId == storeId);

  @override
  int get hashCode => Object.hash(option, storeId);
}

/// "Qual produto é este?" — a scale label with no product yet. One tap on a
/// product links the label to it in that store and uses it.
class ScaleLinkDialog extends StatefulWidget {
  const ScaleLinkDialog({
    super.key,
    required this.label,
    required this.candidates,
    required this.stores,
    required this.storeId,
  });

  /// [candidates] already come from `scaleLinkCandidatesOf`; the dialog filters
  /// nothing. It writes nothing either: whoever opened it links, with the
  /// [ScaleLink] it returns.
  static Future<ScaleLink?> show(
    BuildContext context, {
    required ScaleUnlinked label,
    required IList<ProductOption> candidates,
    required IList<Store> stores,
    required String? storeId,
  }) => showModalBottomSheet<ScaleLink>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ScaleLinkDialog(
      label: label,
      candidates: candidates,
      stores: stores,
      storeId: storeId,
    ),
  );

  final ScaleUnlinked label;
  final IList<ProductOption> candidates;
  final IList<Store> stores;
  final String? storeId;

  @override
  State<ScaleLinkDialog> createState() => _ScaleLinkDialogState();
}

class _ScaleLinkDialogState extends State<ScaleLinkDialog> {
  late String? _storeId = widget.storeId;
  bool _closed = false;

  /// The ONLY way out. A second `pop` on a route that is already leaving would
  /// close the screen below, with the purchase typed on it.
  void _closeWith(ScaleLink? link) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    final spec = specOf(BaseUnit.gram);
    final stores = widget.stores
        .where((store) => store.active || store.id == widget.storeId)
        .toList();
    // A value outside the items would bring the field down.
    final initial = stores.any((store) => store.id == _storeId)
        ? _storeId
        : null;

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
                    'Qual produto é este?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('scale-link-close'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                  onPressed: () => _closeWith(null),
                ),
              ],
            ),
            Text(
              'Etiqueta ${widget.label.itemCode} · '
              '${spec.format(widget.label.weightInGrams)} ${spec.suffix}',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('scale-link-store'),
              initialValue: initial,
              decoration: const InputDecoration(labelText: 'Mercado'),
              items: [
                for (final store in stores)
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
              ],
              // With the store of screen 3 the field is locked.
              onChanged: widget.storeId == null
                  ? (id) => setState(() => _storeId = id)
                  : null,
            ),
            const Divider(),
            if (widget.candidates.isEmpty)
              const Text('Nenhum produto vendido a peso ainda.')
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in widget.candidates)
                      ListTile(
                        key: ValueKey('scale-link-${option.id}'),
                        title: Text(option.selectedLabel),
                        enabled: _storeId != null,
                        onTap: () => _closeWith(
                          ScaleLink(option: option, storeId: _storeId!),
                        ),
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
