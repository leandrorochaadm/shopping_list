import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/ui/catalog/widgets/new_product_screen.dart';

/// The owners of a code the tests of the `#1a` panel and of the pantry check
/// use, mirroring `CatalogRepositoryLocal`. The fake starts with no code and a
/// write awaited before `pumpWidget` freezes the fake clock, so the tests
/// return these through an override of `findOwners`.
const colaCode = '7894900011517';
const foilCode = '7891000100103';
const coffeeCode = '7894900530018';

/// Refrigerante Coca-Cola original, 350 ml.
final colaOwner = BarcodeOwner(
  product: Product(
    id: 'prod-1',
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 350,
      baseUnit: BaseUnit.milliliter,
    ),
  ),
  registration: ProductRegistration(
    id: 'reg-1',
    productTypeId: 'type-1',
    brandId: 'brand-1',
    description: 'original',
    sellingMode: SellingMode.byPiece,
  ),
  type: ProductType(
    id: 'type-1',
    name: 'Refrigerante',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.milliliter,
  ),
  brand: Brand(id: 'brand-1', name: 'Coca-Cola'),
);

/// The type the pantry of the fake does NOT show.
final foilOwner = BarcodeOwner(
  product: Product(
    id: 'prod-6',
    productRegistrationId: 'reg-3',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 3000,
      baseUnit: BaseUnit.centimeter,
    ),
  ),
  registration: ProductRegistration(
    id: 'reg-3',
    productTypeId: 'type-6',
    description: '',
    sellingMode: SellingMode.byPiece,
  ),
  type: ProductType(
    id: 'type-6',
    name: 'Papel-alumínio',
    categoryId: 'cat-3',
    baseUnit: BaseUnit.centimeter,
  ),
);

/// The last line of the pantry (Mercearia), for the scroll test.
final coffeeOwner = BarcodeOwner(
  product: Product(
    id: 'prod-9',
    productRegistrationId: 'reg-9',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 500,
      baseUnit: BaseUnit.gram,
    ),
  ),
  registration: ProductRegistration(
    id: 'reg-9',
    productTypeId: 'type-5',
    description: 'tradicional',
    sellingMode: SellingMode.byPiece,
  ),
  type: ProductType(
    id: 'type-5',
    name: 'Café',
    categoryId: 'cat-4',
    baseUnit: BaseUnit.gram,
  ),
);

PickedProduct pickedFrom(BarcodeOwner owner) => PickedProduct(
  product: owner.product,
  registration: owner.registration,
  type: owner.type,
  brand: owner.brand,
);
