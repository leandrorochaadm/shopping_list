/// PocketBase collection and field names, as constants, so no `_remote` writes
/// a bare string. Every value matches the migrations in `pocketbase/pb_migrations/`.
library;

abstract final class PbCollections {
  static const category = 'category';
  static const brand = 'brand';
  static const store = 'store';
  static const productType = 'product_type';
  static const productRegistration = 'product_registration';
  static const product = 'product';
  static const productBarcode = 'product_barcode';
  static const shoppingListItem = 'shopping_list_item';
  static const purchase = 'purchase';
  static const purchaseItem = 'purchase_item';
  static const listWriteOff = 'list_write_off';
  static const spendingCap = 'spending_cap';
  static const spendingCapAlert = 'spending_cap_alert';
  static const users = 'users';
  static const purchaseItemTotals = 'purchase_item_totals'; // view
}

abstract final class PbFields {
  static const id = 'id';
  static const user = 'user';
  static const created = 'created';
  static const name = 'name';
  static const active = 'active';
  static const description = 'description';
  static const code = 'code';
  static const categoryId = 'category_id';
  static const productTypeId = 'product_type_id';
  static const brandId = 'brand_id';
  static const productRegistrationId = 'product_registration_id';
  static const productId = 'product_id';
  static const storeId = 'store_id';
  static const purchaseId = 'purchase_id';
  static const purchaseItemId = 'purchase_item_id';
  static const shoppingListItemId = 'shopping_list_item_id';
  static const preferredRegistrationId = 'preferred_registration_id';
  static const totalContent = 'total_content';
  static const purchaseDate = 'purchase_date';
  static const createdAt = 'created_at';
  static const enteredOn = 'entered_on';
  static const fulfilledOn = 'fulfilled_on';
  static const removedOn = 'removed_on';
  static const effectiveFrom = 'effective_from';
  static const month = 'month';
  static const purchaseCount = 'purchase_count';

  // Back-relations (expand of children).
  static const purchaseItemViaPurchaseId = 'purchase_item_via_purchase_id';
  static const listWriteOffViaPurchaseItemId =
      'list_write_off_via_purchase_item_id';
  static const productBarcodeViaProductId = 'product_barcode_via_product_id';
  static const productViaProductRegistrationId =
      'product_via_product_registration_id';
}
