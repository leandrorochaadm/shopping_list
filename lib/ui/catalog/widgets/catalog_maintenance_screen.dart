import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/name_normalization.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/selling_choice.dart';
import '../../../routing/routes.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/widgets/message_view.dart';
import '../../store/view_model/store_view_model.dart';
import '../../store/widgets/new_store_dialog.dart';
import '../view_model/catalog_maintenance_view_model.dart';
import '../view_model/catalog_view_model.dart';
import 'catalog_entry_edit_dialog.dart';
import 'new_brand_dialog.dart';
import 'new_category_dialog.dart';
import 'new_product_screen.dart';
import 'new_product_type_dialog.dart';
import 'packaging_edit_dialog.dart';
import 'pick_registration_dialog.dart';
import 'product_type_edit_dialog.dart';
import 'registration_edit_dialog.dart';

/// `/catalog` — H10, the screen that tidies up the vocabulary improvised in
/// an aisle: rename, reclassify, deactivate and reactivate the six catalogs
/// of decision 23, and correct a packaging typed wrong.
///
/// One screen with a selector, and not six (decision 4): six entries in the
/// `≡` for six lists that share every rule would be six screens drifting
/// apart.
class CatalogMaintenanceScreen extends ConsumerStatefulWidget {
  const CatalogMaintenanceScreen({super.key});

  @override
  ConsumerState<CatalogMaintenanceScreen> createState() =>
      _CatalogMaintenanceScreenState();
}

class _CatalogMaintenanceScreenState
    extends ConsumerState<CatalogMaintenanceScreen> {
  final _searchController = TextEditingController();

  CatalogKind _kind = CatalogKind.category;
  String _query = '';
  bool _showInactive = false;

  /// Two taps would stack two dialogs, and the second would be answering
  /// about a list the first has already changed. It guards BOTH doors that
  /// open a dialog and then push screen 4 — the `+` of the AppBar and the
  /// pencil of a registration — hence `_busy` and not `_creating`: the pencil
  /// navigates too, and a double tap there could stack two copies of screen 4
  /// over the same list.
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogMaintenanceViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        // R11: in a standalone PWA there is no browser Back button.
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
        title: const Text('Manutenção do cadastro'),
        actions: [
          // A Builder, for the same reason the body already has one: it ties
          // the SnackBar to THIS screen's Scaffold, which is the convention
          // of `.claude/rules/ui-conventions.md`.
          Builder(
            builder: (context) => IconButton(
              key: const ValueKey('create-entry'),
              icon: const Icon(Icons.add),
              // The tooltip follows the selector: the button promises what
              // the list below it is showing, in the gender of that catalog.
              tooltip: _kind.createLabel,
              // Off while there is nothing loaded: the packaging door needs
              // the six lists in hand, and a `+` that silently does nothing
              // is the tap the person repeats.
              onPressed: _busy || !state.hasValue
                  ? null
                  : () => _create(context),
            ),
          ),
        ],
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  DropdownButtonFormField<CatalogKind>(
                    key: const ValueKey('field-kind'),
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: 'Cadastro'),
                    items: [
                      // A dropdown and not six segments: six of them do not
                      // fit a phone in portrait.
                      for (final kind in CatalogKind.values)
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                    ],
                    onChanged: (kind) => setState(() => _kind = kind ?? _kind),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('field-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('show-inactive'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _showInactive,
                    title: const Text('Mostrar desativados'),
                    onChanged: (value) =>
                        setState(() => _showInactive = value ?? false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await ref
                      .read(catalogMaintenanceViewModelProvider.notifier)
                      .refresh();
                  if (error != null) {
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  }
                },
                child: switch (state) {
                  AsyncLoading() when !state.hasValue => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  AsyncError(:final error) when !state.hasValue => _ErrorBody(
                    error: error,
                  ),
                  _ => _list(context, state.value!),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The `+` of the AppBar: creates one row of the catalog the selector is
  /// showing. It does not write anything itself — every write already has a
  /// door, and a second door would be a second duplicate guard (decision B3
  /// has one answer, not two).
  Future<void> _create(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      // All six, and not only the four dialogs: screen 4 reads the
      // `CatalogViewModel` with `ref.watch`, and watching a provider that is
      // ALREADY created does not run its `build()` again. Skipping the
      // reload for the two doors to screen 4 would open it with the lists as
      // they were BEFORE this screen deactivated something — a registration
      // born under a category the person turned off ten seconds earlier.
      final loaded = _kind == CatalogKind.store
          ? await _reloadStores(messenger)
          : await _reloadCatalog(messenger);
      if (!mounted || !context.mounted || !loaded) return;

      final created = await _openDoorOf(context);
      // The `context` here is the Builder's, not the State's: `mounted`
      // answers for one and `context.mounted` for the other, and the two
      // guards travel together everywhere in this file.
      if (!mounted || !created) return;

      // The three states are separate: the dialogs above wrote in the
      // CatalogViewModel and in the StoreViewModel, and neither of them is
      // the six lists this screen draws.
      final error = await ref
          .read(catalogMaintenanceViewModelProvider.notifier)
          .refresh();
      if (!mounted) return;
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Which door the `+` opens, and the whole difference between the six.
  ///
  /// It is a method of its own, and a switch STATEMENT and not an expression,
  /// so no `await` precedes the `context` it hands to the dialogs: inside a
  /// switch expression the analyzer reads every arm as living after the gap
  /// of the others, and `use_build_context_synchronously` fires on all five.
  ///
  /// True when something was created — which is what makes the six lists
  /// worth rereading.
  Future<bool> _openDoorOf(BuildContext context) async {
    switch (_kind) {
      case CatalogKind.category:
        return await NewCategoryDialog.show(context, ref) != null;
      case CatalogKind.productType:
        return await NewProductTypeDialog.show(context, ref) != null;
      case CatalogKind.brand:
        return await NewBrandDialog.show(context, ref) != null;
      case CatalogKind.store:
        return await NewStoreDialog.show(context, ref) != null;
      case CatalogKind.registration:
        return _openScreen4(context);
      case CatalogKind.packaging:
        return _openScreen4ForPackaging(context);
    }
  }

  /// The pencil of a registration, and the door it may hand back. Screen 4 is
  /// pushed from HERE and not from inside the dialog, because only whoever
  /// awaits the trip can redraw the list when it returns.
  ///
  /// It carries the SAME three obligations as [_create], and for the same
  /// reasons — it is the third door to screen 4, not a lesser one: the
  /// `_busy` guard, the [_reloadCatalog] (screen 4 WATCHES
  /// `CatalogViewModel`), and a reload failure that is SAID, not swallowed.
  Future<void> _editRegistration(
    BuildContext context,
    ProductRegistration entry,
    CatalogMaintenanceState loaded,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final id = await RegistrationEditDialog.show(
        context,
        registration: entry,
        types: loaded.types,
        brands: loaded.brands,
      );
      if (!mounted || id == null || !context.mounted) return;

      // Same reason as the two doors of `_create`: screen 4 watches the
      // catalog, and it must not open on lists this screen has already
      // changed.
      if (!await _reloadCatalog(messenger)) return;
      if (!mounted || !context.mounted) return;

      await _openScreen4(context, registrationId: id);
      if (!mounted) return;

      final error = await ref
          .read(catalogMaintenanceViewModelProvider.notifier)
          .refresh();
      if (!mounted) return;
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The three lists of `CatalogViewModel`, reloaded BEFORE the dialog — or
  /// screen 4 — opens. Three reasons, and every one of them is a visible bug
  /// without it: on this screen that provider may never have been read, and
  /// creating answers "Aguarde as listas carregarem." to the first tap; a
  /// category deactivated HERE would still read as active there, so the
  /// duplicate guard would say "já existe" where it owes a `[ Reativar ]`
  /// (decision B3); and screen 4 WATCHES this provider, so without the
  /// reload it opens its three selectors on the lists as they were before
  /// this screen touched them.
  ///
  /// Returns false when the reload failed, and the creation is cancelled.
  /// Not because there is nothing to show — `refresh` KEEPS the previous
  /// value on failure — but because that previous value is exactly what
  /// breaks B3: offering `[ Reativar ]` off a stale list is the bug this
  /// method exists to avoid, so a failed reload is a hard stop.
  ///
  /// A null answer is not proof of success: `refresh` shares `_running` with
  /// the three creates (`catalog_view_model.dart`), and a guarded call
  /// returns null having reloaded nothing. It is accepted — the only way to
  /// get there is tapping `+` during a pull-to-refresh, and the unique index
  /// of the database is still underneath.
  Future<bool> _reloadCatalog(ScaffoldMessengerState messenger) async {
    final error = await ref.read(catalogViewModelProvider.notifier).refresh();
    if (!mounted) return false;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    return true;
  }

  /// The stores. TWO of the three reasons of [_reloadCatalog] apply here, and
  /// the third does not: on this screen `storeViewModelProvider` may never
  /// have been read, and a store deactivated HERE would still read as active
  /// there, so the duplicate guard would say "já existe" where it owes a
  /// `[ Reativar ]` (decision B3). Screen 4 does not read the stores at all,
  /// so there is nothing to keep in step for it.
  ///
  /// The two notes at the end of [_reloadCatalog] hold unchanged: a failed
  /// reload is a hard stop, and a null answer is not proof of success.
  Future<bool> _reloadStores(ScaffoldMessengerState messenger) async {
    final error = await ref.read(storeViewModelProvider.notifier).refresh();
    if (!mounted) return false;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    return true;
  }

  /// The single door from this screen to screen 4. A registration is born
  /// there, in one transaction with its packagings
  /// (`saveRegistrationWithProducts`); writing a second door here would be a
  /// second identity guard for the same triple.
  ///
  /// With [registrationId] screen 4 opens ON that registration and only adds
  /// packagings — the very trip `RegistrationEditDialog` used to make from
  /// inside itself. Without it, screen 4 opens blank.
  ///
  /// `push`, never `go`: `go` would replace this screen, and Back would leave
  /// the catalog instead of returning to it. Screen 4 pops back on save
  /// (see `NewProductScreen._save`), and the `await` below is what resumes
  /// here afterwards.
  Future<bool> _openScreen4(
    BuildContext context, {
    String? registrationId,
  }) async {
    await context.push(
      Routes.newProduct,
      extra: NewProductRequest(registrationId: registrationId),
    );
    // Screen 4 pops with nothing, so there is no answer to read: the reload
    // is unconditional, and a cancelled trip simply redraws the same list.
    return true;
  }

  /// A packaging is a leaf OF a registration, so the question comes first and
  /// [_openScreen4] does the rest. This method is ONLY the question.
  Future<bool> _openScreen4ForPackaging(BuildContext context) async {
    // `requireValue`, not a null check: the `+` is disabled while the state
    // has no value, precisely so this method never has to answer a question
    // with silence. A guard here that returned false would BE the tap that
    // does nothing.
    final loaded = ref.read(catalogMaintenanceViewModelProvider).requireValue;

    final choices = [
      for (final entry in loaded.registrations)
        if (entry.active) _choiceOf(loaded, entry),
    ]..sort((a, b) => normalizeName(a.label).compareTo(normalizeName(b.label)));

    final id = await PickRegistrationDialog.show(
      context,
      choices: choices.toIList(),
    );
    if (!mounted || id == null) return false;
    if (!context.mounted) return false;

    return _openScreen4(context, registrationId: id);
  }

  /// One registration as the dropdown offers it. The TYPE goes in the label
  /// and the list of registrations does not need it: there the type is the
  /// subtitle of every row, and here the six catalogs are collapsed into one
  /// dropdown. Two registrations of different types read the same without it
  /// — "Omo" the powder and "Omo" the liquid — and the question this dialog
  /// asks would have two identical answers.
  ///
  /// The `if` is not a precaution: [_registrationTitle] ALREADY FALLS BACK to
  /// the type name when the registration has neither brand nor description,
  /// which is the ordinary shape of anything sold by weight. Appending the
  /// type blindly writes "Acém moído · Acém moído".
  static RegistrationChoice _choiceOf(
    CatalogMaintenanceState loaded,
    ProductRegistration entry,
  ) {
    final title = _registrationTitle(loaded, entry);
    final type = _typeNameOf(loaded, entry.productTypeId);
    return RegistrationChoice(
      id: entry.id!,
      label: title == type ? title : '$title · $type',
    );
  }

  Widget _list(BuildContext context, CatalogMaintenanceState loaded) {
    final rows = _rowsOf(context, loaded);
    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [MessageView('Nenhum cadastro encontrado.')],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final row in rows)
          ListTile(
            key: ValueKey('catalog-${row.id}'),
            title: Text(
              row.title,
              style: row.active
                  ? null
                  : TextStyle(color: Theme.of(context).disabledColor),
            ),
            subtitle: row.subtitle == null ? null : Text(row.subtitle!),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar ${row.title}',
              onPressed: () => row.onEdit(),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The chosen catalog, searched and filtered, in alphabetical order BY THE
  /// NORMALIZED NAME: `'Açougue'.compareTo('Bebidas')` compares code units,
  /// and the `ç` would land after the `z`.
  IList<_CatalogRow> _rowsOf(
    BuildContext context,
    CatalogMaintenanceState loaded,
  ) {
    final rows = switch (_kind) {
      CatalogKind.category => [
        for (final entry in loaded.categories)
          _CatalogRow(
            id: entry.id!,
            title: entry.name,
            active: entry.active,
            onEdit: () => CatalogEntryEditDialog.show(
              context,
              ref,
              kind: CatalogKind.category,
              entry: entry,
            ),
          ),
      ],
      CatalogKind.productType => [
        for (final entry in loaded.types)
          _CatalogRow(
            id: entry.id!,
            title: entry.name,
            subtitle: _typeSubtitle(loaded, entry),
            active: entry.active,
            onEdit: () => ProductTypeEditDialog.show(
              context,
              ref,
              type: entry,
              categories: loaded.categories,
            ),
          ),
      ],
      CatalogKind.brand => [
        for (final entry in loaded.brands)
          _CatalogRow(
            id: entry.id!,
            title: entry.name,
            active: entry.active,
            onEdit: () => CatalogEntryEditDialog.show(
              context,
              ref,
              kind: CatalogKind.brand,
              entry: entry,
            ),
          ),
      ],
      CatalogKind.registration => [
        for (final entry in loaded.registrations)
          _CatalogRow(
            id: entry.id!,
            title: _registrationTitle(loaded, entry),
            subtitle: _typeNameOf(loaded, entry.productTypeId),
            active: entry.active,
            onEdit: () => _editRegistration(context, entry, loaded),
          ),
      ],
      CatalogKind.packaging => [
        for (final leaf in loaded.products)
          _CatalogRow(
            id: leaf.id!,
            title: leaf.packaging?.label ?? _looseTitle(loaded, leaf),
            subtitle: _leafSubtitle(loaded, leaf),
            // A leaf whose REGISTRATION is off reads as off even with
            // `active: true` — `handoff §H10` is explicit that deactivating
            // the product deactivates its leaves, and D7 does it on the READ.
            active: _leafIsActive(loaded, leaf),
            onEdit: () => PackagingEditDialog.show(
              context,
              leaf: leaf,
              baseUnit: _baseUnitOfLeaf(loaded, leaf),
            ),
          ),
      ],
      CatalogKind.store => [
        for (final entry in loaded.stores)
          _CatalogRow(
            id: entry.id!,
            title: entry.name,
            active: entry.active,
            onEdit: () => CatalogEntryEditDialog.show(
              context,
              ref,
              kind: CatalogKind.store,
              entry: entry,
            ),
          ),
      ],
    };

    final normalized = normalizeName(_query);
    final visible =
        rows
            .where((row) => _showInactive || row.active)
            // The same normalization the duplicate guard uses: whoever types
            // "acem" finds "acém", on every screen.
            .where(
              (row) =>
                  normalized.isEmpty ||
                  normalizeName(row.title).contains(normalized) ||
                  normalizeName(row.subtitle ?? '').contains(normalized),
            )
            .toList()
          ..sort(
            (a, b) => normalizeName(a.title).compareTo(normalizeName(b.title)),
          );
    return visible.toIList();
  }

  static String? _typeSubtitle(
    CatalogMaintenanceState loaded,
    ProductType type,
  ) {
    final category = loaded.categories
        .where((c) => c.id == type.categoryId)
        .firstOrNull;
    return '${category?.name ?? 'Sem categoria'} · ${type.baseUnit.priceLabel}';
  }

  static String _registrationTitle(
    CatalogMaintenanceState loaded,
    ProductRegistration entry,
  ) {
    final brand = entry.brandId == null
        ? null
        : loaded.brands.where((b) => b.id == entry.brandId).firstOrNull;
    final parts = <String>[
      if (brand != null) brand.name,
      if (entry.description.isNotEmpty) entry.description,
    ];
    // A registration with neither brand nor description IS the type itself —
    // "Acém moído", sold by weight, is exactly that case.
    return parts.isEmpty
        ? _typeNameOf(loaded, entry.productTypeId)
        : parts.join(' ');
  }

  static String _typeNameOf(CatalogMaintenanceState loaded, String typeId) =>
      loaded.types.where((t) => t.id == typeId).firstOrNull?.name ?? '';

  static String? _leafSubtitle(CatalogMaintenanceState loaded, Product leaf) {
    final registration = loaded.registrationOf(leaf);
    if (registration == null) return null;
    return _registrationTitle(loaded, registration);
  }

  static bool _leafIsActive(CatalogMaintenanceState loaded, Product leaf) {
    final registration = loaded.registrationOf(leaf);
    return registration == null
        ? leaf.active
        : leaf.isEffectivelyActiveIn(registration);
  }

  /// The title of a leaf with no packaging: it is the loose product, and the
  /// word for it comes from the grandeza of its type — the SAME fallback
  /// `ProductOption.label` uses, which is why it lives in the enum.
  static String _looseTitle(CatalogMaintenanceState loaded, Product leaf) =>
      'Vendido por '
      '${SellingChoice.looseNameOf(_baseUnitOfLeaf(loaded, leaf)).toLowerCase()}';

  static BaseUnit _baseUnitOfLeaf(
    CatalogMaintenanceState loaded,
    Product leaf,
  ) {
    final registration = loaded.registrationOf(leaf);
    if (registration == null) return BaseUnit.unit;
    return loaded.types
            .where((t) => t.id == registration.productTypeId)
            .firstOrNull
            ?.baseUnit ??
        BaseUnit.unit;
  }
}

/// One line of whichever catalog is selected. It never leaves this file: it
/// is the screen's own shape for "a name, what is under it, and what the
/// pencil opens".
final class _CatalogRow {
  const _CatalogRow({
    required this.id,
    required this.title,
    required this.active,
    required this.onEdit,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onEdit;
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      // The raw exception NEVER reaches the screen — it goes to debugPrint.
      MessageView(
        translateFailure(AppFailure.from(error), 'abrir os cadastros'),
      ),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-catalog'),
          onPressed: () =>
              ref.read(catalogMaintenanceViewModelProvider.notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}
