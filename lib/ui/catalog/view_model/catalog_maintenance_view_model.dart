import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../data/repositories/shopping_list/shopping_list_repository.dart';
import '../../../data/repositories/store/store_repository.dart';
import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/catalog_maintenance.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/store.dart';
import '../../core/error_translation.dart';

/// The six catalogs of decision 23 — four of them named, plus the two halves
/// of the product. It is the list of the screen's selector, and the order here
/// is the order there.
enum CatalogKind {
  category('Categorias', 'a categoria'),
  productType('Tipos de produto', 'o tipo'),
  brand('Marcas', 'a marca'),
  registration('Cadastros de produto', 'o cadastro'),
  packaging('Embalagens', 'a embalagem'),
  store('Mercados', 'o mercado');

  const CatalogKind(this.label, this.noun);

  /// What the selector reads — pt-BR, plural, because it names a list.
  final String label;

  /// The catalog with its article, for the duplicate guard's sentence.
  final String noun;
}

/// Everything the maintenance screen lists, loaded together: the screen swaps
/// catalogs without going to the database, and the duplicate guard of any one
/// of them needs its whole list anyway.
///
/// A `final class` with `==`/`hashCode` over the six fields, and not a record
/// (rule 16). The six `IList`s already compare by content on their own; what
/// would be missing is the `==` of the class that holds them, and without it
/// `AsyncData<CatalogMaintenanceState>` compares by reference — selector,
/// search, filter and the open list would repaint on every action, including
/// the ones that changed nothing.
final class CatalogMaintenanceState {
  const CatalogMaintenanceState({
    required this.categories,
    required this.types,
    required this.brands,
    required this.registrations,
    required this.products,
    required this.stores,
  });

  final IList<Category> categories;
  final IList<ProductType> types;
  final IList<Brand> brands;
  final IList<ProductRegistration> registrations;
  final IList<Product> products;
  final IList<Store> stores;

  CatalogMaintenanceState copyWith({
    IList<Category>? categories,
    IList<ProductType>? types,
    IList<Brand>? brands,
    IList<ProductRegistration>? registrations,
    IList<Product>? products,
    IList<Store>? stores,
  }) => CatalogMaintenanceState(
    categories: categories ?? this.categories,
    types: types ?? this.types,
    brands: brands ?? this.brands,
    registrations: registrations ?? this.registrations,
    products: products ?? this.products,
    stores: stores ?? this.stores,
  );

  /// How many leaves a type has, counted IN MEMORY over what `build()` already
  /// loaded — the other half of [canChangeBaseUnit]. A round trip to count
  /// what is already in hand would be a round trip for nothing.
  int productCountOfType(String typeId) {
    final registrationIds = {
      for (final entry in registrations)
        if (entry.productTypeId == typeId) entry.id,
    };
    return products
        .where((leaf) => registrationIds.contains(leaf.productRegistrationId))
        .length;
  }

  /// The registration a leaf belongs to — what `isEffectivelyActiveIn` needs,
  /// and what the screen asks in order to grey out a leaf whose registration
  /// is the one that was deactivated.
  ProductRegistration? registrationOf(Product leaf) => registrations
      .where((entry) => entry.id == leaf.productRegistrationId)
      .firstOrNull;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogMaintenanceState &&
          other.categories == categories &&
          other.types == types &&
          other.brands == brands &&
          other.registrations == registrations &&
          other.products == products &&
          other.stores == stores);

  @override
  int get hashCode =>
      Object.hash(categories, types, brands, registrations, products, stores);
}

/// Screen `/catalog` — H10, the story that tidies up the vocabulary that was
/// improvised in an aisle.
///
/// One ViewModel for the six catalogs, because the screen is one (decision 4).
final class CatalogMaintenanceViewModel
    extends AsyncNotifier<CatalogMaintenanceState> {
  /// Guards the WRITES. The one read this class has gets a flag of its own,
  /// for the same reason the CatalogViewModel's reads do: sharing would let a
  /// count in flight block the save button.
  bool _running = false;
  bool _counting = false;

  @override
  Future<CatalogMaintenanceState> build() async {
    final catalog = ref.watch(catalogRepositoryProvider);
    final stores = ref.watch(storeRepositoryProvider);

    // Started together, awaited together: six round trips in sequence would
    // be six times the wait on a phone.
    final categories = catalog.fetchCategories();
    final types = catalog.fetchTypes();
    final brands = catalog.fetchBrands();
    final registrations = catalog.fetchRegistrations();
    final products = catalog.fetchProducts();
    final allStores = stores.fetchAll();

    return CatalogMaintenanceState(
      categories: await categories,
      types: await types,
      brands: await brands,
      registrations: await registrations,
      products: await products,
      stores: await allStores,
    );
  }

  /// Reloads the six lists. Returns null on success, or the sentence for the
  /// SnackBar.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      state = const AsyncLoading<CatalogMaintenanceState>();

      final next = await build();
      if (!ref.mounted) return null;

      state = AsyncData(next);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar os cadastros');
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<CatalogMaintenanceState>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  // ── The four named catalogs ────────────────────────────────────────────

  /// Renames one of the FOUR catalogs that have a name.
  ///
  /// There is no generic `rename(kind, id, name)` for the six: a product
  /// registration has no name — it has a triple identity — and a packaging has
  /// neither, it has content. One method taking a [CatalogKind] would have to
  /// open a `switch` and call three different guards, which is the `switch`
  /// AND the three methods, under a name that lies about two of them.
  Future<String?> renameNamed(CatalogKind kind, String id, String name) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      // The rule lives in the entity: a name made of blanks never travels.
      switch (kind) {
        case CatalogKind.category:
          final entry = _find(current.categories, id);
          if (entry == null) return _missing(kind);
          final renamed = entry.copyWith(name: Category(name: name).name);
          final conflict = findNameConflict(
            current.categories,
            name,
            ignoringId: id,
          );
          if (conflict != null) return nameConflictMessage(conflict, kind.noun);
          return await _writeCategory(renamed);

        case CatalogKind.brand:
          final entry = _find(current.brands, id);
          if (entry == null) return _missing(kind);
          final renamed = entry.copyWith(name: Brand(name: name).name);
          final conflict = findNameConflict(
            current.brands,
            name,
            ignoringId: id,
          );
          if (conflict != null) return nameConflictMessage(conflict, kind.noun);
          return await _writeBrand(renamed);

        case CatalogKind.productType:
          final entry = _find(current.types, id);
          if (entry == null) return _missing(kind);
          final renamed = entry.copyWith(
            name: ProductType(
              name: name,
              categoryId: entry.categoryId,
              baseUnit: entry.baseUnit,
            ).name,
          );
          final conflict = findNameConflict(
            current.types,
            name,
            ignoringId: id,
          );
          if (conflict != null) return nameConflictMessage(conflict, kind.noun);
          return await _writeType(renamed);

        case CatalogKind.store:
          final entry = _find(current.stores, id);
          if (entry == null) return _missing(kind);
          final renamed = entry.copyWith(name: Store(name: name).name);
          final conflict = findNameConflict(
            current.stores,
            name,
            ignoringId: id,
          );
          if (conflict != null) return nameConflictMessage(conflict, kind.noun);
          return await _writeStore(renamed);

        case CatalogKind.registration:
        case CatalogKind.packaging:
          // Neither has a name. Reaching here is a screen bug, not a user's.
          return 'Este cadastro não é editado por nome.';
      }
    } on BlankName catch (e) {
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, 'renomear o cadastro');
    } finally {
      _running = false;
    }
  }

  /// Moving a type to another category. The destination has to be ACTIVE:
  /// filing a type under a category nobody sees is filing it nowhere.
  Future<String?> reclassifyType(String typeId, String categoryId) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      final type = _find(current.types, typeId);
      if (type == null) return _missing(CatalogKind.productType);

      final category = _find(current.categories, categoryId);
      if (category == null || !category.active) {
        return 'Escolha uma categoria ativa.';
      }
      return await _writeType(type.copyWith(categoryId: categoryId));
    } on Object catch (e, st) {
      return translateError(e, st, 'reclassificar o tipo');
    } finally {
      _running = false;
    }
  }

  /// Changing a type's base unit — allowed only while the type has no product
  /// and no purchase, because after that it would convert the whole history
  /// between magnitudes.
  ///
  /// [purchaseCount] comes from `CatalogViewModel.purchaseCountsByType()`,
  /// which reads every type in one round trip; the product count is counted in
  /// memory, over the leaves `build()` already loaded.
  Future<String?> changeBaseUnit(
    String typeId,
    BaseUnit baseUnit, {
    required int purchaseCount,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      final type = _find(current.types, typeId);
      if (type == null) return _missing(CatalogKind.productType);

      if (!canChangeBaseUnit(
        productCount: current.productCountOfType(typeId),
        purchaseCount: purchaseCount,
      )) {
        throw const BaseUnitLocked();
      }
      return await _writeType(type.copyWith(baseUnit: baseUnit));
    } on BaseUnitLocked catch (e) {
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, 'trocar a unidade base');
    } finally {
      _running = false;
    }
  }

  // ── The product's two halves ───────────────────────────────────────────

  /// Editing a registration: description, brand and TYPE. Its guard is not a
  /// name — it is the triple identity, ignoring the row being edited — and the
  /// type only moves within [typesCompatibleWith].
  Future<String?> editRegistration(
    String id, {
    String? description,
    String? brandId,
    bool clearBrand = false,
    String? typeId,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      final entry = _findRegistration(current.registrations, id);
      if (entry == null) return _missing(CatalogKind.registration);

      final from = _find(current.types, entry.productTypeId);
      final to = typeId == null ? from : _find(current.types, typeId);
      if (to == null) return _missing(CatalogKind.productType);

      // Moving between base units would make the destination's total add
      // volume to weight, silently and with no way back.
      if (from != null && to.baseUnit != from.baseUnit) {
        throw IncompatibleBaseUnit(
          productLabel: entry.description.isEmpty
              ? from.name
              : entry.description,
          typeName: to.name,
          from: from.baseUnit,
          to: to.baseUnit,
        );
      }

      final edited = entry.copyWith(
        description: description,
        brandId: clearBrand ? '' : brandId,
        productTypeId: typeId,
      );

      // The duplicate guard of a registration is `hasSameIdentityAs`, over the
      // triple — and it has to ignore the row being edited, or correcting a
      // typo in its own description would report a conflict with itself.
      final conflict = edited.conflictIn(
        current.registrations.where((other) => other.id != id),
      );
      if (conflict != null) {
        return conflict.active
            ? 'Já existe esse produto cadastrado.'
            : 'Esse produto já existe, mas está desativado.';
      }

      final written = await ref
          .read(catalogRepositoryProvider)
          .updateRegistration(edited);
      if (!ref.mounted) return null;

      _replaceRegistration(written);
      return null;
    } on IncompatibleBaseUnit catch (e) {
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, 'salvar o cadastro');
    } finally {
      _running = false;
    }
  }

  /// The "350 ml digitado como 35 ml" of the wireframe: one leaf's packaging,
  /// corrected. The collision guard is content, not name — a registration may
  /// only hold one leaf of a given size.
  Future<String?> correctPackaging(
    String productId,
    Packaging packaging,
  ) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      final leaf = _findProduct(current.products, productId);
      if (leaf == null) return _missing(CatalogKind.packaging);

      final corrected = leaf.copyWith(packaging: packaging);
      final collides = current.products.any(
        (other) => other.id != productId && other.hasSameContentAs(corrected),
      );
      if (collides) {
        return 'Este cadastro já tem uma embalagem com esse conteúdo.';
      }

      final written = await ref
          .read(catalogRepositoryProvider)
          .updateProduct(corrected);
      if (!ref.mounted) return null;

      _replaceProduct(written);
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'corrigir a embalagem');
    } finally {
      _running = false;
    }
  }

  // ── Deactivating and reactivating ──────────────────────────────────────

  /// The transition of decision 19, for any of the six. Nothing is deleted:
  /// renaming holds for the whole history, and deactivating has a way back.
  ///
  /// **Deactivating a TYPE that is on the list is not done here** — the screen
  /// asks [countListItemsOfType] first, shows what `TypeInUseOnList` derives,
  /// and only the confirmation calls [deactivateTypeAndRemoveItems].
  Future<String?> setActive(CatalogKind kind, String id, bool active) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      switch (kind) {
        case CatalogKind.category:
          final entry = _find(current.categories, id);
          if (entry == null) return _missing(kind);
          return await _writeCategory(
            active ? entry.reactivated() : entry.deactivated(),
          );

        case CatalogKind.brand:
          final entry = _find(current.brands, id);
          if (entry == null) return _missing(kind);
          return await _writeBrand(
            active ? entry.reactivated() : entry.deactivated(),
          );

        case CatalogKind.productType:
          final entry = _find(current.types, id);
          if (entry == null) return _missing(kind);
          return await _writeType(
            active ? entry.reactivated() : entry.deactivated(),
          );

        case CatalogKind.store:
          final entry = _find(current.stores, id);
          if (entry == null) return _missing(kind);
          return await _writeStore(
            active ? entry.reactivated() : entry.deactivated(),
          );

        case CatalogKind.registration:
          final entry = _findRegistration(current.registrations, id);
          if (entry == null) return _missing(kind);
          final written = await ref
              .read(catalogRepositoryProvider)
              .updateRegistration(
                active ? entry.reactivated() : entry.deactivated(),
              );
          if (!ref.mounted) return null;
          _replaceRegistration(written);
          return null;

        case CatalogKind.packaging:
          final leaf = _findProduct(current.products, id);
          if (leaf == null) return _missing(kind);
          final written = await ref
              .read(catalogRepositoryProvider)
              .updateProduct(active ? leaf.reactivated() : leaf.deactivated());
          if (!ref.mounted) return null;
          _replaceProduct(written);
          return null;
      }
    } on Object catch (e, st) {
      return translateError(e, st, 'salvar o cadastro');
    } finally {
      _running = false;
    }
  }

  /// How many OPEN list items carry this type — the number the warning is
  /// built from.
  ///
  /// **It returns `int?`, not `String?`: it is a READ, not an action.** And
  /// unlike the reads of `CatalogViewModel` it cannot answer with a quiet
  /// zero: the number IS the warning, and a count that did not load looks
  /// exactly like "nenhum" — which would deactivate the type WITHOUT asking,
  /// removing items nobody ever saw. `null` is "não deu para conferir", and
  /// the screen refuses the deactivation with that sentence.
  ///
  /// It has a guard of its own, not `_running`: sharing would block the save
  /// button during a read nobody is waiting for.
  Future<int?> countListItemsOfType(String typeId) async {
    if (_counting) return null;
    _counting = true;
    try {
      return await ref
          .read(shoppingListRepositoryProvider)
          .countOpenItemsOfType(typeId);
    } on Object catch (e, st) {
      translateError(e, st, 'conferir a lista');
      return null;
    } finally {
      _counting = false;
    }
  }

  /// The confirmation given: deactivate the type AND take its open items off
  /// the list. Deliberately irreversible — reactivating the type does not
  /// bring the item back.
  ///
  /// [today] exists for the test: the screen passes nothing and the clock
  /// enters the system HERE (rule 9), never in a widget or an entity.
  Future<String?> deactivateTypeAndRemoveItems(
    String typeId, {
    DateTime? today,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      final current = state.value;
      if (current == null) return 'Aguarde os cadastros carregarem.';

      final type = _find(current.types, typeId);
      if (type == null) return _missing(CatalogKind.productType);

      final written = await ref
          .read(catalogRepositoryProvider)
          .updateType(type.deactivated());
      if (!ref.mounted) return null;

      // The repository swallows the echo of every row it removed, on its own:
      // the writer here IS the list's repository, so the banner is its
      // problem and this ViewModel never sees it.
      await ref
          .read(shoppingListRepositoryProvider)
          .removeOpenItemsOfType(typeId, dayOf(today ?? DateTime.now()));
      if (!ref.mounted) return null;

      _replaceType(written);
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'desativar o tipo');
    } finally {
      _running = false;
    }
  }

  // ── The four writes, written once each ─────────────────────────────────

  Future<String?> _writeCategory(Category entry) async {
    final written = await ref
        .read(catalogRepositoryProvider)
        .updateCategory(entry);
    if (!ref.mounted) return null;

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          categories: _replaced(current.categories, written, (e) => e.id),
        ),
      );
    }
    return null;
  }

  Future<String?> _writeBrand(Brand entry) async {
    final written = await ref
        .read(catalogRepositoryProvider)
        .updateBrand(entry);
    if (!ref.mounted) return null;

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          brands: _replaced(current.brands, written, (e) => e.id),
        ),
      );
    }
    return null;
  }

  Future<String?> _writeType(ProductType entry) async {
    final written = await ref.read(catalogRepositoryProvider).updateType(entry);
    if (!ref.mounted) return null;

    _replaceType(written);
    return null;
  }

  Future<String?> _writeStore(Store entry) async {
    final written = await ref.read(storeRepositoryProvider).update(entry);
    if (!ref.mounted) return null;

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          stores: _replaced(current.stores, written, (e) => e.id),
        ),
      );
    }
    return null;
  }

  void _replaceType(ProductType written) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(types: _replaced(current.types, written, (e) => e.id)),
    );
  }

  void _replaceRegistration(ProductRegistration written) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        registrations: _replaced(current.registrations, written, (e) => e.id),
      ),
    );
  }

  void _replaceProduct(Product written) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        products: _replaced(current.products, written, (e) => e.id),
      ),
    );
  }

  static IList<T> _replaced<T>(
    IList<T> list,
    T written,
    String? Function(T entry) idOf,
  ) => list
      .map((entry) => idOf(entry) == idOf(written) ? written : entry)
      .toIList();

  static T? _find<T extends CatalogEntry>(IList<T> list, String id) =>
      list.where((entry) => entry.id == id).firstOrNull;

  static ProductRegistration? _findRegistration(
    IList<ProductRegistration> list,
    String id,
  ) => list.where((entry) => entry.id == id).firstOrNull;

  static Product? _findProduct(IList<Product> list, String id) =>
      list.where((entry) => entry.id == id).firstOrNull;

  /// The row went away between the screen drawing it and the tap landing —
  /// the other phone deactivated it, or the list is stale.
  static String _missing(CatalogKind kind) =>
      'Não encontrei ${kind.noun}. Atualize a lista.';
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final catalogMaintenanceViewModelProvider =
    AsyncNotifierProvider<CatalogMaintenanceViewModel, CatalogMaintenanceState>(
      CatalogMaintenanceViewModel.new,
      retry: (retryCount, error) => null,
    );
