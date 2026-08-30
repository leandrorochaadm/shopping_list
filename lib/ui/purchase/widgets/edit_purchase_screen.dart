import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/store.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/widgets/warning_dialog.dart';
import '../../core/formatting.dart';
import '../../core/widgets/message_view.dart';
import '../../store/view_model/store_view_model.dart';
import '../../store/widgets/new_store_dialog.dart';
import '../view_model/edit_purchase_view_model.dart';
import '../view_model/new_purchase_view_model.dart';
import '../view_model/purchase_history_view_model.dart';
import 'purchase_item_edit_dialog.dart';
import 'purchase_item_row.dart';

/// Correcting or deleting one purchase — `/purchases/:id/edit`, H9.
///
/// This is the screen that makes a typo reversible: R$ 3,80 typed instead of
/// R$ 38 is not a wrong number in a report, it is milk missing at home
/// because the item left the list with no way back.
class EditPurchaseScreen extends ConsumerStatefulWidget {
  const EditPurchaseScreen({required this.purchaseId, super.key});

  final String purchaseId;

  @override
  ConsumerState<EditPurchaseScreen> createState() => _EditPurchaseScreenState();
}

class _EditPurchaseScreenState extends ConsumerState<EditPurchaseScreen> {
  /// The correction being typed. It lives here, not in the ViewModel: nothing
  /// is written until `[ Salvar correção ]`, and a half-typed correction that
  /// reached the state would be a purchase the app believes in.
  DateTime? _date;
  String? _storeId;
  IList<PurchaseItem>? _items;

  /// Which purchase the three fields above were seeded from. A `refresh()`
  /// that brings another version re-seeds; a rebuild does not.
  String? _seededFrom;

  /// The second guard, and it is not redundant with the ViewModel's.
  ///
  /// `save` and `delete` return `Future<String?>`, which is rule 16's right
  /// form for two outcomes with no payload — but the `null` the REENTRANCY
  /// guard of rule 14 returns is the SAME null as success, and here success
  /// pops. A double tap would make the second call fall into the guard,
  /// return null, and the View leave the screen with the first write still
  /// in the air. The mould is `SingleFieldDialog`'s `_saving`.
  bool _saving = false;

  /// Today, read ONCE and rounded to the day — rule 9. A fresh instant per
  /// frame would rebuild the calendar's bound on every build.
  late final DateTime _today = dayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editPurchaseViewModelProvider(widget.purchaseId));

    return Scaffold(
      appBar: AppBar(
        // R11: in a standalone PWA there is no browser Back button. Coming
        // from the history there is a stack to pop; arriving by a pasted
        // link there is not, and the way out is the house.
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
        title: const Text('Corrigir compra'),
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => switch (state) {
          AsyncLoading() when !state.hasValue => const Center(
            child: CircularProgressIndicator(),
          ),
          AsyncError(:final error) when !state.hasValue => _ErrorBody(
            purchaseId: widget.purchaseId,
            error: error,
          ),
          _ => _body(context, state.value!),
        },
      ),
    );
  }

  Widget _body(BuildContext context, EditPurchaseState loaded) {
    _seed(loaded);

    final stores = ref.watch(storeViewModelProvider);
    final options = ref.watch(newPurchaseViewModelProvider);
    final items = _items!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DateField(
          value: _date!,
          today: _today,
          enabled: !_saving,
          onChanged: (date) => setState(() => _date = date),
        ),
        const SizedBox(height: 12),
        _StoreField(
          stores: stores.value ?? const IList<Store>.empty(),
          value: _storeId,
          enabled: !_saving,
          onChanged: (id) => setState(() => _storeId = id),
          onCreate: () async {
            final created = await NewStoreDialog.show(context, ref);
            if (!mounted || created?.id == null) return;
            setState(() => _storeId = created!.id);
          },
        ),
        const Divider(height: 32),
        for (final item in items)
          PurchaseItemRow(
            key: ValueKey(item.id),
            item: item,
            onEdit: _saving ? () {} : () => _editItem(context, item, options),
            onRemove: _saving ? () {} : () => _removeItem(item),
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
              formatMoney(_total(items)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('save-correction'),
          onPressed: _saving ? null : () => _save(context),
          child: Text(_saving ? 'Salvando...' : 'Salvar correção'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('delete-purchase'),
          onPressed: _saving ? null : () => _delete(context),
          child: const Text('Apagar compra'),
        ),
      ],
    );
  }

  /// Fills the three editable fields from what was loaded — once per version
  /// of the purchase. Called from `build`, so it assigns directly instead of
  /// going through `setState`: a `setState` during a build is the assertion
  /// "setState() or markNeedsBuild() called during build".
  void _seed(EditPurchaseState loaded) {
    if (_seededFrom == loaded.detail.purchase.id && _items != null) return;
    _seededFrom = loaded.detail.purchase.id;
    _date = loaded.detail.purchase.date;
    _storeId = loaded.detail.purchase.storeId;
    _items = loaded.detail.items;
  }

  static Money _total(IList<PurchaseItem> items) =>
      items.fold(const Money(0), (sum, item) => sum + item.paid);

  Future<void> _editItem(
    BuildContext context,
    PurchaseItem item,
    AsyncValue<IList<ProductOption>> options,
  ) async {
    final corrected = await PurchaseItemEditDialog.show(
      context,
      item: item,
      options: options.value ?? const IList<ProductOption>.empty(),
      onRemove: () => _removeItem(item),
    );
    if (!mounted || corrected == null) return;

    setState(() {
      _items = _items!
          .map((line) => line.id == corrected.id ? corrected : line)
          .toIList();
    });
  }

  /// A removed line simply is NOT in the list any more — that is how "tirei o
  /// item da compra" reaches the ViewModel without a third state.
  void _removeItem(PurchaseItem item) =>
      setState(() => _items = _items!.removeWhere((l) => l.id == item.id));

  Future<void> _save(BuildContext context) async {
    final storeId = _storeId;
    final messenger = ScaffoldMessenger.of(context);
    if (storeId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Escolha o mercado.')),
      );
      return;
    }

    // Captured BEFORE the await: after it this context may be gone.
    final router = GoRouter.of(context);
    final canPop = context.canPop();

    setState(() => _saving = true);
    final outcome = await ref
        .read(editPurchaseViewModelProvider(widget.purchaseId).notifier)
        .save(
          purchaseDate: _date!,
          storeId: storeId,
          items: _items!,
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
      case CorrectionFailed(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case CorrectionSaved(:final capAlert):
        messenger.showSnackBar(
          const SnackBar(content: Text('Correção salva.')),
        );
        // A correction can push the month across a cut too — the same dialog
        // screen 3 uses. There is no repeat warning here: `handoff §H14` puts
        // that on screen 3 and nowhere else, and correcting a purchase of
        // three weeks ago has no repetition to decide.
        // `context` here is the Builder's, not the State's, so the `mounted`
        // above does not speak for it.
        if (capAlert != null && context.mounted) {
          await showWarnings(context, [capAlert.message]);
        }
        _leave(router, canPop: canPop);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar esta compra?'),
        content: const Text(
          'Os itens que esta compra tirou da lista voltam para ela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final canPop = context.canPop();

    setState(() => _saving = true);
    final outcome = await ref
        .read(editPurchaseViewModelProvider(widget.purchaseId).notifier)
        .delete();
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case null:
        return;
      case CorrectionFailed(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      // A deletion only ever drops the month, so it has nothing to warn
      // about — `capAlert` is always null on this path.
      case CorrectionSaved():
        messenger.showSnackBar(
          const SnackBar(content: Text('Compra apagada.')),
        );
        _leave(router, canPop: canPop);
    }
  }

  /// Back to the history — `pop`, the pair of the `push` the history does.
  /// A `goNamed` would stack a second history over the one already below.
  void _leave(GoRouter router, {required bool canPop}) {
    // What is behind is stale by exactly this correction.
    ref.invalidate(purchaseHistoryViewModelProvider);
    if (canPop) {
      router.pop();
    } else {
      router.goNamed(RouteNames.purchaseHistory);
    }
  }
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.purchaseId, required this.error});

  final String purchaseId;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      // The raw exception NEVER reaches the screen — it goes to debugPrint.
      MessageView(translateFailure(AppFailure.from(error), 'abrir a compra')),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-purchase'),
          onPressed: () => ref
              .read(editPurchaseViewModelProvider(purchaseId).notifier)
              .refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
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
      // Two years back from the purchase itself, not from today: an old
      // purchase being corrected has to keep its own day reachable.
      firstDate: DateTime(value.year - 2),
      // A day after today CANNOT BE TAPPED, and `Purchase.checkDate` is
      // still the rule — a screen may never be the only guard (rule 11).
      lastDate: today,
    );
    if (picked != null) onChanged(picked);
  }
}

/// The store of a purchase being corrected, and it is NOT screen 3's field.
///
/// The difference is one line and it matters: this one keeps the purchase's
/// OWN store on the list even when it has since been deactivated. Screen 3
/// offers only active stores, and rightly — a new purchase may not be filed
/// under a market nobody uses. A correction that dropped the store the
/// purchase already has would blank the field and make "corrigir o valor
/// pago" impossible until someone reactivated a market they never meant to
/// touch.
class _StoreField extends StatelessWidget {
  const _StoreField({
    required this.stores,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCreate,
  });

  final IList<Store> stores;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final offered = stores
        .where((store) => store.active || store.id == value)
        .toIList();

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const ValueKey('field-store'),
            initialValue: offered.any((store) => store.id == value)
                ? value
                : null,
            decoration: const InputDecoration(labelText: 'Mercado'),
            items: [
              for (final store in offered)
                DropdownMenuItem(value: store.id, child: Text(store.name)),
            ],
            onChanged: enabled ? onChanged : null,
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
}
