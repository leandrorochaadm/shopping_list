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
import '../view_model/catalog_maintenance_view_model.dart';
import 'catalog_entry_edit_dialog.dart';
import 'packaging_edit_dialog.dart';
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
                  _ => _list(state.value!),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(CatalogMaintenanceState loaded) {
    final rows = _rowsOf(loaded);
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
  IList<_CatalogRow> _rowsOf(CatalogMaintenanceState loaded) {
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
            onEdit: () => RegistrationEditDialog.show(
              context,
              registration: entry,
              types: loaded.types,
              brands: loaded.brands,
            ),
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
