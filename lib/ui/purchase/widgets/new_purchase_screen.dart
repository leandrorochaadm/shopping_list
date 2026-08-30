import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/online_status.dart';
import '../../../domain/models/base_unit.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase_draft.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/store.dart';
import '../../../routing/routes.dart';
import '../../catalog/widgets/new_product_screen.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/widgets/warning_dialog.dart';
import '../../store/view_model/store_view_model.dart';
import '../../store/widgets/new_store_dialog.dart';
import '../view_model/new_purchase_view_model.dart';
import '../view_model/purchase_draft_view_model.dart';
import 'product_field.dart';
import 'purchase_item_row.dart';

/// Screen 3 — registering a purchase, against the two-minute budget of
/// requirement 3.
///
/// Three states live in three places, and keeping them apart is what makes
/// the screen work offline: the ITEM being typed lives here (the form), the
/// PURCHASE lives in `PurchaseDraftViewModel` (and in Hive), and the I/O
/// lives in `NewPurchaseViewModel`.
class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  final _quantityController = TextEditingController();
  final _valueController = TextEditingController();

  /// The Autocomplete's own controller and focus node, held here rather than
  /// left to it: a product registered on screen 4 arrives ALREADY chosen, and
  /// without the controller there is no way to write its name into the field.
  /// And `[ + Adicionar ]` sends the cursor back here for the next item —
  /// twenty items is twenty rounds of this loop.
  final _productController = TextEditingController();
  final _productFocus = FocusNode();

  ProductOption? _option;

  /// Leaves registered on screen 4 during THIS purchase. They are held here
  /// instead of invalidating the picker's provider: invalidating would reload
  /// the whole catalog and blank the form — the same reason the stores are
  /// watched by the widget and not by the ViewModel.
  IList<ProductOption> _justRegistered = const IList.empty();

  /// Set once the Valor field is touched by hand: from then on nothing
  /// recomputes it. It is the acceptance criterion, literally.
  bool _valueTouched = false;

  /// The line being corrected by `[ed]`, so `[ + Adicionar ]` replaces it
  /// instead of adding a second one.
  String? _editingItemId;

  bool _saving = false;

  /// Today, read ONCE and rounded to the day — rule 9. A fresh instant on
  /// every frame would rebuild the date picker's bound on every build, and a
  /// `DateTime.now()` inside `build()` is the classic way an `==` stops
  /// filtering anything.
  ///
  /// It bounds the calendar so a future day cannot be TAPPED. The rule itself
  /// is still `Purchase.checkDate`, in the domain: a screen may never be the
  /// only guard (rule 11).
  late final DateTime _today = dayOf(DateTime.now());

  @override
  void dispose() {
    _quantityController.dispose();
    _valueController.dispose();
    _productController.dispose();
    _productFocus.dispose();
    super.dispose();
  }

  int? get _typedQuantity {
    final option = _option;
    if (option == null) return null;
    try {
      // Sold by weight, "1,5" is a kilo and a half and becomes 1500 g; sold
      // by piece it is a plain count of packages. The parsing is the domain's,
      // digit by digit, and never goes through a double.
      return option.isSoldByWeight
          ? option.baseUnit.typedMeasure.parseAmount(_quantityController.text)
          : MeasureUnit.unit.parseAmount(_quantityController.text);
    } on Object {
      return null;
    }
  }

  /// Each change of quantity redoes the value — until it is typed by hand.
  void _onQuantityChanged() {
    if (_valueTouched) return;
    final reference = _option?.priceReference;
    final typed = _typedQuantity;
    if (reference == null || typed == null) return;

    _valueController.text = formatMoneyPlain(
      reference.estimateFor(_option!.toBaseUnit(typed)),
    );
  }

  void _onProductChosen(ProductOption option) {
    setState(() {
      _option = option;
      _valueTouched = false;
    });
    _onQuantityChanged();
  }

  void _clearForm() {
    setState(() {
      _option = null;
      _editingItemId = null;
      _valueTouched = false;
    });
    _quantityController.clear();
    _valueController.clear();
    _productController.clear();
  }

  /// `[ed]` — the line comes back into the form, and the button below turns
  /// into "Salvar alteração".
  void _edit(PurchaseItem item) {
    setState(() {
      _option = item.option;
      _editingItemId = item.id;
      // What is loaded IS the typed value, so nothing may recompute over it.
      _valueTouched = true;
    });
    _productController.text = item.label;
    _quantityController.text = item.option.isSoldByWeight
        ? item.option.baseUnit.typedMeasure.format(item.quantityInBaseUnit)
        : '${item.quantity}';
    _valueController.text = formatMoneyPlain(item.paid);
  }

  Future<void> _addItem() async {
    final option = _option;
    if (option == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final int quantity;
    final Money paid;
    try {
      // Both parsers are the DOMAIN's, digit by digit, and neither goes
      // through a double: '0,35' × 100 in binary floating point is 34.999…,
      // and one truncation later a cent is gone.
      quantity = option.isSoldByWeight
          ? option.baseUnit.typedMeasure.parseAmount(_quantityController.text)
          : MeasureUnit.unit.parseAmount(_quantityController.text);
      paid = Money.parse(_valueController.text);
    } on InvalidAmount catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } on AmountTooPrecise catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } on InvalidMoney catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    final error = await ref
        .read(purchaseDraftViewModelProvider.notifier)
        .putItem(
          PurchaseItem(
            // Kept on an edit, so the line is corrected and not doubled.
            id: _editingItemId,
            option: option,
            quantity: quantity,
            paid: paid,
          ),
        );
    if (!mounted) return;

    if (error != null) {
      // The write to Hive was refused — the line IS on screen anyway, and the
      // sentence says it is not safe yet.
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    _clearForm();
    // Back to the product field: twenty items is twenty rounds of this loop,
    // and a tap saved here is twenty taps saved.
    _productFocus.requestFocus();
  }

  /// The `[+Novo]→4` of the wireframe. `push`, never `go`: `go` replaces the
  /// route and would take this screen — with the purchase on it — away.
  Future<void> _registerProduct() async {
    final picked = await context.push<PickedProduct>(
      Routes.newProduct,
      // What tells screen 4 to hand the leaf back instead of navigating to
      // the list.
      extra: const NewProductRequest(returnsSelection: true),
    );
    if (!mounted || picked == null) return;

    final option = ProductOption(
      product: picked.product,
      registration: picked.registration,
      type: picked.type,
      brand: picked.brand,
      // No reference: a product registered a moment ago has never been
      // bought, which is the wireframe's "sem base de comparação".
    );
    setState(() {
      _justRegistered = _justRegistered.add(option);
      _option = option;
      _valueTouched = false;
    });
    _productController.text = option.label;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _saving = true);
    final outcome = await ref
        .read(newPurchaseViewModelProvider.notifier)
        .save(
          draft: ref.read(purchaseDraftViewModelProvider),
          // The same day the calendar was bounded by, so the screen and the
          // rule cannot disagree about what "today" is.
          today: _today,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      // The reentrancy guard barred a second tap: nothing to show.
      case null:
        return;
      case PurchaseSaved(:final capAlert, :final sameDay):
        messenger.showSnackBar(const SnackBar(content: Text('Compra salva.')));
        _clearForm();
        // The two warnings of H13 and H14, STACKED on the same confirmation
        // screen with a single `[ Entendi ]` — the cap on top, exactly as the
        // wireframe of screen 3 draws it. `showWarnings` opens nothing when
        // there is nothing to say, so there is no `if` here.
        await showWarnings(context, [
          if (capAlert != null) capAlert.message,
          for (final alert in sameDay)
            alert.messageFor(
              today: _today,
              shortDate: formatShortDate(alert.purchasedOn),
            ),
        ]);
        // The purchase is registered either way: the dialog acknowledges it,
        // it does not decide anything.
        router.go(Routes.shoppingList);
      case PurchaseHeldOffline():
        // No SnackBar and NO navigation: the banner above already says what
        // happened, and leaving the screen would hide the purchase that is
        // still waiting.
        break;
      case SaveFailed(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(purchaseDraftViewModelProvider);
    final options = ref.watch(newPurchaseViewModelProvider);
    // The stores are watched HERE and not inside the purchase ViewModel: the
    // dialog that creates one writes AsyncData on this provider, and a
    // dependency between the two would redo both catalog queries and blank
    // the fields in the face of whoever just registered a store.
    final stores = ref.watch(storeViewModelProvider);
    final online = ref.watch(onlineStatusProvider);
    final showsRecovery = ref.watch(recoveryBannerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar compra'),
        // R11: installed on the home screen there is no browser Back button.
        leading: context.canPop()
            ? BackButton(onPressed: context.pop)
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (showsRecovery) _RecoveryBanner(draft: draft),
            if (!online) const _OfflineBanner(),
            _DateField(
              value: draft.date,
              today: _today,
              enabled: !_saving,
              onChanged: (date) => ref
                  .read(purchaseDraftViewModelProvider.notifier)
                  .setDate(date),
            ),
            const SizedBox(height: 12),
            _StoreField(
              stores: stores,
              value: draft.storeId,
              enabled: !_saving,
              onChanged: (id) {
                if (id == null) return;
                ref.read(purchaseDraftViewModelProvider.notifier).setStore(id);
              },
              onCreate: () async {
                final created = await NewStoreDialog.show(context, ref);
                if (!mounted || created?.id == null) return;
                await ref
                    .read(purchaseDraftViewModelProvider.notifier)
                    .setStore(created!.id!);
              },
            ),
            if (draft.items.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Itens desta compra',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final item in draft.items)
                PurchaseItemRow(
                  item: item,
                  editing: item.id == _editingItemId,
                  onEdit: () => _edit(item),
                  onRemove: () async {
                    if (item.id == _editingItemId) _clearForm();
                    await ref
                        .read(purchaseDraftViewModelProvider.notifier)
                        .removeItem(item.id);
                  },
                ),
            ],
            const Divider(height: 32),
            _ProductField(
              state: options,
              extra: _justRegistered,
              controller: _productController,
              focusNode: _productFocus,
              selected: _option,
              enabled: !_saving,
              onChosen: _onProductChosen,
              onRetry: () =>
                  ref.read(newPurchaseViewModelProvider.notifier).refresh(),
              onCreate: _registerProduct,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-quantity'),
              controller: _quantityController,
              enabled: _option != null && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // The iOS keyboard offers a comma or a dot depending on the
              // layout, and the domain's parser reads both.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                labelText: _option?.quantityLabel ?? 'Quantidade',
              ),
              onChanged: (_) => setState(_onQuantityChanged),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-value'),
              controller: _valueController,
              enabled: _option != null && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Valor total pago',
                helperText: _option?.priceReference == null
                    ? 'Sem base de comparação'
                    : 'Sugerido pela última compra',
              ),
              // The first touch by hand stops every recalculation, for good.
              onChanged: (_) => _valueTouched = true,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              key: const ValueKey('add-item'),
              onPressed: _option == null || _saving ? null : _addItem,
              child: Text(
                _editingItemId == null
                    ? '+ Adicionar à compra'
                    : 'Salvar alteração',
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total da compra',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  formatMoney(draft.total),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('save'),
              onPressed: _saving ? null : _save,
              child: Text(_saveLabel(online)),
            ),
          ],
        ),
      ),
    );
  }

  String _saveLabel(bool online) {
    if (_saving) return 'Salvando...';
    // What the platform actually delivers: WebKit has no Background Sync
    // (R16), so nothing goes up with the app closed, and the label says so.
    return online ? 'Salvar compra' : 'Salvar quando eu abrir com sinal';
  }
}

/// "Rascunho recuperado" — a purchase from a previous run of the app.
class _RecoveryBanner extends ConsumerWidget {
  const _RecoveryBanner({required this.draft});

  final PurchaseDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(purchaseDraftViewModelProvider.notifier);
    final count = draft.items.length;

    return MaterialBanner(
      // The store's NAME does not live in the draft — it holds a key — and
      // going to fetch it would be a round trip in the middle of a recovery
      // that has to work with no network at all.
      content: Text(
        'Rascunho recuperado: compra de ${formatShortDate(draft.date)}, '
        '${count == 1 ? '1 item' : '$count itens'}, não salva.',
      ),
      actions: [
        TextButton(
          onPressed: notifier.dismissBanner,
          child: const Text('Continuar'),
        ),
        TextButton(onPressed: notifier.discard, child: const Text('Descartar')),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => const MaterialBanner(
    // Decided in this story (D3). The wireframe promised "quando o sinal
    // voltar", and WebKit has no Background Sync (R16): with the app closed
    // in a pocket, nothing happens. The app does resend on its own with the
    // app OPEN — which is more than this sentence promises, and that is the
    // right way round.
    content: Text(
      'Sem conexão. Esta compra está guardada no aparelho e será salva '
      'quando você abrir o app com sinal.',
    ),
    actions: [SizedBox.shrink()],
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.today,
    required this.enabled,
    required this.onChanged,
  });

  final DateTime value;

  /// Read once by the screen and rounded to the day — never here.
  final DateTime today;

  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(labelText: 'Data da compra'),
    child: InkWell(
      key: const ValueKey('field-date'),
      onTap: enabled ? () => _pick(context) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatDate(value)),
          const Icon(Icons.calendar_today_outlined, size: 18),
        ],
      ),
    ),
  );

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(today.year - 2),
      // A day after today CANNOT BE TAPPED. Blocking it at the source beats
      // a message afterwards — and `Purchase.checkDate` is still the rule,
      // because a screen may never be the only guard (rule 11).
      lastDate: today,
    );
    if (picked != null) onChanged(picked);
  }
}

class _StoreField extends StatelessWidget {
  const _StoreField({
    required this.stores,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCreate,
  });

  final AsyncValue<IList<Store>> stores;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final list = stores.value ?? const IList<Store>.empty();

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const ValueKey('field-store'),
            initialValue: list.any((store) => store.id == value) ? value : null,
            decoration: InputDecoration(
              labelText: 'Mercado',
              hintText: _hint(list),
            ),
            items: [
              for (final store in list.where((store) => store.active))
                DropdownMenuItem(value: store.id, child: Text(store.name)),
            ],
            // Only the two fields go quiet while the lists load — the body of
            // the screen never does, or the recovered purchase would blink
            // out from under whoever is reading it.
            onChanged: enabled && stores.hasValue ? onChanged : null,
          ),
        ),
        IconButton(
          key: const ValueKey('new-store'),
          icon: const Icon(Icons.add),
          tooltip: 'Novo mercado',
          onPressed: enabled ? onCreate : null,
        ),
      ],
    );
  }

  String? _hint(IList<Store> list) {
    if (stores.isLoading && !stores.hasValue) return 'Carregando...';
    if (stores.hasError && !stores.hasValue) {
      return translateFailure(
        AppFailure.from(stores.error!),
        'carregar os mercados',
      );
    }
    return list.isEmpty ? 'Nenhum mercado ainda — cadastre o primeiro' : null;
  }
}

class _ProductField extends StatelessWidget {
  const _ProductField({
    required this.state,
    required this.extra,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.enabled,
    required this.onChosen,
    required this.onRetry,
    required this.onCreate,
  });

  final AsyncValue<IList<ProductOption>> state;

  /// Registered on screen 4 during this purchase, and therefore not in what
  /// the picker loaded when the screen opened.
  final IList<ProductOption> extra;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ProductOption? selected;
  final bool enabled;
  final ValueChanged<ProductOption> onChosen;
  final Future<String?> Function() onRetry;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final options = (state.value ?? const IList<ProductOption>.empty()).addAll(
      extra,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The picker itself lives in `product_field.dart`, shared with
            // the correction screen: what stays here is the loading/error
            // hint and the two buttons around it, which are screen 3's.
            Expanded(
              child: ProductField(
                options: options,
                controller: controller,
                focusNode: focusNode,
                enabled: enabled && state.hasValue,
                hintText: _hint(options),
                onSelected: onChosen,
              ),
            ),
            IconButton(
              key: const ValueKey('new-product'),
              icon: const Icon(Icons.add),
              tooltip: 'Novo produto',
              onPressed: enabled ? onCreate : null,
            ),
          ],
        ),
        if (state.hasError && !state.hasValue)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('retry-products'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ),
      ],
    );
  }

  String? _hint(IList<ProductOption> options) {
    if (state.isLoading && !state.hasValue) return 'Carregando...';
    if (state.hasError && !state.hasValue) {
      return translateFailure(
        AppFailure.from(state.error!),
        'carregar os produtos',
      );
    }
    return options.isEmpty
        ? 'Nenhum produto ainda — cadastre o primeiro'
        : null;
  }
}
