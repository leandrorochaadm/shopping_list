import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/barcode.dart';
import '../../../domain/models/checkout.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/scale_label.dart';
import '../../../domain/models/scan_resolution.dart';
import '../../../domain/models/store.dart';
import '../../barcode/view_model/barcode_lookup_view_model.dart';
import '../../barcode/widgets/barcode_camera_view.dart';
import '../../core/beep.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/unit_specs.dart';
import '../../store/view_model/store_view_model.dart';
import '../view_model/purchase_draft_view_model.dart';
import 'purchase_item_edit_dialog.dart';
import 'purchase_item_row.dart';
import 'scale_link_dialog.dart';
import 'scale_store_dialog.dart';

/// The sentence of the exit warning. [withoutPrice] are the lines still
/// waiting for a price and [unregistered] the codes left as "Produto não
/// cadastrado": both stay out of the purchase.
@visibleForTesting
String checkoutLeftOutMessage({
  required int withoutPrice,
  required int unregistered,
}) {
  if (unregistered == 0) {
    return withoutPrice == 1
        ? '1 item sem preço não entrou na compra.'
        : '$withoutPrice itens sem preço não entraram na compra.';
  }
  final total = withoutPrice + unregistered;
  return total == 1
      ? '1 item não entrou na compra.'
      : '$total itens não entraram na compra.';
}

/// A packaging read that still waits for its price. Screen state, outside the
/// draft: it is not a line of the purchase until it has a price.
final class _PendingLine {
  _PendingLine({required this.key, required this.need, required this.price});

  /// From a counter, so the field does not swap controllers when another line
  /// leaves the list.
  final int key;
  NeedsPrice need;
  final TextEditingController price;
  String? error;
}

/// Checkout mode `#3b` — the camera stays open over screen 3 and each read
/// goes straight into the purchase draft.
///
/// No route of its own: it is a full-screen dialog, so closing it is a plain
/// `pop` back to screen 3, which only has to redraw.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    required this.options,
    required this.onRegister,
    required this.reloadOptions,
    required this.keyboardUp,
    super.key,
  });

  static Future<void> show(
    BuildContext context, {
    required IList<ProductOption> Function() options,
    required Future<ProductOption?> Function(Barcode code) onRegister,
    required Future<String?> Function() reloadOptions,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog.fullscreen(
      child: CheckoutScreen(
        options: options,
        onRegister: onRegister,
        reloadOptions: reloadOptions,
        keyboardUp: MediaQuery.viewInsetsOf(context).bottom > 0,
      ),
    ),
  );

  /// A function and not a list: the options change with the screen open
  /// (a registration, a `refresh()`). It is the `_allOptions` of screen 3.
  final IList<ProductOption> Function() options;

  /// The `_registerLeaf` of screen 3: opens screen 4 with the code on the
  /// first card and returns the leaf it registered.
  final Future<ProductOption?> Function(Barcode code) onRegister;

  /// Reloads the options and fixes the `_justRegistered` of screen 3.
  final Future<String?> Function() reloadOptions;

  /// Read OUTSIDE the `Dialog`, which applies the keyboard inset as padding
  /// and removes it from the child: inside, the inset reads 0.
  final bool keyboardUp;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  static const _cameraHeight = 220.0;

  Future<void> _last = Future<void>.value();
  bool _asking = false;
  bool _registering = false;
  bool _concluding = false;
  bool _closed = false;

  final _pending = <_PendingLine>[];
  final _unregistered = <Barcode>[];
  int _nextKey = 0;
  String? _lastRead;

  // An animation and not a Timer: `pumpAndSettle` waits for it, and a Timer
  // left pending would fail the test.
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  final _scroll = ScrollController();

  @override
  void dispose() {
    _flash.dispose();
    _scroll.dispose();
    for (final line in _pending) {
      line.price.dispose();
    }
    super.dispose();
  }

  IList<Store> get _stores =>
      ref.read(storeViewModelProvider).value ?? const IList<Store>.empty();

  // putItem/removeItem/setStore return null WITHOUT writing while another write
  // runs (rule 14 inside _mutate), and the state only changes after the save.
  // One job at a time, each reading the draft the previous one left.
  void _enqueue(Future<void> Function() job) {
    final messenger = ScaffoldMessenger.of(context);
    _last = _last.then((_) async {
      if (!mounted) return;
      try {
        await job();
      } on Object catch (e, st) {
        // A job that throws would leave _last failed: every later read would
        // be skipped in silence, and the await in _conclude would rethrow.
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(translateError(e, st, 'ler o código'))),
          );
        }
      }
    });
  }

  void _onDetect(String raw) {
    // A question is open: the read is not counted.
    if (_asking || _concluding) return;
    _enqueue(() => _handleScan(raw));
  }

  Future<void> _handleScan(String raw, {String? storeId}) async {
    final draft = ref.read(purchaseDraftViewModelProvider);
    final resolution = resolveScan(
      raw,
      widget.options(),
      storeId: storeId ?? draft.storeId,
    );
    await _apply(resolution, raw);
  }

  Future<void> _apply(ScanResolution resolution, String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    final adopted = ref
        .read(purchaseDraftViewModelProvider)
        .storeAdoptedFrom(resolution);
    if (adopted != null) {
      final error = await ref
          .read(purchaseDraftViewModelProvider.notifier)
          .setStore(adopted);
      if (!mounted) return;
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    }
    // The state AFTER the previous job.
    final items = ref.read(purchaseDraftViewModelProvider).items;

    switch (checkoutScan(resolution, items)) {
      case ItemAdded(:final item):
        _feedback('✓ ${item.label}  ${formatMoney(item.paid)}');
        // The await is the queue: without it the job ends before the save and
        // the next read sees the old items.
        await _put(item);
      case QuantityIncreased() && final step:
        _feedback(
          '✓ ${step.item.label}  ${formatMoney(step.addedPaid(items))}',
        );
        await _put(step.item);
      case NeedsPrice() && final need:
        _addPending(need);
        _feedback('✓ ${need.option.selectedLabel}');
      case CheckoutNoMatch(:final code):
        await _askToRegister(code, raw);
      case CheckoutScaleUnlinked(:final itemCode, :final weightInGrams):
        await _linkLabel(
          ScaleUnlinked(itemCode: itemCode, weightInGrams: weightInGrams),
        );
      case CheckoutScaleInManyStores(:final storeIds):
        _asking = true;
        final chosen = await ScaleStoreDialog.show(
          context,
          storeIds: storeIds,
          stores: _stores,
        );
        _asking = false;
        if (!mounted || chosen == null) return;
        // With the store given, `resolveScan` answers `ScaleMatch`, and the
        // step above adopts the store.
        await _handleScan(raw, storeId: chosen);
      case CheckoutUnknownLabel():
        setState(
          () => _lastRead =
              'Não conheço esta etiqueta. Escolha o produto pela lista.',
        );
      case CheckoutInvalid():
        setState(() => _lastRead = 'Código de barras inválido.');
    }
  }

  Future<void> _put(PurchaseItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(purchaseDraftViewModelProvider.notifier)
        .putItem(item);
    if (!mounted) return;
    // `_mutate` swaps the state even on error: the line stays on screen.
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _remove(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(purchaseDraftViewModelProvider.notifier)
        .removeItem(id);
    if (!mounted) return;
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  void _feedback(String text) {
    ref.read(beepProvider).play();
    _flash.forward(from: 0).whenComplete(() {
      if (mounted) _flash.reverse();
    });
    setState(() => _lastRead = text);
  }

  void _addPending(NeedsPrice need) {
    for (final line in _pending) {
      final joined = line.need.joining(need);
      if (joined != null) {
        setState(() => line.need = joined);
        return;
      }
    }
    setState(
      () => _pending.add(
        _PendingLine(
          key: _nextKey++,
          need: need,
          price: TextEditingController(),
        ),
      ),
    );
    // So the new field is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmPrice(_PendingLine line) {
    final item = line.need.pricedAt(
      Money(UnitSpec.currency.parse(line.price.text)),
    );
    if (item == null) {
      setState(() => line.error = 'Informe um valor válido.');
      return;
    }
    setState(() => _pending.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.price.dispose());
    _enqueue(() => _put(item));
  }

  Future<void> _askToRegister(Barcode code, String raw) async {
    _asking = true;
    final register = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produto não cadastrado'),
        content: Text(code.label),
        actions: [
          FilledButton(
            key: const ValueKey('checkout-unknown-register'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cadastrar'),
          ),
          TextButton(
            key: const ValueKey('checkout-unknown-later'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Depois'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted) return;

    if (register != true) {
      _leaveOut(code);
      return;
    }
    // The camera leaves the tree: the reader of screen 4 would fight for it.
    setState(() => _registering = true);
    ProductOption? created;
    try {
      created = await widget.onRegister(code);
    } finally {
      // Even when it throws: the camera must come back, or no later read
      // would ever reach the queue.
      if (mounted) setState(() => _registering = false);
    }
    if (!mounted) return;

    // A leaf sold by weight takes no packaging code, so the code read stayed
    // out of it.
    if (created != null && created.product.acceptsBarcodes) {
      // Never bought: it becomes a pending line with the price open.
      await _apply(PackagingMatch(option: created), raw);
    } else {
      _leaveOut(code);
    }
  }

  void _leaveOut(Barcode code) {
    if (!_unregistered.contains(code)) setState(() => _unregistered.add(code));
  }

  Future<void> _linkLabel(ScaleUnlinked label) async {
    final messenger = ScaffoldMessenger.of(context);
    _asking = true;
    final link = await ScaleLinkDialog.show(
      context,
      label: label,
      candidates: scaleLinkCandidatesOf(widget.options()),
      stores: _stores,
      storeId: ref.read(purchaseDraftViewModelProvider).storeId,
    );
    _asking = false;
    if (!mounted || link == null) return;

    final error = await ref
        .read(barcodeLookupViewModelProvider.notifier)
        .linkScaleCode(
          registration: link.option.registration,
          productId: link.option.id!,
          code: ScaleCode(storeId: link.storeId, itemCode: label.itemCode),
        );
    if (!mounted) return;

    // Goes on even if the link failed: the purchase is at the till, and the
    // link only serves the next read. The empty raw is never used —
    // `ScaleMatch` does not go back to `_handleScan`.
    await _apply(label.linkedTo(link.option, link.storeId), '');
    if (!mounted) return;

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final reloadError = await widget.reloadOptions();
    if (!mounted) return;
    if (reloadError != null) {
      messenger.showSnackBar(SnackBar(content: Text(reloadError)));
    }
  }

  Future<void> _edit(PurchaseItem item) async {
    _asking = true;
    final edited = await PurchaseItemEditDialog.show(
      context,
      item: item,
      options: widget.options(),
      onRemove: () => _enqueue(() => _remove(item.id)),
    );
    _asking = false;
    if (!mounted || edited == null) return;
    _enqueue(() => _put(edited));
  }

  Future<void> _confirmItemPrice(String itemId) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(purchaseDraftViewModelProvider.notifier)
        .confirmPrice(itemId);
    if (!mounted) return;
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _conclude() async {
    if (_concluding) return;
    _concluding = true;
    try {
      // Lets the last read be saved before closing.
      await _last;
      if (!mounted) return;
      final leftOut = _pending.length + _unregistered.length;
      if (leftOut > 0 && !await _confirmLeavingOut()) return;
      _closeWith();
    } finally {
      if (mounted) _concluding = false;
    }
  }

  Future<bool> _confirmLeavingOut() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          checkoutLeftOutMessage(
            withoutPrice: _pending.length,
            unregistered: _unregistered.length,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('checkout-exit-back'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const ValueKey('checkout-exit-anyway'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concluir assim'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// One `pop` only, and only while this route is the top one: a read that
  /// arrives with checkout closing must not close screen 3.
  void _closeWith() {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(purchaseDraftViewModelProvider);
    // Watched so the stores are loaded when a dialog asks for their names.
    ref.watch(storeViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _conclude();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 128,
          leading: TextButton.icon(
            key: const ValueKey('checkout-done'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Concluir'),
            onPressed: _conclude,
          ),
          title: const Text('Caixa'),
        ),
        // A Builder so the SnackBar finds a context BELOW the Scaffold.
        body: Builder(
          builder: (context) => Column(
            children: [
              SizedBox(
                height: _cameraHeight,
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, child) => DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 4,
                        color: Color.lerp(
                          Colors.transparent,
                          Colors.green,
                          _flash.value,
                        )!,
                      ),
                    ),
                    child: child,
                  ),
                  child: Stack(
                    children: [
                      if (_registering)
                        const SizedBox.expand()
                      else
                        Center(child: BarcodeCameraView(onDetect: _onDetect)),
                      if (_lastRead case final text?)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              text,
                              key: const ValueKey('checkout-last-read'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    for (final item in draft.items)
                      PurchaseItemRow(
                        item: item,
                        onEdit: () => _edit(item),
                        onConfirmPrice: () =>
                            _enqueue(() => _confirmItemPrice(item.id)),
                      ),
                    for (final line in _pending)
                      _PendingPriceRow(
                        key: ValueKey('checkout-pending-${line.key}'),
                        line: line,
                        onConfirm: () => _confirmPrice(line),
                      ),
                    for (final code in _unregistered)
                      ListTile(
                        key: ValueKey('checkout-unregistered-${code.code}'),
                        dense: true,
                        title: Text('Produto não cadastrado · ${code.label}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Gone with the keyboard, like the footer of screen 3.
        bottomNavigationBar: widget.keyboardUp
            ? null
            : _CheckoutFooter(count: draft.items.length, total: draft.total),
      ),
    );
  }
}

/// The line of a packaging with no earlier purchase: the price is typed right
/// here. A field in a repeatable line is exception 1 of `ui-conventions.md`.
class _PendingPriceRow extends StatelessWidget {
  const _PendingPriceRow({
    required this.line,
    required this.onConfirm,
    super.key,
  });

  final _PendingLine line;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final option = line.need.option;
    final spec = option.isSoldByWeight ? specOf(option.baseUnit) : countSpec;
    final quantity = spec.format(line.need.quantity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${option.selectedLabel} · $quantity'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField.currency(
                  key: ValueKey('checkout-price-${line.key}'),
                  controller: line.price,
                  errorText: line.error,
                  decoration: const InputDecoration(labelText: 'Preço'),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  key: ValueKey('checkout-price-ok-${line.key}'),
                  onPressed: onConfirm,
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
          Text(
            'sem compra anterior',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({required this.count, required this.total});

  final int count;
  final Money total;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(count == 1 ? '1 item' : '$count itens'),
          Text(
            formatMoney(total),
            key: const ValueKey('checkout-total'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}
