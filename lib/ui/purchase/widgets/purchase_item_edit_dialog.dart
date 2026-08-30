import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/shopping_list_item.dart' show InvalidQuantity;
import '../../core/formatting.dart';
import 'product_field.dart';

/// One line of a purchase being corrected (H9): quantity, amount paid, the
/// PRODUCT itself, and taking the line out of the purchase altogether.
///
/// **It pops a [PurchaseItem]** — no new type crosses this boundary (rule 16).
/// The entity's own constructor keeps the id of the row that already existed,
/// converts to the base unit and is the single place in the app where that
/// conversion happens; a class of four fields here would be a copy of it that
/// does less.
///
/// Removing is [onRemove] and not a second pop value: the pop carries the
/// corrected line, and a removed line is not a corrected one. The caller
/// already knows which line it opened, so a sealed type of two branches would
/// name what the callback already says.
class PurchaseItemEditDialog extends StatefulWidget {
  const PurchaseItemEditDialog({
    required this.item,
    required this.options,
    required this.onRemove,
    super.key,
  });

  static Future<PurchaseItem?> show(
    BuildContext context, {
    required PurchaseItem item,
    required IList<ProductOption> options,
    required VoidCallback onRemove,
  }) => showDialog<PurchaseItem>(
    context: context,
    builder: (context) => PurchaseItemEditDialog(
      item: item,
      options: options,
      onRemove: onRemove,
    ),
  );

  final PurchaseItem item;

  /// What the picker offers. It comes from the screen, which read it once —
  /// a dialog that fetched its own catalog would be a round trip per line.
  final IList<ProductOption> options;

  final VoidCallback onRemove;

  @override
  State<PurchaseItemEditDialog> createState() => _PurchaseItemEditDialogState();
}

class _PurchaseItemEditDialogState extends State<PurchaseItemEditDialog> {
  late ProductOption _option = widget.item.option;
  late final _quantityController = TextEditingController(
    text: _quantityTextOf(widget.item),
  );
  late final _valueController = TextEditingController(
    text: formatMoneyPlain(widget.item.paid),
  );

  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  /// What the field opens written with: the amount for something weighed,
  /// the plain package count otherwise — where the bare number would read
  /// '1500' for a kilo and a half.
  static String _quantityTextOf(PurchaseItem item) => item.option.isSoldByWeight
      ? item.option.baseUnit.typedMeasure.format(item.quantityInBaseUnit)
      : '${item.quantity}';

  /// Swapping the product may swap how the line is measured — a crate counted
  /// by piece for beef sold by weight. The typed quantity is kept, because
  /// the number on the receipt did not change; what changes is how it is
  /// read, and the label above the field says so.
  void _onProductChosen(ProductOption option) =>
      setState(() => _option = option);

  void _submit() {
    final int quantity;
    final Money paid;
    try {
      // Both parsers are the DOMAIN's, digit by digit, and neither goes
      // through a double: '0,35' × 100 in binary floating point is 34.999…,
      // and one truncation later a cent is gone.
      quantity = _option.isSoldByWeight
          ? _option.baseUnit.typedMeasure.parseAmount(_quantityController.text)
          : MeasureUnit.unit.parseAmount(_quantityController.text);
      paid = Money.parse(_valueController.text);
    } on InvalidAmount catch (e) {
      setState(() => _error = e.message);
      return;
    } on AmountTooPrecise catch (e) {
      setState(() => _error = e.message);
      return;
    } on InvalidMoney catch (e) {
      setState(() => _error = e.message);
      return;
    }

    try {
      Navigator.of(context).pop(
        PurchaseItem(
          // Kept: the trail points at this id, and a new one would orphan it.
          id: widget.item.id,
          option: _option,
          quantity: quantity,
          paid: paid,
        ),
      );
    } on InvalidQuantity catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Corrigir item'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductField(
            options: widget.options,
            initial: widget.item.option,
            onSelected: _onProductChosen,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('field-quantity'),
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // The iOS keyboard offers a comma or a dot depending on the
            // layout, and the domain's parser reads both.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            decoration: InputDecoration(labelText: _option.quantityLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('field-value'),
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Valor total pago',
              errorText: _error,
              // The message can be two lines long, and the default clips it.
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('remove-item'),
        onPressed: () {
          widget.onRemove();
          Navigator.of(context).pop();
        },
        child: const Text('Remover item'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('save-item'),
        onPressed: _submit,
        child: const Text('Salvar'),
      ),
    ],
  );
}
