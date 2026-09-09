import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../core/online_status.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/price_increase.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/proportional_cost.dart';
import '../../../domain/models/purchase_draft.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/store.dart';
import '../../../domain/models/unit_price.dart';
import '../../../routing/routes.dart';
import '../../catalog/widgets/new_product_screen.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/unit_specs.dart';
import '../../core/widgets/warning_dialog.dart';
import '../../store/view_model/store_view_model.dart';
import '../../store/widgets/new_store_dialog.dart';
import '../view_model/new_purchase_view_model.dart';
import '../view_model/purchase_draft_view_model.dart';
import 'cost_comparison_panel.dart';
import 'price_increase_warning.dart';
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

  /// The price of ONE pricing unit — the "R$ 39,90 o kg" of the shelf tag.
  /// It is the same money as [_valueController] seen from the other side, and
  /// the two are kept in step by [_recomputePrices].
  final _unitPriceController = TextEditingController();

  /// The Autocomplete's own controller and focus node, held here rather than
  /// left to it: a product registered on screen 4 arrives ALREADY chosen, and
  /// without the controller there is no way to write its name into the field.
  /// And `[ + Adicionar ]` sends the cursor back here for the next item —
  /// twenty items is twenty rounds of this loop.
  final _productController = TextEditingController();
  final _productFocus = FocusNode();

  /// Where the cursor goes when the `#3a` panel hands an option back — it is
  /// the "volta ao lançamento com o produto já trocado, o cursor na
  /// quantidade" of requirement 17. `[ + Adicionar ]` keeps sending the
  /// focus back to Produto.
  final _quantityFocus = FocusNode();

  ProductOption? _option;

  /// Leaves registered on screen 4 during THIS purchase. They are held here
  /// instead of invalidating the picker's provider: invalidating would reload
  /// the whole catalog and blank the form — the same reason the stores are
  /// watched by the widget and not by the ViewModel.
  IList<ProductOption> _justRegistered = const IList.empty();

  /// Which of the two money fields was typed LAST — and therefore which one
  /// the other is computed from.
  ///
  /// It replaced the old `_valueTouched` boolean, which only had to answer
  /// "may the suggestion still write here?". With two fields the question
  /// became "who is the source now?", and a boolean cannot say it: typing the
  /// price per kilo has to redo the total, typing the total has to redo the
  /// price per kilo, and changing the amount has to redo whichever the person
  /// did NOT type.
  _PriceSource _priceSource = _PriceSource.none;

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
    _unitPriceController.dispose();
    _productController.dispose();
    _productFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  /// The mask of the quantity field, and the ONE place the choice is made:
  /// sold by weight it is the magnitude of the type, sold by piece it is a
  /// plain count of packages — which is what `BaseUnit.unit.parseAmount` used
  /// to say on the three lines that read this field.
  ///
  /// Null option is the field disabled; the count spec keeps the mask from
  /// changing shape at the moment a product is chosen.
  UnitSpec get _quantitySpec {
    final option = _option;
    if (option == null || !option.isSoldByWeight) return countSpec;
    return specOf(option.baseUnit);
  }

  int? get _typedQuantity {
    if (_option == null) return null;
    // Nothing throws any more: the mask only lets digits in, and an empty
    // field reads as zero — which is the "not typed yet" this getter means.
    final typed = _quantitySpec.parse(_quantityController.text);
    return typed > 0 ? typed : null;
  }

  /// **H15** — the warning of the item being typed, or null.
  ///
  /// It is **not computed inside `build()`**: whoever decides is
  /// `option.priceIncreaseFor`, in the domain (rule 11). This getter only
  /// gathers what the three fields hold today, and returns null while any of
  /// them is missing — which is the written acceptance criterion ("não há
  /// alerta antes de quantidade e valor").
  PriceIncrease? get _priceIncrease {
    final option = _option;
    final typed = _typedQuantity;
    if (option == null || typed == null) return null;

    // The mask never lets a malformed value exist, so what is left to guard is
    // the field with nothing in it — and that is the "no warning before the
    // amount and the value" the acceptance criterion asks for.
    final cents = UnitSpec.currency.parse(_valueController.text);
    if (cents <= 0) return null;
    final paid = Money(cents);

    return option.priceIncreaseFor(
      paid: paid,
      quantityInBaseUnit: option.toBaseUnit(typed),
    );
  }

  /// The typed amount already converted into the base unit, or null while
  /// there is no product or no amount — which is when neither money field can
  /// be computed from the other.
  int? get _quantityInBaseUnit {
    final option = _option;
    final typed = _typedQuantity;
    if (option == null || typed == null) return null;
    return option.toBaseUnit(typed);
  }

  /// What a money field holds, or null when it is empty. The mask never lets
  /// a malformed value exist, so an empty field is the only case left.
  Money? _moneyIn(TextEditingController controller) {
    final cents = UnitSpec.currency.parse(controller.text);
    return cents > 0 ? Money(cents) : null;
  }

  /// Writes a computed value into a field — or clears it, when there is
  /// nothing to compute.
  ///
  /// It never bounces back: `onChanged` fires on TYPING, and writing into a
  /// controller from here is not typing.
  void _write(TextEditingController controller, Money? value) {
    controller.text = value == null
        ? ''
        : UnitSpec.currency.format(value.cents);
  }

  /// Redoes the money field the person did NOT type — and, while neither was
  /// typed, pre-fills the total from the last purchase.
  ///
  /// Whoever decides is the domain: `PriceReference.estimateFor` for the
  /// suggestion, `pricePerLargeUnitOf` and `paidAtPricePerLargeUnit` for the
  /// two directions. This method only says WHICH of them to ask.
  void _recomputePrices() {
    final option = _option;
    if (option == null) return;
    final quantity = _quantityInBaseUnit;

    // The price per pricing unit is the SOURCE: it is the total that follows.
    if (_priceSource == _PriceSource.unitPrice) {
      final unitPrice = _moneyIn(_unitPriceController);
      _write(
        _valueController,
        unitPrice == null || quantity == null
            ? null
            : paidAtPricePerLargeUnit(
                pricePerLargeUnit: unitPrice,
                quantityInBaseUnit: quantity,
                unit: option.baseUnit,
              ),
      );
      return;
    }

    // No money typed yet, and the last purchase has something to say.
    final reference = option.priceReference;
    if (_priceSource == _PriceSource.none &&
        reference != null &&
        quantity != null) {
      _write(_valueController, reference.estimateFor(quantity));
    }

    // From here the total is the source, whether it was typed or suggested —
    // and the price per pricing unit MIRRORS whatever is on screen. Deriving
    // it every time is what keeps a price per kilo of the previous product
    // from surviving a product swap the suggestion could not overwrite.
    final paid = _moneyIn(_valueController);
    _write(
      _unitPriceController,
      paid == null || quantity == null
          ? null
          : pricePerLargeUnitOf(
              paid: paid,
              quantityInBaseUnit: quantity,
              unit: option.baseUnit,
            ),
    );
  }

  /// A product picked in the **Produto field** — and a different product is a
  /// different purchase line: the amount, the total paid and the price per
  /// pricing unit are all cleared before it takes over.
  ///
  /// It is NOT what the `#3a` panel comes back through: there the product
  /// changes INSIDE the same type, with the amount already typed, and
  /// requirement 17 says the way back lands on the amount — clearing it would
  /// throw away exactly what the comparison was made for.
  void _onProductChanged(ProductOption option) {
    _quantityController.clear();
    _valueController.clear();
    _unitPriceController.clear();
    _onProductChosen(option);
  }

  void _onProductChosen(ProductOption option) {
    setState(() {
      _option = option;
      _priceSource = _PriceSource.none;
    });
    _recomputePrices();
  }

  void _clearForm() {
    setState(() {
      _option = null;
      _editingItemId = null;
      _priceSource = _PriceSource.none;
    });
    _quantityController.clear();
    _valueController.clear();
    _unitPriceController.clear();
    _productController.clear();
  }

  /// `[ed]` — the line comes back into the form, and the button below turns
  /// into "Salvar alteração".
  void _edit(PurchaseItem item) {
    setState(() {
      _option = item.option;
      _editingItemId = item.id;
      // What is loaded IS the total that was typed, so the suggestion may not
      // write over it — and the price per pricing unit is derived from it,
      // exactly as if it had just been typed.
      _priceSource = _PriceSource.total;
    });
    _productController.text = item.label;
    _quantityController.text = _quantitySpec.format(
      item.option.isSoldByWeight ? item.quantityInBaseUnit : item.quantity,
    );
    _valueController.text = UnitSpec.currency.format(item.paid.cents);
    _recomputePrices();
  }

  Future<void> _addItem() async {
    final option = _option;
    if (option == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // The value comes off the mask already in cents, so nothing here goes
    // through a double: '0,35' × 100 in binary floating point is 34.999…, and
    // one truncation later a cent is gone.
    final cents = UnitSpec.currency.parse(_valueController.text);
    if (cents <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }
    final paid = Money(cents);

    final quantity = _quantitySpec.parse(_quantityController.text);
    if (quantity <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida.')),
      );
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

  /// The options the panel sees: what the picker loaded **plus** what was
  /// registered on screen 4 during this purchase (F-i). `_ProductField` does
  /// the same sum; it is done again here because whoever builds the panel is
  /// the screen, not the field.
  IList<ProductOption> _allOptions(AsyncValue<IList<ProductOption>> state) =>
      (state.value ?? const IList<ProductOption>.empty()).addAll(
        _justRegistered,
      );

  /// The `[ Comparar custo ]→3a` of the wireframe.
  ///
  /// The way back is treated as ANY product choice — `_onProductChosen`
  /// already clears `_valueTouched`, and the `_onQuantityChanged` right after
  /// it redoes the suggested value against the new option's history. The ⚠ of
  /// H15 redoes itself, because it is a getter over `_option`.
  Future<void> _compareCost(IList<ProductOption> options) async {
    final option = _option;
    if (option == null) return;

    final picked = await CostComparisonPanel.show(
      context,
      candidates: costCandidatesOf(
        options: options,
        typeId: option.type.id,
        // F-j: the leaf being registered goes into `shown` even with no
        // price of its own.
        launching: option,
      ),
      launching: option,
    );
    // Closed choosing nothing: the item stays exactly as it was.
    if (!mounted || picked == null) return;

    // **The `setState` first and the controller after**, in the order of
    // `_registerProduct`: writing into the Autocomplete's controller outside
    // a `setState` reopens the options overlay over the field just filled in.
    _onProductChosen(picked);
    _productController.text = picked.selectedLabel;
    _quantityFocus.requestFocus();
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
      _priceSource = _PriceSource.none;
    });
    // A leaf registered a minute ago is a product change like any other: it
    // has never been bought, so there is nothing to suggest and nothing of
    // the previous product may stay behind.
    _quantityController.clear();
    _valueController.clear();
    _unitPriceController.clear();
    _productController.text = option.selectedLabel;
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
            const Divider(height: 32),
            _ProductField(
              state: options,
              extra: _justRegistered,
              controller: _productController,
              focusNode: _productFocus,
              selected: _option,
              enabled: !_saving,
              onChosen: _onProductChanged,
              onRetry: () =>
                  ref.read(newPurchaseViewModelProvider.notifier).refresh(),
              onCreate: _registerProduct,
            ),
            // The `[ Comparar custo ]→3a`, optional and off the normal path:
            // it only appears when the chosen product's type has TWO options
            // or more. Whoever never taps it registers the purchase exactly
            // as before.
            if (_option case final option?)
              if (costCandidatesOf(
                options: _allOptions(options),
                typeId: option.type.id,
                launching: option,
              ).canCompare)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('compare-cost'),
                    onPressed: _saving
                        ? null
                        : () => _compareCost(_allOptions(options)),
                    child: const Text('Comparar custo'),
                  ),
                ),
            const SizedBox(height: 12),
            AppTextField.unit(
              key: const ValueKey('field-quantity'),
              controller: _quantityController,
              focusNode: _quantityFocus,
              enabled: _option != null && !_saving,
              spec: _quantitySpec,
              decoration: InputDecoration(
                labelText: _option?.quantityLabel ?? 'Quantidade',
              ),
              onChanged: (_) => setState(_recomputePrices),
            ),
            const SizedBox(height: 12),
            AppTextField.currency(
              key: const ValueKey('field-value'),
              controller: _valueController,
              enabled: _option != null && !_saving,
              decoration: InputDecoration(
                labelText: 'Valor total pago',
                helperText: _option?.priceReference == null
                    ? 'Sem base de comparação'
                    : 'Sugerido pela última compra',
              ),
              // Typing here makes the total the SOURCE: the suggestion stops
              // writing over it, and the price per pricing unit is redone
              // from it.
              //
              // The `setState` is not decoration: the ⚠ of H15 comes out of
              // the typed value, and without repainting it would only appear
              // on the next touch of another field.
              onChanged: (_) => setState(() {
                _priceSource = _PriceSource.total;
                _recomputePrices();
              }),
            ),
            // The price of ONE pricing unit — the number on the shelf tag.
            //
            // **Only where the product is sold by weight**: the amount there
            // is a weight, a volume or a length, and 'R$ 39,90 o kg' is what
            // is compared at the counter. Sold by piece the price already IS
            // the package's, and a second money field would only be one more
            // thing to fill in.
            if (_option case final option? when option.isSoldByWeight) ...[
              const SizedBox(height: 12),
              AppTextField.currency(
                key: const ValueKey('field-unit-price'),
                controller: _unitPriceController,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Valor por ${option.baseUnit.priceLabel}',
                ),
                onChanged: (_) => setState(() {
                  _priceSource = _PriceSource.unitPrice;
                  _recomputePrices();
                }),
              ),
            ],
            if (_priceIncrease case final increase?)
              PriceIncreaseWarning(increase: increase),
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
            // From here down it is READING, and reading is what the keyboard
            // is allowed to push: the list grows with every item launched, and
            // above the fields it pushed Produto, Quantidade and Valor under
            // the keyboard on a twenty-item purchase.
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

/// Which of the two money fields of the form was typed LAST.
///
/// It is what tells `_recomputePrices` which direction to compute in — and
/// `none`, the form nobody has touched, is what lets the last purchase
/// pre-fill both.
enum _PriceSource { none, total, unitPrice }
