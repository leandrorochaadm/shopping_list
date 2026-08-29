import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';

/// A registration and the leaves it was saved with — what one transaction
/// produced. It is not a DTO: both halves are the entities themselves, and
/// they travel together because the write that created them was single.
final class SavedRegistration {
  const SavedRegistration({required this.registration, required this.products});

  final ProductRegistration registration;
  final IList<Product> products;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedRegistration &&
          other.registration == registration &&
          other.products == products;

  @override
  int get hashCode => Object.hash(registration, products);
}

/// A leaf and the registration it belongs to — the pair the item dialog needs
/// in order to offer "marca preferida" and "embalagem preferida" of the SAME
/// type, without downloading the whole catalog.
final class TypeLeaf {
  const TypeLeaf({required this.product, required this.registration});

  final Product product;
  final ProductRegistration registration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeLeaf &&
          other.product == product &&
          other.registration == registration;

  @override
  int get hashCode => Object.hash(product, registration);
}

/// The five levels of the product catalog. I/O only: every conversion, every
/// duplicate check and every validation happens in `domain/` before a method
/// here is called.
abstract class CatalogRepository {
  /// The three lists screen 4 selects from. **Deactivated rows come too**
  /// (decision B3): the duplicate guard has to see them, and the screen is
  /// what greys them out.
  Future<IList<Category>> fetchCategories();

  Future<IList<ProductType>> fetchTypes();

  Future<IList<Brand>> fetchBrands();

  Future<Category> createCategory(Category category);

  Future<ProductType> createType(ProductType type);

  Future<Brand> createBrand(Brand brand);

  /// Writes a type back — today the only caller reactivates the deactivated
  /// type the `#1a` search found (decision B3: never a second one with the
  /// same name, which would split the history the soft delete exists to keep).
  /// Full maintenance is H10.
  Future<ProductType> updateType(ProductType type);

  /// How many purchase items each type already has — what orders the `#1a`
  /// panel when the search box is empty. The count comes from a view that
  /// only sums and groups; the decision of what to do with it is here.
  Future<IMap<String, int>> fetchPurchaseCountsByType();

  /// Every leaf of a type, with its registration — what the item dialog
  /// offers as preferred brand and preferred packaging.
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId);

  /// The identity guard against what is stored: type + brand + normalized
  /// description, with a null brand counting as a value. Returns the
  /// registration that already holds it, active or not, or null.
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  });

  /// The descriptions already used under this type and this brand, for the
  /// suggestion under the description field. It is an acceptance criterion,
  /// not a comfort: "orig." typed on a distracted day creates a second
  /// registration out of nothing.
  Future<IList<String>> fetchDescriptions({
    required String productTypeId,
    String? brandId,
  });

  /// The leaves a registration already has — what `[ Abrir e acrescentar
  /// embalagem ]` loads when a blocked registration is reopened.
  Future<IList<Product>> fetchProductsOf(String registrationId);

  /// Registration + N leaves in ONE transaction, through the Postgres
  /// function of the base migration. Two separate calls would leave an orphan
  /// registration with no leaf when the second one failed — and the duplicate
  /// guard would then block the user's own retry.
  ///
  /// [packagings] is empty for a product sold by weight: the leaf still
  /// exists (decision B1), with no packaging on it.
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  });

  /// Adds leaves to a registration that already exists — the second half of
  /// `[ Abrir e acrescentar embalagem ]`, and the "comprou o Omo de 2,3 kg
  /// tendo só o de 500 g" case of the wireframe.
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<Packaging> packagings,
  });
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => throw UnimplementedError(
    'catalogRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);
