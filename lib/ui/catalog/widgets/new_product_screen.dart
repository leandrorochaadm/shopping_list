import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/message_view.dart';
import '../view_model/catalog_view_model.dart';
import 'new_brand_dialog.dart';
import 'new_category_dialog.dart';
import 'new_product_type_dialog.dart';
import 'packaging_row.dart';

/// What screen 4 hands back to screen 3: everything a `ProductOption` needs.
///
/// All four, and not the leaf alone: screen 3 has only the list of options it
/// loaded when it opened, and the type and the brand of a product registered
/// a moment ago are not in it. Going to fetch them would be a round trip in
/// the middle of a purchase — and screen 4 already holds the four in hand.
typedef PickedProduct = ({
  Product product,
  ProductRegistration registration,
  ProductType type,
  Brand? brand,
});

/// Screen 4 — the product registration, in five levels.
///
/// The form lives here and the I/O lives in the ViewModel. Every rule is
/// ASKED of the domain: whether two packagings are the same amount, whether
/// the selling mode allows a packaging list, what a valid measure is.
class NewProductScreen extends ConsumerStatefulWidget {
  const NewProductScreen({this.returnsSelection = false, super.key});

  /// True when screen 3 opened it to register something it is about to buy:
  /// saving then POPS with the chosen leaf instead of navigating to the list.
  /// Whoever arrives from the menu leaves it false and nothing changes.
  final bool returnsSelection;

  @override
  ConsumerState<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends ConsumerState<NewProductScreen> {
  final _descriptionController = TextEditingController();

  String? _categoryId;
  String? _typeId;
  String? _brandId;
  SellingMode _sellingMode = SellingMode.byPiece;

  IList<PackagingDraft> _drafts = const IList.empty();
  int? _selectedDraftId;
  var _nextDraftId = 1;

  /// The registration that already holds the typed identity, if any: the
  /// warning, and the block on saving.
  RegistrationConflict? _conflict;

  /// Set once `[ Abrir e acrescentar embalagem ]` is taken: the fields above
  /// come filled and LOCKED, and the packagings that already exist are on
  /// screen. What was being typed comes along — that is the whole point.
  ProductRegistration? _opened;
  IList<Product> _existing = const IList.empty();

  IList<String> _descriptions = const IList.empty();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The first line is already there: the wireframe's list is never empty
    // for a product sold by piece, and the radio has to have somewhere to be.
    _drafts = _drafts.add(PackagingDraft(id: _nextDraftId++));
    _selectedDraftId = _drafts.first.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _soldByWeight => _sellingMode == SellingMode.byWeight;

  bool get _locked => _opened != null;

  ProductType? _typeOf(CatalogOptions options) {
    for (final type in options.types) {
      if (type.id == _typeId) return type;
    }
    return null;
  }

  /// The packagings this screen would save: the lines that parse, in order.
  IList<Packaging> get _packagings => _soldByWeight
      ? const IList.empty()
      : _drafts
            .map((draft) => draft.packaging)
            .whereType<Packaging>()
            .toIList();

  /// A line is a duplicate when another line — or a packaging ALREADY SAVED
  /// under this registration — holds the same amount. By content, not by
  /// text: `1 × 0,35 L` matches `350 ml`.
  bool _isDuplicate(PackagingDraft draft) {
    final packaging = draft.packaging;
    if (packaging == null) return false;

    for (final other in _drafts) {
      if (other.id == draft.id) continue;
      final theirs = other.packaging;
      if (theirs != null && theirs.hasSameContentAs(packaging)) {
        // Only the LATER line is flagged, so a pair does not light up twice.
        if (_drafts.indexOf(other) < _drafts.indexOf(draft)) return true;
      }
    }
    for (final product in _existing) {
      final theirs = product.packaging;
      if (theirs != null && theirs.hasSameContentAs(packaging)) return true;
    }
    return false;
  }

  bool get _hasDuplicate => _drafts.any(_isDuplicate);

  /// What blocks the save, in the order the screen explains it.
  bool get _canSave {
    if (_saving || _typeId == null) return false;
    // The identity is taken and this is not the "add a packaging" path.
    if (_conflict != null && !_locked) return false;
    if (_soldByWeight) return !_locked;
    return _packagings.isNotEmpty &&
        _packagings.length == _drafts.length &&
        !_hasDuplicate;
  }

  void _onTypeChanged(String? id) {
    setState(() {
      _typeId = id;
      _conflict = null;
      // The measure of every line belongs to the type's family, so a type
      // change invalidates the units already chosen.
      final unit = _impliedUnit;
      _drafts = _drafts.map((draft) => draft.withUnit(unit)).toIList();
    });
    _loadDescriptions();
    _checkIdentity();
  }

  /// The unit when the type leaves no choice — a type counted by unit has a
  /// single measure and no dropdown, so nothing on screen could ever set it.
  MeasureUnit? get _impliedUnit {
    final options = ref.read(catalogViewModelProvider).value;
    if (options == null) return null;

    final measures = _typeOf(options)?.measures;
    return measures != null && measures.length == 1 ? measures.first : null;
  }

  Future<void> _loadDescriptions() async {
    final typeId = _typeId;
    if (typeId == null) return;

    final descriptions = await ref
        .read(catalogViewModelProvider.notifier)
        .descriptionsFor(productTypeId: typeId, brandId: _brandId);
    if (!mounted) return;
    setState(() => _descriptions = descriptions);
  }

  /// Asks whether type + brand + description is taken. It runs when the
  /// description loses focus and whenever type or brand change — the warning
  /// is meant to arrive BEFORE any packaging is listed.
  Future<void> _checkIdentity() async {
    final typeId = _typeId;
    if (typeId == null || _locked) return;

    final conflict = await ref
        .read(catalogViewModelProvider.notifier)
        .checkIdentity(
          productTypeId: typeId,
          brandId: _brandId,
          description: _descriptionController.text,
        );
    if (!mounted) return;
    setState(() => _conflict = conflict);
  }

  /// `[ Abrir e acrescentar embalagem ]` — the way out of the block, and what
  /// keeps it from being a dead end. What was typed does not get lost: the
  /// line being built goes down into the loaded list.
  void _openConflict() {
    final conflict = _conflict;
    if (conflict == null) return;

    setState(() {
      _opened = conflict.registration;
      _existing = conflict.products;
      _sellingMode = conflict.registration.sellingMode;
      _conflict = null;
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final options = ref.read(catalogViewModelProvider).value;
    final typeId = _typeId;
    if (typeId == null || options == null) return;
    final type = _typeOf(options);
    if (type == null) return;

    setState(() => _saving = true);
    final notifier = ref.read(catalogViewModelProvider.notifier);
    final opened = _opened;

    final String? error;
    ProductRegistration? registration;
    IList<Product> written;

    if (opened == null) {
      registration = ProductRegistration(
        productTypeId: typeId,
        brandId: _brandId,
        description: _descriptionController.text,
        sellingMode: _sellingMode,
      );
      final result = await notifier.save(
        registration: registration,
        packagings: _packagings,
      );
      error = result.error;
      registration = result.saved?.registration ?? registration;
      written = result.saved?.products ?? const IList<Product>.empty();
    } else {
      registration = opened;
      final result = await notifier.addPackagings(
        registrationId: opened.id!,
        packagings: _packagings,
      );
      error = result.error;
      written = result.products;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Saving ALWAYS leaves this screen — a registration saved twice is the
    // failure this avoids.
    messenger.showSnackBar(const SnackBar(content: Text('Produto salvo.')));

    if (!widget.returnsSelection) {
      router.go(Routes.shoppingList);
      return;
    }
    // `pop`, never `go`: screen 3 is underneath with a purchase on it, and
    // `go` would replace the route and take the draft off the screen.
    router.pop<PickedProduct>(
      _picked(registration, written, options, type),
    );
  }

  /// Which leaf the radio marked, and it comes from a DIFFERENT place in each
  /// of the three paths — `_selectedDraftId` numbers the rows being typed, it
  /// is not a database id. The match is by `totalContent`, which is the
  /// natural key of a packaging inside a registration: the unique index of
  /// the schema is `product (product_registration_id, total_content)`.
  PickedProduct? _picked(
    ProductRegistration registration,
    IList<Product> written,
    CatalogOptions options,
    ProductType type,
  ) {
    // Sold by weight there is no packaging and no radio: the leaf is the only
    // one the registration has.
    if (_soldByWeight) {
      final leaf = written.firstOrNull ?? _existing.firstOrNull;
      return leaf == null ? null : _option(leaf, registration, options, type);
    }

    final marked = _drafts
        .where((draft) => draft.id == _selectedDraftId)
        .firstOrNull
        ?.packaging;
    if (marked == null) {
      // The radio sits on a packaging that ALREADY existed — nothing came
      // back from the database for it, because nothing was written.
      final leaf = _existing.firstOrNull ?? written.firstOrNull;
      return leaf == null ? null : _option(leaf, registration, options, type);
    }

    for (final leaf in [...written, ..._existing]) {
      if (leaf.packaging?.totalContent == marked.totalContent) {
        return _option(leaf, registration, options, type);
      }
    }
    return null;
  }

  PickedProduct _option(
    Product leaf,
    ProductRegistration registration,
    CatalogOptions options,
    ProductType type,
  ) => (
    product: leaf,
    registration: registration,
    type: type,
    // Null is "Sem marca" (decision B2) — a real answer.
    brand: options.brands.where((brand) => brand.id == _brandId).firstOrNull,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo produto'),
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
        builder: (context) => switch (state) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError() => _RetryView(
            onRetry: () =>
                ref.read(catalogViewModelProvider.notifier).refresh(),
          ),
          AsyncValue(:final value?) => _form(context, value),
        },
      ),
    );
  }

  Widget _form(BuildContext context, CatalogOptions options) {
    final type = _typeOf(options);

    return ListView(
      // Scrollable in every state, so the screen behaves the same with the
      // keyboard up on a small phone.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CategoryField(
          categories: options.categories,
          value: _categoryId,
          enabled: !_locked && !_saving,
          onChanged: (id) => setState(() {
            _categoryId = id;
            // The type list is filtered by category, so the chosen type may
            // no longer be in it.
            _typeId = null;
            _conflict = null;
          }),
          onCreate: () async {
            final created = await NewCategoryDialog.show(context, ref);
            if (!mounted || created == null) return;
            setState(() => _categoryId = created.id);
          },
        ),
        const SizedBox(height: 12),
        _TypeField(
          types: options.types
              .where(
                (type) => _categoryId == null || type.categoryId == _categoryId,
              )
              .toIList(),
          value: _typeId,
          enabled: !_locked && !_saving,
          onChanged: _onTypeChanged,
          onCreate: () async {
            final created = await NewProductTypeDialog.show(context, ref);
            if (!mounted || created == null) return;
            setState(() => _categoryId = created.categoryId);
            _onTypeChanged(created.id);
          },
        ),
        const SizedBox(height: 8),
        // The base unit belongs to the TYPE, never to the product: two
        // products of the same type with different units would stop that
        // type's consumption from adding up.
        Text(
          type == null
              ? 'Unidade: escolha o tipo do produto primeiro'
              : 'Unidade: ${_baseUnitLabel(type.baseUnit)} (vem do tipo)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _SellingModeField(
          value: _sellingMode,
          enabled: !_locked && !_saving,
          onChanged: (mode) => setState(() => _sellingMode = mode),
        ),
        const SizedBox(height: 16),
        _BrandField(
          brands: options.brands,
          value: _brandId,
          enabled: !_locked && !_saving,
          onChanged: (id) {
            setState(() {
              _brandId = id;
              _conflict = null;
            });
            _loadDescriptions();
            _checkIdentity();
          },
          onCreate: () async {
            final created = await NewBrandDialog.show(context, ref);
            if (!mounted || created == null) return;
            setState(() => _brandId = created.id);
            _loadDescriptions();
            _checkIdentity();
          },
        ),
        const SizedBox(height: 12),
        Focus(
          // The warning is meant to arrive when the description LEAVES the
          // field, which is what the wireframe says and what keeps a round
          // trip off every keystroke.
          onFocusChange: (hasFocus) {
            if (!hasFocus) _checkIdentity();
          },
          child: TextField(
            key: const ValueKey('field-description'),
            controller: _descriptionController,
            enabled: !_locked && !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              helperText: 'Separa "zero" de "original" no mesmo tipo e marca.',
              helperMaxLines: 2,
            ),
          ),
        ),
        if (_descriptions.isNotEmpty && !_locked) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final description in _descriptions)
                ActionChip(
                  label: Text(description),
                  onPressed: _saving
                      ? null
                      : () {
                          _descriptionController.text = description;
                          _checkIdentity();
                        },
                ),
            ],
          ),
        ],
        if (_conflict case final conflict?) ...[
          const SizedBox(height: 16),
          _ConflictWarning(
            packagingCount: conflict.products.length,
            onOpen: _openConflict,
          ),
        ],
        if (_locked) ...[
          const SizedBox(height: 16),
          Text(
            'Acrescentando embalagem a um produto que já existe.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
        // Sold by weight: the packaging list disappears from the screen.
        // Quantity is what the PURCHASE asks for, not the registration.
        if (!_soldByWeight) ...[
          const Divider(height: 32),
          Text(
            'Embalagens deste produto',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_existing.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final product in _existing)
              ListTile(
                dense: true,
                leading: const Icon(Icons.check),
                title: Text(product.packaging?.label ?? ''),
                subtitle: const Text('já cadastrada'),
              ),
          ],
          if (type == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Escolha o tipo do produto primeiro.'),
            )
          else ...[
            // One RadioGroup around the whole list: which packaging is being
            // bought right now is a single answer, and the group is what says
            // so to the accessibility tree.
            RadioGroup<int>(
              groupValue: _selectedDraftId,
              // Always live: RadioGroup requires a callback, and disabling
              // happens on each Radio through PackagingRow's `enabled`.
              onChanged: (id) => setState(() => _selectedDraftId = id),
              child: Column(
                children: [
                  for (final draft in _drafts)
                    PackagingRow(
                      key: ValueKey(draft.id),
                      draft: draft,
                      measures: type.measures,
                      duplicate: _isDuplicate(draft),
                      enabled: !_saving && _conflict == null,
                      onChanged: (updated) => setState(() {
                        _drafts = _drafts.replace(
                          _drafts.indexOf(draft),
                          updated,
                        );
                      }),
                      onRemoved: () => setState(() {
                        _drafts = _drafts.remove(draft);
                        // The radio never ends up empty.
                        if (_selectedDraftId == draft.id) {
                          _selectedDraftId = _drafts.firstOrNull?.id;
                        }
                      }),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar embalagem'),
              // It is blocked while the identity is taken: a line built here
              // would be born inside a registration that will not be saved.
              onPressed: _saving || _conflict != null
                  ? null
                  : () => setState(() {
                      final draft = PackagingDraft(
                        id: _nextDraftId++,
                        // The unit chosen on the previous line comes
                        // suggested: it is almost always the same one.
                        unit: _drafts.lastOrNull?.unit ?? _impliedUnit,
                      );
                      _drafts = _drafts.add(draft);
                      _selectedDraftId ??= draft.id;
                    }),
            ),
          ],
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('save'),
          onPressed: _canSave ? _save : null,
          child: Text(_saveLabel),
        ),
      ],
    );
  }

  /// Each line becomes a product of its own, with its own price and history —
  /// which is why the button says how many are about to be born.
  String get _saveLabel {
    if (_saving) return 'Salvando...';
    if (_soldByWeight) return 'Salvar produto';

    final count = _packagings.length;
    return count == 1 ? 'Salvar 1 produto' : 'Salvar $count produtos';
  }

  static String _baseUnitLabel(BaseUnit unit) => switch (unit) {
    BaseUnit.kilogram => 'quilo',
    BaseUnit.liter => 'litro',
    BaseUnit.unit => 'unidade',
  };
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCreate,
  });

  final IList<Category> categories;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: const ValueKey('field-category'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: 'Categoria',
            hintText: categories.isEmpty ? 'Cadastre a primeira' : null,
          ),
          items: [
            for (final category in categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(
                  category.active
                      ? category.name
                      : '${category.name} (desativada)',
                ),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Nova categoria',
        onPressed: enabled ? onCreate : null,
      ),
    ],
  );
}

class _TypeField extends StatelessWidget {
  const _TypeField({
    required this.types,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCreate,
  });

  final IList<ProductType> types;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: const ValueKey('field-type'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: 'Tipo',
            hintText: types.isEmpty ? 'Cadastre o primeiro' : null,
          ),
          items: [
            for (final type in types)
              DropdownMenuItem(
                value: type.id,
                child: Text(
                  type.active ? type.name : '${type.name} (desativado)',
                ),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Novo tipo',
        onPressed: enabled ? onCreate : null,
      ),
    ],
  );
}

class _BrandField extends StatelessWidget {
  const _BrandField({
    required this.brands,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onCreate,
  });

  final IList<Brand> brands;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String?>(
          key: const ValueKey('field-brand'),
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Marca'),
          items: [
            // "Sem marca" is a real answer and not missing data (decision B2):
            // ground beef has no brand, and the null is what says so.
            const DropdownMenuItem(child: Text('Sem marca')),
            for (final brand in brands)
              DropdownMenuItem(
                value: brand.id,
                child: Text(
                  brand.active ? brand.name : '${brand.name} (desativada)',
                ),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Nova marca',
        onPressed: enabled ? onCreate : null,
      ),
    ],
  );
}

class _SellingModeField extends StatelessWidget {
  const _SellingModeField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final SellingMode value;
  final bool enabled;
  final ValueChanged<SellingMode> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Vendido:'),
      const SizedBox(width: 8),
      Expanded(
        child: SegmentedButton<SellingMode>(
          segments: const [
            ButtonSegment(value: SellingMode.byWeight, label: Text('A peso')),
            ButtonSegment(value: SellingMode.byPiece, label: Text('Por peça')),
          ],
          selected: {value},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
        ),
      ),
    ],
  );
}

class _ConflictWarning extends StatelessWidget {
  const _ConflictWarning({required this.packagingCount, required this.onOpen});

  final int packagingCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              packagingCount == 1
                  ? 'Esse produto já está cadastrado, com 1 embalagem.'
                  : 'Esse produto já está cadastrado, com $packagingCount '
                        'embalagens.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onOpen,
              child: const Text('Abrir e acrescentar embalagem'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry});

  final Future<String?> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(
        child: MessageView('Não foi possível carregar as listas do cadastro.'),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton(
          onPressed: onRetry,
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}
