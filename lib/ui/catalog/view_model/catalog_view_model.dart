import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../core/error_translation.dart';

/// The three lists screen 4 selects from. They load together because the
/// screen is unusable until all three have arrived, and one AsyncValue over
/// the three is one loading state instead of three.
/// `==` covers all three fields because this is the `T` of an AsyncNotifier:
/// Riverpod filters updates with `==`, and comparing by reference would
/// repaint screen 4 on every refresh (rule 8).
final class CatalogOptions {
  const CatalogOptions({
    required this.categories,
    required this.types,
    required this.brands,
  });

  final IList<Category> categories;
  final IList<ProductType> types;
  final IList<Brand> brands;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogOptions &&
          other.categories == categories &&
          other.types == types &&
          other.brands == brands;

  @override
  int get hashCode => Object.hash(categories, types, brands);

  /// Only the writes that replace exactly ONE of the three lists use this.
  /// Written by hand, like every other copyWith in the project.
  CatalogOptions copyWith({
    IList<Category>? categories,
    IList<ProductType>? types,
    IList<Brand>? brands,
  }) => CatalogOptions(
    categories: categories ?? this.categories,
    types: types ?? this.types,
    brands: brands ?? this.brands,
  );
}

/// How saving a registration ended. Two outcomes, and the payload rides on
/// the successful one — which is why this is a sealed type and not a
/// `String?` (rule 16).
///
/// The written rows travel back because screen 3 opened screen 4 to register
/// a product it was about to buy: without them it would have to reload the
/// whole catalog to find the leaf that was just created — a round trip in the
/// middle of a purchase, and the form blinking out while it happens.
sealed class RegistrationSaveOutcome {
  const RegistrationSaveOutcome();
}

final class RegistrationSaved extends RegistrationSaveOutcome {
  const RegistrationSaved(this.saved);

  final SavedRegistration saved;
}

final class RegistrationSaveFailed extends RegistrationSaveOutcome {
  const RegistrationSaveFailed(this.message);

  /// pt-BR, already translated — the raw exception never reaches a screen.
  final String message;
}

/// How adding packagings to an existing registration ended — the second half
/// of `[ Abrir e acrescentar embalagem ]`. Two outcomes, payload on success
/// (rule 16).
sealed class AddPackagingsOutcome {
  const AddPackagingsOutcome();
}

final class PackagingsAdded extends AddPackagingsOutcome {
  const PackagingsAdded(this.products);

  final IList<Product> products;
}

final class AddPackagingsFailed extends AddPackagingsOutcome {
  const AddPackagingsFailed(this.message);

  /// pt-BR, already translated.
  final String message;
}

/// A registration that already holds the typed identity, and the leaves it
/// already has — what `[ Abrir e acrescentar embalagem ]` needs to open.
final class RegistrationConflict {
  const RegistrationConflict({
    required this.registration,
    required this.products,
  });

  final ProductRegistration registration;
  final IList<Product> products;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistrationConflict &&
          other.registration == registration &&
          other.products == products;

  @override
  int get hashCode => Object.hash(registration, products);
}

/// The catalog itself — categories, types and brands — and every write screen
/// 4 and the `#1a` panel make against it.
///
/// It is not named after screen 4 because it has three consumers already: the
/// registration screen, the two dialogs the `#1a` panel reuses verbatim, and
/// the panel itself. H10 will be the fourth.
///
/// The FORM lives in the screen — what is selected, what is typed, which
/// packaging rows exist. What lives here is the I/O and the orchestration:
/// loading the three lists, creating a catalog entry on the spot, asking
/// whether the identity is taken, and the single transactional write.
final class CatalogViewModel extends AsyncNotifier<CatalogOptions> {
  /// Guards the WRITES. Reads have guards of their own further down: sharing
  /// one flag would let a duplicate check in flight block the save button,
  /// which is the opposite of what the guard is for.
  bool _running = false;

  /// Guards the two registration writes — `save` and `addPackagings` — and
  /// ONLY them. They shared `_running` with the three catalog creates until
  /// 29/08/2026, and the cost was silent: saving while a category dialog was
  /// still writing fell into the guard, and screen 4 read the empty answer as
  /// success. They keep sharing a flag with each other because they are the
  /// same action of screen 4.
  bool _writingRegistration = false;
  bool _checkingIdentity = false;
  bool _loadingDescriptions = false;
  bool _loadingCounts = false;
  bool _loadingLeaves = false;

  @override
  Future<CatalogOptions> build() async {
    final repository = ref.watch(catalogRepositoryProvider);

    // Started together, awaited together: three round trips in sequence would
    // be three times the wait on a phone.
    final categories = repository.fetchCategories();
    final types = repository.fetchTypes();
    final brands = repository.fetchBrands();

    return CatalogOptions(
      categories: await categories,
      types: await types,
      brands: await brands,
    );
  }

  /// Reloads the three lists. Returns null on success, or the sentence for
  /// the SnackBar.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<CatalogOptions>();

      final options = await build();
      if (!ref.mounted) return null;

      state = AsyncData(options);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar as listas');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<CatalogOptions>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// Creates a category and puts it in the list. Returns null on success, or
  /// the pt-BR sentence the dialog shows under its field.
  Future<String?> createCategory(String name) => _create(
    name: name,
    build: (name) => Category(name: name),
    existing: (options) => options.categories,
    write: (repository, entry) => repository.createCategory(entry),
    store: (options, created) =>
        options.copyWith(categories: options.categories.add(created)),
    action: 'salvar a categoria',
    noun: 'a categoria',
  );

  /// Creates a brand. Same shape as the category, different words — and the
  /// brand is a catalog of its own precisely because "Omo" and "OMO" typed on
  /// different days would split its price history in two.
  Future<String?> createBrand(String name) => _create(
    name: name,
    build: (name) => Brand(name: name),
    existing: (options) => options.brands,
    write: (repository, entry) => repository.createBrand(entry),
    store: (options, created) =>
        options.copyWith(brands: options.brands.add(created)),
    action: 'salvar a marca',
    noun: 'a marca',
  );

  /// Creates a product type: name, category and base unit, and nothing else.
  ///
  /// The name is unique across the WHOLE catalog and not per category — the
  /// type is the level the reports add up, and two "Leite" types would split
  /// that sum in half with nothing on screen explaining why.
  Future<String?> createType({
    required String name,
    required String categoryId,
    required BaseUnit baseUnit,
  }) => _create(
    name: name,
    build: (name) =>
        ProductType(name: name, categoryId: categoryId, baseUnit: baseUnit),
    existing: (options) => options.types,
    write: (repository, entry) => repository.createType(entry),
    store: (options, created) =>
        options.copyWith(types: options.types.add(created)),
    action: 'salvar o tipo',
    noun: 'o tipo',
  );

  /// The one create, written once. The three catalogs differ in their words
  /// and in which list they land in; the guard, the order (rule first, then
  /// I/O) and the error handling are the same three times, and three copies
  /// would be three places to fix.
  Future<String?> _create<T extends CatalogEntry>({
    required String name,
    required T Function(String name) build,
    required IList<T> Function(CatalogOptions options) existing,
    required Future<T> Function(CatalogRepository repository, T entry) write,
    required CatalogOptions Function(CatalogOptions options, T created) store,
    required String action,
    required String noun,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      // The rule lives in the entity: a name made of blanks never travels.
      final entry = build(name);

      // Never null in practice: screen 4 only paints the `[+Novo]` buttons
      // inside the AsyncData arm, so the three lists have arrived before any
      // of these dialogs can open. The null arm is here because a null list
      // is "no answer", not "no conflict" — and letting it through is how a
      // second "Omo" would be born.
      final options = state.value;
      if (options == null) return 'Aguarde as listas carregarem.';

      // The duplicate guard answers HERE — the unique index is the net
      // underneath, and a net is not an explanation.
      final conflict = findNameConflict(existing(options), name);
      if (conflict != null) return _conflictMessage(conflict, noun);

      final created = await write(ref.read(catalogRepositoryProvider), entry);
      if (!ref.mounted) return null;

      final current = state.value;
      if (current != null) state = AsyncData(store(current, created));
      return null;
    } on BlankName catch (e) {
      // A rule of the domain saying no is not a failure: nothing to log, and
      // the sentence is the entity's own.
      return e.message;
    } on Object catch (e, st) {
      return translateError(e, st, action);
    } finally {
      _running = false;
    }
  }

  /// Reactivates the type the `#1a` search found deactivated. It is the way
  /// out of decision B3: whoever misses a type does NOT create a second one
  /// with the same name — that would split in two the history the soft delete
  /// exists to preserve. Full maintenance is H10; this is the only path there
  /// is until then.
  Future<String?> reactivateType(ProductType type) async {
    if (_running) return null;
    _running = true;
    try {
      // The transition is the entity's (rule 7), never a copyWith spread
      // around a ViewModel.
      final written = await ref
          .read(catalogRepositoryProvider)
          .updateType(type.reactivated());
      if (!ref.mounted) return null;

      final options = state.value;
      if (options != null) {
        state = AsyncData(
          options.copyWith(
            types: options.types
                .map((entry) => entry.id == written.id ? written : entry)
                .toIList(),
          ),
        );
      }
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'reativar o tipo');
    } finally {
      _running = false;
    }
  }

  /// The count that orders the `#1a` panel while the search box is empty.
  ///
  /// An empty map on failure, not a sentence: order is a comfort, and a count
  /// that did not load is no reason to stop anyone from putting milk on the
  /// list. It has a guard of its own for the same reason `descriptionsFor`
  /// does — sharing `_running` with the writes would block the save button
  /// during a read nobody is waiting for.
  Future<IMap<String, int>> purchaseCountsByType() async {
    if (_loadingCounts) return const IMap.empty();
    _loadingCounts = true;
    try {
      return await ref
          .read(catalogRepositoryProvider)
          .fetchPurchaseCountsByType();
    } on Object catch (e, st) {
      translateError(e, st, 'buscar os tipos mais comprados');
      return const IMap.empty();
    } finally {
      _loadingCounts = false;
    }
  }

  /// Every leaf of a type, with its registration — what the item dialog
  /// offers as preferred brand and preferred packaging.
  ///
  /// Empty on failure, for the same reason as above: a list of packagings
  /// that did not load must not stop the quantity from being adjusted.
  Future<IList<TypeLeaf>> leavesOfType(String productTypeId) async {
    if (_loadingLeaves) return const IList.empty();
    _loadingLeaves = true;
    try {
      return await ref
          .read(catalogRepositoryProvider)
          .fetchLeavesOfType(productTypeId);
    } on Object catch (e, st) {
      translateError(e, st, 'buscar as embalagens deste tipo');
      return const IList.empty();
    } finally {
      _loadingLeaves = false;
    }
  }

  /// Decision B3: the guard sees the deactivated rows too, and the way out of
  /// a deactivated match is to REACTIVATE the one that exists — never to
  /// create a second one, which would split its history in two.
  ///
  /// **The sentence survives the `#1a` panel on purpose.** Inside the panel a
  /// deactivated type shows up in the search with a `[ Reativar ]` and the
  /// `[ + Criar "…" ]` is not even offered, so this sentence is never read
  /// there. Screen 4 does reach it, and will keep reaching it until H10:
  /// offering to reactivate from there would be H10 being born by accident
  /// inside H2.
  String _conflictMessage(CatalogEntry conflict, String noun) => conflict.active
      ? 'Já existe $noun ${conflict.name}.'
      : 'O cadastro ${conflict.name} existe, mas está desativado. '
            'Reative-o na manutenção do cadastro.';

  /// Asks whether type + brand + description is already taken, and brings the
  /// leaves of whatever it finds so the screen can say "com 4 embalagens".
  ///
  /// A failure here returns null rather than a sentence: this check is a
  /// COURTESY the screen pays before the save, and the unique index is what
  /// actually holds. Turning a lost connection into a block would keep a
  /// legitimate registration from being written.
  Future<RegistrationConflict?> checkIdentity({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    if (_checkingIdentity) return null;
    _checkingIdentity = true;
    try {
      final repository = ref.read(catalogRepositoryProvider);
      final registration = await repository.findRegistration(
        productTypeId: productTypeId,
        brandId: brandId,
        description: description,
      );
      if (registration?.id == null || !ref.mounted) return null;

      final products = await repository.fetchProductsOf(registration!.id!);
      if (!ref.mounted) return null;

      return RegistrationConflict(
        registration: registration,
        products: products,
      );
    } on Object catch (e, st) {
      translateError(e, st, 'conferir se o produto já existe');
      return null;
    } finally {
      _checkingIdentity = false;
    }
  }

  /// The descriptions already used under this type and this brand. Empty on
  /// failure, for the same reason as above: a suggestion that did not load is
  /// not a reason to stop a registration.
  Future<IList<String>> descriptionsFor({
    required String productTypeId,
    String? brandId,
  }) async {
    if (_loadingDescriptions) return const IList.empty();
    _loadingDescriptions = true;
    try {
      return await ref
          .read(catalogRepositoryProvider)
          .fetchDescriptions(productTypeId: productTypeId, brandId: brandId);
    } on Object catch (e, st) {
      translateError(e, st, 'buscar as descrições já usadas');
      return const IList.empty();
    } finally {
      _loadingDescriptions = false;
    }
  }

  /// Saves the registration and its packagings in ONE transaction.
  ///
  /// Returns the rows that were written, or the sentence for the SnackBar.
  /// The rows travel back because screen 3 needs the leaf it just created,
  /// with the id the database gave it.
  ///
  /// A `null` is the reentrancy guard of rule 14 saying "I did nothing" — it
  /// is not a third outcome, and it is never success.
  ///
  /// [packagings] is empty for a product sold by weight — the leaf still
  /// exists (decision B1), it simply has no packaging.
  Future<RegistrationSaveOutcome?> save({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  }) async {
    if (_writingRegistration) return null;
    _writingRegistration = true;
    try {
      // The two rules of the selling mode, asked before any I/O: by piece
      // with no packaging cannot convert a purchase, and by weight with one
      // means the screen kept state it should have dropped.
      registration.checkPackagings(packagings);

      final saved = await ref
          .read(catalogRepositoryProvider)
          .saveRegistrationWithProducts(
            registration: registration,
            packagings: packagings,
          );
      return RegistrationSaved(saved);
    } on MissingPackaging catch (e) {
      return RegistrationSaveFailed(e.message);
    } on UnexpectedPackaging catch (e) {
      return RegistrationSaveFailed(e.message);
    } on Object catch (e, st) {
      return RegistrationSaveFailed(translateError(e, st, 'salvar o produto'));
    } finally {
      _writingRegistration = false;
    }
  }

  /// Adds packagings to a registration that already exists — the second half
  /// of `[ Abrir e acrescentar embalagem ]`.
  Future<AddPackagingsOutcome?> addPackagings({
    required String registrationId,
    required IList<Packaging> packagings,
  }) async {
    if (_writingRegistration) return null;
    _writingRegistration = true;
    try {
      if (packagings.isEmpty) {
        return AddPackagingsFailed(const MissingPackaging().message);
      }

      final products = await ref
          .read(catalogRepositoryProvider)
          .addPackagings(
            registrationId: registrationId,
            packagings: packagings,
          );
      return PackagingsAdded(products);
    } on Object catch (e, st) {
      return AddPackagingsFailed(translateError(e, st, 'salvar a embalagem'));
    } finally {
      _writingRegistration = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final catalogViewModelProvider =
    AsyncNotifierProvider<CatalogViewModel, CatalogOptions>(
      CatalogViewModel.new,
      retry: (retryCount, error) => null,
    );
