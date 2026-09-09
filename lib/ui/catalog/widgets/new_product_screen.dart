import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/selling_choice.dart';
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
final class PickedProduct {
  const PickedProduct({
    required this.product,
    required this.registration,
    required this.type,
    required this.brand,
  });

  final Product product;
  final ProductRegistration registration;
  final ProductType type;
  final Brand? brand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickedProduct &&
          other.product == product &&
          other.registration == registration &&
          other.type == type &&
          other.brand == brand;

  @override
  int get hashCode => Object.hash(product, registration, type, brand);
}

/// What whoever opens screen 4 may ask of it.
///
/// It was born a plain `bool` in delivery 3 — "hand the chosen leaf back to
/// screen 3" — and becomes a class here, because the catalog maintenance
/// (H10) needs to say WHICH registration to open, and a bool holds one
/// answer. A null `state.extra` — the door from the menu — is the default of
/// both.
///
/// A `final class` and not a record (rule 16): the same shape as
/// [PickedProduct], which makes the trip back and lives right above.
final class NewProductRequest {
  const NewProductRequest({this.returnsSelection = false, this.registrationId});

  final bool returnsSelection;
  final String? registrationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewProductRequest &&
          other.returnsSelection == returnsSelection &&
          other.registrationId == registrationId;

  @override
  int get hashCode => Object.hash(returnsSelection, registrationId);
}

/// Screen 4 — the product registration, in five levels.
///
/// The form lives here and the I/O lives in the ViewModel. Every rule is
/// ASKED of the domain: whether two packagings are the same amount, whether
/// the selling mode allows a packaging list, what a valid measure is.
class NewProductScreen extends ConsumerStatefulWidget {
  const NewProductScreen({
    this.returnsSelection = false,
    this.registrationId,
    super.key,
  });

  /// True when screen 3 opened it to register something it is about to buy:
  /// saving then POPS with the chosen leaf instead of navigating to the list.
  /// Whoever arrives from the menu leaves it false and nothing changes.
  final bool returnsSelection;

  /// Arriving from the catalog maintenance (requirement 16), the screen opens
  /// with the registration LOADED, the fields above locked and the packagings
  /// it already has on the list — the "comprou o Omo de 2,3 kg tendo só o de
  /// 500 g" case. Null is the `[+Novo]` door, which opens blank.
  ///
  /// It fills the very `_opened`/`_existing` state H2 already wrote for the
  /// registration blocked by repetition: no second path.
  final String? registrationId;

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
    // for a product sold by piece, so the screen opens with somewhere to
    // type instead of an empty block and a button.
    _drafts = _drafts.add(PackagingDraft(id: _nextDraftId++));

    final registrationId = widget.registrationId;
    if (registrationId != null) {
      // After the frame, because it touches the ViewModel and shows a
      // SnackBar — neither belongs inside an initState.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromCatalog(registrationId),
      );
    }
  }

  /// The `≡` door: the maintenance screen said WHICH registration to open.
  ///
  /// It lands in the same `_opened`/`_existing` state H2 already wrote, so
  /// there is no second path through this screen. The failure is a branch of
  /// its own on purpose: a quiet null would open screen 4 BLANK — identical
  /// to `[+Novo]` — and the person would register again the very product they
  /// came to correct.
  Future<void> _openFromCatalog(String registrationId) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(catalogViewModelProvider.notifier)
        .openRegistration(registrationId);
    if (!mounted) return;

    switch (outcome) {
      // The reentrancy guard fired: nothing to show and nothing to open.
      case null:
        return;
      case RegistrationOpened(:final conflict):
        setState(() {
          _opened = conflict.registration;
          _existing = conflict.products;
          _sellingMode = conflict.registration.sellingMode;
          _typeId = conflict.registration.productTypeId;
          _brandId = conflict.registration.brandId;
          _descriptionController.text = conflict.registration.description;
          _conflict = null;
          // The magnitude of a line is the TYPE's, and here the type arrives
          // after the line does — `initState` opened the first one before
          // anybody knew which registration this is. Without carrying it
          // down, that line never parses: both fields filled and the caption
          // still reading "Use números maiores que zero", with the save
          // button dead. `_baseUnit` reads `_typeId`, so it comes after it.
          final unit = _baseUnit;
          _drafts = _drafts.map((draft) => draft.withUnit(unit)).toIList();
        });
      case OpenRegistrationFailed(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
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
      // The grandeza comes from the type, so a type change can leave the
      // saved mode with no word to go by: `Peso` under a type of litres.
      _sellingMode = SellingChoice.of(_sellingMode, _baseUnit).mode;
      // The magnitude of every line is the type's, so a type change carries
      // the new one down to the lines already typed.
      final unit = _baseUnit;
      _drafts = _drafts.map((draft) => draft.withUnit(unit)).toIList();
    });
    _loadDescriptions();
    _checkIdentity();
  }

  /// The grandeza on screen right now, or null while no type is chosen. It
  /// reads `_typeId`, so it must be called AFTER the field is written.
  BaseUnit? get _baseUnit {
    final options = ref.read(catalogViewModelProvider).value;
    return options == null ? null : _typeOf(options)?.baseUnit;
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
  ///
  /// **When the registration in the way is DEACTIVATED it reactivates first**,
  /// and the button says so. Adding leaves to a deactivated registration is
  /// writing what nobody will ever see — and until H10 the only way out
  /// offered was to leave the screen, with the receipt still in hand.
  Future<void> _openConflict() async {
    final conflict = _conflict;
    if (conflict == null) return;

    var registration = conflict.registration;
    if (!registration.active) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _saving = true);
      final error = await ref
          .read(catalogViewModelProvider.notifier)
          .reactivateRegistration(registration);
      if (!mounted) return;
      setState(() => _saving = false);

      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      registration = registration.reactivated();
    }

    setState(() {
      _opened = registration;
      _existing = conflict.products;
      _sellingMode = registration.sellingMode;
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
      final outcome = await notifier.save(
        registration: registration,
        packagings: _packagings,
      );
      switch (outcome) {
        // The reentrancy guard fired: nothing was written, so nothing is
        // said and nothing is left. Undoing `_saving` is what keeps the
        // button clickable — without it the screen trades one bug for a
        // frozen button.
        case null:
          if (!mounted) return;
          setState(() => _saving = false);
          return;
        case RegistrationSaved(:final saved):
          error = null;
          registration = saved.registration;
          written = saved.products;
        case RegistrationSaveFailed(:final message):
          error = message;
          written = const IList<Product>.empty();
      }
    } else {
      registration = opened;
      final outcome = await notifier.addPackagings(
        registrationId: opened.id!,
        packagings: _packagings,
      );
      switch (outcome) {
        case null:
          if (!mounted) return;
          setState(() => _saving = false);
          return;
        case PackagingsAdded(:final products):
          error = null;
          written = products;
        case AddPackagingsFailed(:final message):
          error = message;
          written = const IList<Product>.empty();
      }
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
      // Whoever PUSHED this screen gets it back: the catalog maintenance
      // opens it to create a registration, to add a packaging and from the
      // pencil of a registration, and `go` would leave the person on the
      // shopping list, three taps away from the list they were tidying up.
      // With no stack — a typed URL, which is also how the tests mount this
      // screen — the list stays the exit, as R11 asks.
      if (router.canPop()) {
        router.pop();
        return;
      }
      router.go(Routes.shoppingList);
      return;
    }
    // `pop`, never `go`: screen 3 is underneath with a purchase on it, and
    // `go` would replace the route and take the draft off the screen.
    router.pop<PickedProduct>(_picked(registration, written, options, type));
  }

  /// Which leaf goes back to screen 3: the one registered LAST.
  ///
  /// Until the layout review of 08/09/2026 a radio on each line answered
  /// "which one am I buying now" — a naked circle on a card, in the middle of
  /// a screen that is the REGISTRATION and not the purchase. It left, and the
  /// last packaging typed is the answer: swapping it in screen 3's selector
  /// is one tap.
  ///
  /// The match is by `totalContent`, which is the natural key of a packaging
  /// inside a registration: the unique index of the schema is
  /// `product (product_registration_id, total_content)`.
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

    final marked = _packagings.isEmpty ? null : _packagings.last;
    if (marked == null) {
      // Nothing was typed: the screen is the maintenance path over a product
      // that already has its packagings.
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
  ) => PickedProduct(
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
            // And with no type there is no grandeza: the loose choice has no
            // word left, so the mode falls back to `Unidade`.
            _sellingMode = SellingChoice.of(_sellingMode, null).mode;
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
              : 'Unidade: ${type.baseUnit.magnitudeNoun} (vem do tipo)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _SellingModeField(
          baseUnit: type?.baseUnit,
          value: SellingChoice.of(_sellingMode, type?.baseUnit),
          enabled: !_locked && !_saving,
          onChanged: (choice) => setState(() => _sellingMode = choice.mode),
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
          child: AppTextField(
            key: const ValueKey('field-description'),
            controller: _descriptionController,
            enabled: !_locked && !_saving,
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
            active: conflict.registration.active,
            onOpen: _saving ? null : _openConflict,
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
          const SizedBox(height: 4),
          Text(
            'Cada embalagem vira um produto, com preço e histórico próprios.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (type == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Escolha o tipo do produto primeiro.'),
            )
          else ...[
            for (final draft in _drafts)
              PackagingRow(
                key: ValueKey(draft.id),
                draft: draft,
                baseUnit: type.baseUnit,
                duplicate: _isDuplicate(draft),
                enabled: !_saving && _conflict == null,
                onChanged: (updated) => setState(() {
                  _drafts = _drafts.replace(_drafts.indexOf(draft), updated);
                }),
                onRemoved: () => setState(() {
                  _drafts = _drafts.remove(draft);
                }),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar outra embalagem'),
              // It is blocked while the identity is taken: a line built here
              // would be born inside a registration that will not be saved.
              onPressed: _saving || _conflict != null
                  ? null
                  : () => setState(() {
                      final draft = PackagingDraft(
                        id: _nextDraftId++,
                        // The magnitude is the type's; there is nothing to
                        // choose on the line.
                        unit: _baseUnit,
                      );
                      _drafts = _drafts.add(draft);
                    }),
            ),
          ],
          // What is already registered comes AFTER the lines being typed: the
          // line one types must not slide down as the product piles up
          // packagings. Only the maintenance path ever fills this list.
          if (_existing.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Collapsed, and without the check icon it used to carry: six
            // ticked lines under the ones being typed read as a checklist
            // waiting to be answered, when they are only "you already have
            // these".
            ExpansionTile(
              key: const ValueKey('existing-packagings'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                _existing.length == 1
                    ? 'Já cadastrada neste produto (1)'
                    : 'Já cadastradas neste produto (${_existing.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              children: [
                for (final product in _existing)
                  ListTile(
                    dense: true,
                    title: Text(product.packaging?.label ?? ''),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 24),
        if (_blockReason case final reason?) ...[
          Text(
            reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              // Red only for what IS a mistake. A screen that opens with an
              // empty line and paints "falta completar" in error colour is
              // scolding before anyone typed a character.
              color: _hasDuplicate
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
  ///
  /// It never writes a zero: "Salvar 0 produtos" on a dead button reads as a
  /// broken screen, and what is missing is said by [_blockReason] instead.
  String get _saveLabel {
    if (_saving) return 'Salvando...';
    if (_soldByWeight) return 'Salvar produto';

    final count = _packagings.length;
    return count > 1 ? 'Salvar $count produtos' : 'Salvar produto';
  }

  /// Why the button is dead, in the words of whoever is looking at it — and
  /// only for what this block owns. What is said elsewhere on the screen (no
  /// type chosen, identity taken) is not repeated down here.
  String? get _blockReason {
    if (_saving || _soldByWeight) return null;
    if (_typeId == null || (_conflict != null && !_locked)) return null;
    if (_hasDuplicate) return 'Há duas embalagens iguais na lista.';

    final incomplete = _drafts.length - _packagings.length;
    if (incomplete == 0) {
      return _packagings.isEmpty ? 'Acrescente ao menos uma embalagem.' : null;
    }
    return incomplete == 1
        ? 'Falta completar 1 embalagem.'
        : 'Faltam completar $incomplete embalagens.';
  }
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
    required this.baseUnit,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  /// Null while no type is chosen: the grandeza belongs to the type, so until
  /// there is one only `Unidade` can be taken.
  final BaseUnit? baseUnit;

  final SellingChoice value;
  final bool enabled;
  final ValueChanged<SellingChoice> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Vendido:'),
      const SizedBox(width: 8),
      Expanded(
        child: SegmentedButton<SellingChoice>(
          // No check icon: the labels plus the icon do not fit the 390 pt of
          // an iPhone 12, and the filled segment already says which one is
          // taken.
          showSelectedIcon: false,
          // Only the words this magnitude can take, never all four: a type
          // has ONE bulk word — weight, volume or length — and `Unidade`.
          // Four segments squeeze the widest label to 35 pt at 390 pt, which
          // is narrower than the word it has to write.
          segments: [
            for (final choice in SellingChoice.values)
              if (choice.isAvailableFor(baseUnit))
                ButtonSegment(value: choice, label: Text(choice.label)),
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
  const _ConflictWarning({
    required this.packagingCount,
    required this.active,
    required this.onOpen,
  });

  final int packagingCount;

  /// Whether the registration in the way is on. Deactivated, the button
  /// reactivates before opening — and says so.
  final bool active;

  final VoidCallback? onOpen;

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
            Text(_sentence, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const ValueKey('open-conflict'),
              onPressed: onOpen,
              child: Text(
                active
                    ? 'Abrir e acrescentar embalagem'
                    : 'Reativar e acrescentar embalagem',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The deactivated sentence carries no destination: the button is right
  /// there, and "reative-o na manutenção do cadastro" was a detour.
  String get _sentence {
    if (!active) return 'Esse produto já existe, mas está desativado.';
    return packagingCount == 1
        ? 'Esse produto já está cadastrado, com 1 embalagem.'
        : 'Esse produto já está cadastrado, com $packagingCount embalagens.';
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
