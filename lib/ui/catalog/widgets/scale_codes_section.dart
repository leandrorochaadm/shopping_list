import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/scale_label.dart';
import '../../../domain/models/store.dart';
import '../../barcode/widgets/barcode_reader_sheet.dart';
import '../../store/view_model/store_view_model.dart';

/// The scale codes of a product sold by weight: pick the store, type the
/// label or read it, and the item code goes into the list.
///
/// It does not know whether the write is at once or at save: the screen
/// decides, through [onAdd] and [onRemove].
class ScaleCodesSection extends ConsumerStatefulWidget {
  const ScaleCodesSection({
    required this.codes,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
    super.key,
  });

  final IList<ScaleCode> codes;

  /// `null` means it went in; otherwise the sentence of the refusal, which
  /// the section shows under the field.
  final Future<String?> Function(ScaleCode code) onAdd;
  final void Function(ScaleCode code) onRemove;
  final bool enabled;

  @override
  ConsumerState<ScaleCodesSection> createState() => _ScaleCodesSectionState();
}

class _ScaleCodesSectionState extends ConsumerState<ScaleCodesSection> {
  final _text = TextEditingController();
  String? _storeId;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _include(String raw, {required bool typed}) async {
    final storeId = _storeId;
    if (storeId == null) return;

    final ScaleCode code;
    try {
      code = ScaleCode.fromLabel(raw, storeId: storeId);
    } on UnknownScaleLabel catch (e) {
      setState(() => _error = e.message);
      return;
    }

    final refusal = await widget.onAdd(code);
    if (!mounted) return;
    setState(() {
      _error = refusal;
      if (refusal == null && typed) _text.clear();
    });
  }

  Future<void> _scan() async {
    final raw = await BarcodeReaderSheet.show(context);
    if (!mounted || raw == null) return;
    await _include(raw, typed: false);
  }

  Future<void> _reloadStores() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(storeViewModelProvider.notifier).refresh();
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  String? _storeName(IList<Store> stores, String id) =>
      stores.where((store) => store.id == id).firstOrNull?.name;

  String _lineOf(IList<Store>? stores, ScaleCode code) {
    final name = _storeName(stores ?? const IList<Store>.empty(), code.storeId);
    return name == null ? '• ${code.itemCode}' : '• $name · ${code.itemCode}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = ref.watch(storeViewModelProvider);
    final all = stores.value;
    final ready = widget.enabled && _storeId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Códigos de balança (opcional)',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          'Cada mercado tem o seu código.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (all == null && stores.hasError) ...[
          const Text('Não foi possível carregar os mercados.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _reloadStores,
              child: const Text('Tentar de novo'),
            ),
          ),
        ] else
          DropdownButtonFormField<String>(
            key: const ValueKey('scale-store'),
            initialValue: _storeId,
            decoration: const InputDecoration(labelText: 'Mercado'),
            items: [
              for (final store in all ?? const IList<Store>.empty())
                if (store.active)
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
            ],
            onChanged: widget.enabled && all != null
                ? (id) => setState(() {
                    _storeId = id;
                    _error = null;
                  })
                : null,
          ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                key: const ValueKey('scale-code'),
                controller: _text,
                enabled: ready,
                decoration: const InputDecoration(
                  hintText: 'Código da etiqueta',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) _include(text, typed: true);
                },
              ),
            ),
            IconButton(
              key: const ValueKey('scale-scan'),
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Ler código',
              onPressed: ready ? _scan : null,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, value, _) => IconButton(
                key: const ValueKey('scale-add'),
                icon: const Icon(Icons.add),
                tooltip: 'Incluir código',
                onPressed: ready && value.text.trim().isNotEmpty
                    ? () => _include(_text.text, typed: true)
                    : null,
              ),
            ),
          ],
        ),
        if (_error case final error?)
          Text(
            error,
            key: const ValueKey('scale-error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        if (widget.codes.isEmpty)
          const Text('Nenhum código.')
        else
          for (final code in widget.codes)
            Row(
              children: [
                Expanded(child: Text(_lineOf(all, code))),
                IconButton(
                  key: ValueKey(
                    'scale-remove-${code.storeId}-${code.itemCode}',
                  ),
                  icon: const Icon(Icons.close),
                  tooltip: 'Remover código',
                  onPressed: widget.enabled
                      ? () => widget.onRemove(code)
                      : null,
                ),
              ],
            ),
      ],
    );
  }
}
