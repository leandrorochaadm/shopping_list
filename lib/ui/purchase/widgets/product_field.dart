import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/product_option.dart';

/// The Produto picker, and the whole answer to pendency C1: a STRETCH of the
/// name, ignoring case, blanks and accents, over a list grouped by type with
/// the most-bought type opening it.
///
/// It lives here, and not inside screen 3, because the correction screen (H9)
/// needs the same field to swap an item's product. Two product searches over
/// the same base is the recipe for the two drifting apart on the first change,
/// and neither of them being covered by the other's test.
///
/// **It takes no `ref` and no repository** (rule 4): whoever mounts it already
/// has the options in hand — screen 3 from `NewPurchaseViewModel`, the
/// correction dialog from the purchase it opened. That is also what lets the
/// widget test of both sides skip building a container.
class ProductField extends StatefulWidget {
  const ProductField({
    required this.options,
    required this.onSelected,
    this.initial,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.hintText,
    super.key,
  });

  final IList<ProductOption> options;

  /// What the field opens written with — the item being corrected. Only read
  /// when [controller] is null: a caller holding its own controller is the
  /// one deciding what is in it.
  final ProductOption? initial;

  final ValueChanged<ProductOption> onSelected;

  /// Screen 3 owns both of these, because a product registered on screen 4
  /// has to arrive already written in the field. Left null, the widget makes
  /// its own pair and disposes of them.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  final bool enabled;
  final String? hintText;

  @override
  State<ProductField> createState() => _ProductFieldState();
}

class _ProductFieldState extends State<ProductField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ??
      (_ownController ??= TextEditingController(
        text: widget.initial?.label ?? '',
      ));

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Autocomplete<ProductOption>(
    // Both handed over together, which is what Autocomplete requires — and
    // what lets a product registered on screen 4 arrive already written in
    // the field.
    textEditingController: _controller,
    focusNode: _focusNode,
    displayStringForOption: (option) => option.label,
    optionsBuilder: (value) {
      final query = value.text;
      // C1: a STRETCH of the name, ignoring case, blanks and accents. An
      // empty field shows everything, in the ranked order.
      if (query.trim().isEmpty) return widget.options;
      return widget.options.where((option) => option.matches(query));
    },
    onSelected: widget.onSelected,
    fieldViewBuilder: (context, controller, node, onFieldSubmitted) =>
        TextField(
          key: const ValueKey('field-product'),
          controller: controller,
          focusNode: node,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Produto',
            hintText: widget.hintText,
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        ),
    optionsViewBuilder: (context, onSelected, iterable) => _GroupedOptions(
      groups: groupForPicker(iterable.toIList()),
      onSelected: onSelected,
    ),
  );
}

/// The picker is GROUPED BY TYPE, with the type he buys most opening the
/// list — decision C1. A flat list would put a soft drink between two milks.
class _GroupedOptions extends StatelessWidget {
  const _GroupedOptions({required this.groups, required this.onSelected});

  final IList<ProductGroup> groups;
  final ValueChanged<ProductOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    group.type.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final option in group.options)
                  ListTile(
                    dense: true,
                    title: Text(option.label),
                    onTap: () => onSelected(option),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
