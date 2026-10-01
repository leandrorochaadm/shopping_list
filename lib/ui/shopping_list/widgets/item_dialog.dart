import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/shopping_list.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../catalog/view_model/catalog_view_model.dart';
import '../../core/unit_specs.dart';
import '../view_model/shopping_list_view_model.dart';

/// The item dialog of H6: quantity, product, "não encontrei" and remove.
///
/// Since M-a the two dropdowns of brand and packaging are ONE field,
/// "Produto": the registration the line asks for, which is what the
/// write-off obeys. An option another open line of the type already asks for
/// is greyed out, so the same product never sits on the list twice.
///
/// **Two doors since H17**, and `wireframes §Tela 6` is what demands it — "o
/// **mesmo** diálogo de item da Tela 1":
///
///   * [ItemDialog.editing] — screen 1, and screen 6 on a type that is already
///     on the list. It EDITS the existing line, never creating a second one.
///   * [ItemDialog.creating] — screen 6 on a type that is not on the list yet.
///     There is no item to edit, so there is nothing to remove and nothing to
///     mark as not found: "marcar como não encontrado o que ninguém pediu não
///     quer dizer nada".
///
/// It has an exit of its own (`R11`): in an installed PWA there is no browser
/// Back button.
class ItemDialog extends ConsumerStatefulWidget {
  const ItemDialog._({
    this.item,
    required this.type,
    required this.category,
    this.prefilledQuantity,
    super.key,
  });

  /// Screen 1, and the "já está na lista" path of screen 6.
  ItemDialog.editing(ShoppingListItem item, {int? prefilledQuantity, Key? key})
    : this._(
        item: item,
        type: item.type,
        category: item.category,
        prefilledQuantity: prefilledQuantity,
        key: key,
      );

  /// Screen 6 on a type that is NOT on the list yet, and the `#1a` panel on
  /// a type that IS (M-a) — a second line, with a product of its own.
  const ItemDialog.creating({
    required ProductType type,
    required Category category,
    int? prefilledQuantity,
    Key? key,
  }) : this._(
         type: type,
         category: category,
         prefilledQuantity: prefilledQuantity,
         key: key,
       );

  /// Null in the creating mode — and it is what every branch below asks.
  final ShoppingListItem? item;

  /// Always present: in the editing mode it is the item's own, in the creating
  /// mode it is what screen 6 handed over. Reading it instead of
  /// `item!.type` is what lets the two modes share every widget below.
  final ProductType type;

  /// The same, and it is what `add` needs — the line carries the whole
  /// category (D4).
  final Category category;

  /// What screen 6 says is missing. **It wins over the stored quantity**: the
  /// dialog is being opened FROM that number.
  ///
  /// Null in the bottom band of screen 6 — nothing is missing there, and a
  /// prefilled `0` would make saving throw `InvalidQuantity`.
  final int? prefilledQuantity;

  /// Screen 1's door, unchanged in signature so its callers do not move.
  static Future<void> show(BuildContext context, ShoppingListItem item) =>
      showDialog<void>(
        context: context,
        builder: (context) => ItemDialog.editing(item),
      );

  /// Screen 6's door: it hands over the type, the category and what is
  /// missing, and this decides which of the two modes it is.
  ///
  /// [existing] comes from `findOpenItemOfType`, which is where the "nunca
  /// criando um segundo" of the wireframe is actually decided.
  static Future<void> showForType(
    BuildContext context, {
    required ProductType type,
    required Category category,
    int? missing,
    ShoppingListItem? existing,
  }) => showDialog<void>(
    context: context,
    builder: (context) => existing == null
        ? ItemDialog.creating(
            type: type,
            category: category,
            prefilledQuantity: missing,
          )
        : ItemDialog.editing(existing, prefilledQuantity: missing),
  );

  @override
  ConsumerState<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<ItemDialog> {
  late final TextEditingController _quantity = TextEditingController(
    // Filled with what is already stored, in the unit the field is typed in:
    // the whole number, never the large unit. Screen 6's prefill wins over
    // it — the dialog was opened from that number.
    text: switch (widget.prefilledQuantity ?? widget.item?.quantity) {
      final int amount => specOf(widget.type.baseUnit).format(amount),
      null => '',
    },
  );

  /// What the person picked in the "Produto" field: a registration id or
  /// [_any] for "Qualquer um". Null until they touch it — and then [_choice]
  /// says what the field starts on.
  String? _picked;
  late bool _notFound = widget.item?.notFound ?? false;

  IList<TypeLeaf> _leaves = const IList.empty();
  bool _loadingLeaves = true;
  bool _saving = false;
  String? _quantityError;

  /// The one branch the whole dialog turns on. In the creating mode there is
  /// no line yet: nothing to remove, nothing to mark as not found, and the
  /// save is an `add` instead of a `save`.
  bool get _isEditing => widget.item != null;

  /// The value of "Qualquer um" in the dropdown. Not null, because null is
  /// what the field holds when nothing was chosen; and never a real id, since
  /// ids are uuids.
  static const _any = '';

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  /// The option the field is on: a registration id, [_any], or null for
  /// NOTHING chosen. Editing starts on the line's own product. Creating
  /// starts on "Qualquer um" only while no other line of the type is already
  /// "Qualquer um" — then the person has to choose.
  ///
  /// Asked on every build rather than fixed in `initState`, because the list
  /// may still be loading when the dialog opens.
  String? get _choice {
    final picked = _picked;
    if (picked != null) return picked;
    final item = widget.item;
    if (item != null) return item.effectivePreferredRegistration?.id ?? _any;
    return _isTaken(_any) ? null : _any;
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    final typeId = widget.type.id;
    if (typeId == null) {
      setState(() => _loadingLeaves = false);
      return;
    }

    // Through the ViewModel, never the repository (rule 4). A failure comes
    // back as an empty list — a list of products that did not load must not
    // stop the quantity from being adjusted, and the field simply keeps
    // "Qualquer um".
    final leaves = await ref
        .read(catalogViewModelProvider.notifier)
        .leavesOfType(typeId);
    if (!mounted) return;
    setState(() {
      _leaves = leaves;
      _loadingLeaves = false;
    });
  }

  /// The registrations OTHER open lines of the type already ask for — the
  /// rule is the domain's (rule 11); the dialog only asks it. `null` in the
  /// set is "Qualquer um".
  ISet<String?> _takenIn(IList<ShoppingListItem>? items) =>
      takenRegistrationsOfType(
        items ?? const IList.empty(),
        widget.type.id ?? '',
        exceptItemId: widget.item?.id,
      );

  /// `read`, so it can be asked from `_save` too; `build` watches the list,
  /// which is what greys out at once an option the other phone just took.
  ISet<String?> get _taken =>
      _takenIn(ref.read(shoppingListViewModelProvider).value);

  bool _isTaken(String option) =>
      _taken.contains(option == _any ? null : option);

  /// The brand of a registration, from the catalog — the registration only
  /// keeps the id. Falls back to the one the line already carries, so a
  /// catalog that did not load does not erase the brand of the label.
  Brand? _brandOf(ProductRegistration registration) {
    final brandId = registration.brandId;
    if (brandId == null) return null;
    final brands = ref.read(catalogViewModelProvider).value?.brands;
    return brands?.where((brand) => brand.id == brandId).firstOrNull ??
        (widget.item?.preferredRegistrationBrand?.id == brandId
            ? widget.item!.preferredRegistrationBrand
            : null);
  }

  /// The ACTIVE registrations of the type, once each, in the order the
  /// field shows them — by what they read.
  IList<ProductRegistration> get _registrations {
    final byId = <String, ProductRegistration>{
      for (final leaf in _leaves)
        if (leaf.registration.active && leaf.registration.id != null)
          leaf.registration.id!: leaf.registration,
    };
    return (byId.values.toList()..sort(
          (a, b) => normalizeName(
            a.labelWith(_brandOf(a)),
          ).compareTo(normalizeName(b.labelWith(_brandOf(b)))),
        ))
        .toIList();
  }

  /// The registration behind [_choice]. The line's own stored one is the
  /// fallback: leaves that failed to load must not clear a preference the
  /// person never touched.
  ProductRegistration? get _chosenRegistration {
    final choice = _choice;
    if (choice == null || choice == _any) return null;
    return _registrations.where((r) => r.id == choice).firstOrNull ??
        (widget.item?.preferredRegistration?.id == choice
            ? widget.item!.preferredRegistration
            : null);
  }

  Future<void> _save() async {
    final typed = _quantity.text.trim();

    // The EMPTY field stays null, and that is an answer: it is the "sai na
    // primeira compra" of the dialog. Only a filled one is read, and
    // the mask leaves nothing malformed to refuse — what is left is a field
    // holding zero.
    int? quantity;
    if (typed.isNotEmpty) {
      final parsed = specOf(widget.type.baseUnit).parse(typed);
      if (parsed <= 0) {
        // Under the field, never a SnackBar: it is an answer about what was
        // just typed, and it belongs next to what was typed.
        setState(() => _quantityError = 'Informe uma quantidade válida.');
        return;
      }
      quantity = parsed;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _quantityError = null;
    });

    final notifier = ref.read(shoppingListViewModelProvider.notifier);
    final item = widget.item;
    final registration = _chosenRegistration;
    final brand = registration == null ? null : _brandOf(registration);
    final error = item == null
        // The creating mode keeps the product chosen (M-a revoked E-k): with
        // the write-off by registration, a second line of milk saved without
        // it would be worth any milk.
        ? await notifier.add(
            widget.type,
            widget.category,
            quantity: quantity,
            preferredRegistration: registration,
            preferredRegistrationBrand: brand,
          )
        : await notifier.save(
            item.copyWith(
              quantity: quantity,
              clearQuantity: quantity == null,
              preferredRegistration: registration,
              preferredRegistrationBrand: brand,
              clearRegistration: registration == null,
              notFound: _notFound,
            ),
          );
    if (!mounted) return;

    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  Future<void> _remove() async {
    // Only reachable in the editing mode: the button is not built otherwise.
    final item = widget.item!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da lista?'),
        content: Text('${item.label} sai da lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final error = await ref
        .read(shoppingListViewModelProvider.notifier)
        .remove(item);
    if (!mounted) return;

    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  /// Under the field, and it says the two sides of one rule.
  ///
  /// Normally it explains what an empty field means. On the item that is on
  /// the list WITH NO QUANTITY and was opened from screen 6, it explains what
  /// confirming changes: the line stops leaving on the first purchase and
  /// starts being written off by amount. **The screen does not change
  /// the rule in silence** (decision of 26/08/2026) — and stacking both
  /// sentences would be noise, since the second one is what ends the first.
  String get _quantityHelper {
    final prefill = widget.prefilledQuantity;
    if (_isEditing && widget.item!.quantity == null && prefill != null) {
      return 'este item está na lista sem quantidade — confirmar passa a '
          'pedir ${widget.type.baseUnit.formatQuantity(prefill)}';
    }
    // "do tipo" left with M-a: with a product chosen it is no longer true.
    return 'Vazio: sai na primeira compra.';
  }

  /// Under the "Produto" field. It says what the choice means for the
  /// write-off — or, when there is nothing to choose, why.
  String get _productHelper {
    if (_choice == null) {
      final allTaken =
          !_loadingLeaves &&
          _isTaken(_any) &&
          _registrations.every((r) => _isTaken(r.id!));
      return allTaken
          ? 'Todos os produtos deste tipo já estão na lista.'
          : 'Escolha um produto que ainda não está na lista.';
    }
    return _choice == _any
        ? 'Sai da lista com qualquer ${widget.type.name.toLowerCase()}.'
        : 'Só sai da lista com este produto.';
  }

  /// One option of the field. A product another line already asks for stays
  /// visible but greyed out, and says why.
  DropdownMenuItem<String> _option(String value, String label) {
    final taken = _isTaken(value);
    return DropdownMenuItem(
      value: value,
      enabled: !taken,
      child: Text(taken ? '$label · já está na lista' : label),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(shoppingListViewModelProvider);
    final registrations = _registrations;
    final choice = _choice;

    return AlertDialog(
      title: Text(widget.type.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField.unit(
              key: const ValueKey('field-quantity'),
              controller: _quantity,
              enabled: !_saving,
              // The spec of the type's BASE unit, never the packaging: what
              // sums is the type, and six litres typed here are six litres
              // even with a 350 ml packaging preferred. The suffix comes with
              // it, and it is the READING unit now — 'L', not 'ml'.
              spec: specOf(widget.type.baseUnit),
              errorText: _quantityError,
              decoration: InputDecoration(
                labelText: 'Quantidade',
                errorMaxLines: 3,
                helperText: _quantityHelper,
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('field-registration'),
              // The stored registration only becomes an option once the
              // leaves have loaded — until then a value with no matching item
              // trips the DropdownButton assertion.
              initialValue:
                  choice == _any || registrations.any((r) => r.id == choice)
                  ? choice
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Produto',
                helperText: _productHelper,
                helperMaxLines: 3,
              ),
              items: [
                _option(_any, 'Qualquer um'),
                for (final registration in registrations)
                  _option(
                    registration.id!,
                    registration.labelWith(_brandOf(registration)),
                  ),
              ],
              onChanged: _saving || _loadingLeaves
                  ? null
                  : (id) => setState(() => _picked = id),
            ),
            if (_loadingLeaves)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            // Both only exist on a line that EXISTS: there is nothing to mark
            // as not found and nothing to remove on a type nobody has asked
            // for yet.
            if (_isEditing) ...[
              SwitchListTile(
                key: const ValueKey('field-not-found'),
                value: _notFound,
                title: const Text('Não encontrei'),
                contentPadding: EdgeInsets.zero,
                // The ONLY way to the `[!]`: the checkbox on the line never
                // passes through it.
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _notFound = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover da lista'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // Nothing chosen: the creating mode of a type whose "Qualquer um"
          // is already on the list, and the field says what to do.
          onPressed: _saving || choice == null ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }

  /// Spelled out next to the field: "kg" reads as an abbreviation of something
  /// else when it stands alone beside a number.
}
