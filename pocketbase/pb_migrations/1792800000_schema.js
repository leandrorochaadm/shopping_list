/// <reference path="../pb_data/types.d.ts" />
// Schema of the 13 app collections. The server only stores types and enforces
// ownership; every business rule lives in the app domain.

// Owner rules: list, view and delete.
const OWNER = "user = @request.auth.id";
// Create: the owner sent is the logged-in user.
const CREATE_OWNER = '@request.auth.id != "" && @request.body.user = @request.auth.id';
// Update: the owner cannot change.
const UPDATE_OWNER = OWNER + " && @request.body.user:isset = false";

// A relation must point to a record of the same owner (create and update).
function requiredOnCreate(field) {
  return "@request.body." + field + ".user = @request.auth.id";
}
function requiredOnUpdate(field) {
  return "(@request.body." + field + ":isset = false || @request.body." + field + ".user = @request.auth.id)";
}
function optionalOnCreate(field) {
  return '(@request.body.' + field + ' = "" || @request.body.' + field + ".user = @request.auth.id)";
}
function optionalOnUpdate(field) {
  return "(@request.body." + field + ':isset = false || @request.body.' + field + ' = "" || @request.body.' + field + ".user = @request.auth.id)";
}

function userField() {
  return { name: "user", type: "relation", required: true, collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: true };
}
function autodates() {
  return [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];
}

migrate((app) => {
  // Saves one collection; `rel` lists [field, target, required, cascade].
  function make(name, fields, rels, indexes) {
    const relFields = [];
    const createRules = [];
    const updateRules = [];
    for (const [field, target, required, cascade] of rels) {
      relFields.push({
        name: field,
        type: "relation",
        required: required,
        collectionId: app.findCollectionByNameOrId(target).id,
        maxSelect: 1,
        cascadeDelete: cascade === true,
      });
      createRules.push(required ? requiredOnCreate(field) : optionalOnCreate(field));
      updateRules.push(required ? requiredOnUpdate(field) : optionalOnUpdate(field));
    }
    const collection = new Collection({
      type: "base",
      name: name,
      listRule: OWNER,
      viewRule: OWNER,
      createRule: [CREATE_OWNER].concat(createRules).join(" && "),
      updateRule: [UPDATE_OWNER].concat(updateRules).join(" && "),
      deleteRule: OWNER,
      fields: [userField()].concat(fields.before || [], relFields, fields.after || [], autodates()),
      indexes: ["CREATE INDEX `idx_" + name + "_user` ON `" + name + "` (`user`)"].concat(indexes || []),
    });
    app.save(collection);
  }
  const text = (name) => ({ name: name, type: "text" });
  const bool = (name) => ({ name: name, type: "bool" });
  const int = (name) => ({ name: name, type: "number", onlyInt: true });
  const date = (name) => ({ name: name, type: "date" });
  const idx = (name, table, cols) => "CREATE INDEX `idx_" + name + "` ON `" + table + "` (" + cols.map((c) => "`" + c + "`").join(", ") + ")";

  make("category", { after: [text("name"), bool("active")] }, []);
  make("brand", { after: [text("name"), bool("active")] }, []);
  make("store", { after: [text("name"), bool("active")] }, []);

  make("product_type", { before: [text("name")], after: [text("base_unit"), bool("active")] },
    [["category_id", "category", true]]);

  make("product_registration", { after: [text("description"), text("selling_mode"), bool("active")] },
    [["product_type_id", "product_type", true], ["brand_id", "brand", false]]);

  make("product", { after: [int("piece_count"), int("piece_size"), int("total_content"), text("piece_size_unit"), bool("active")] },
    [["product_registration_id", "product_registration", true]],
    [idx("product_product_registration_id", "product", ["product_registration_id"])]);

  make("product_barcode", { after: [{ name: "code", type: "text", required: true }] },
    [["product_id", "product", true], ["store_id", "store", false]],
    [idx("product_barcode_product_id", "product_barcode", ["product_id"])]);

  make("shopping_list_item", { after: [int("quantity"), date("entered_on"), date("fulfilled_on"), date("removed_on"), bool("picked"), bool("not_found")] },
    [["product_type_id", "product_type", true], ["preferred_registration_id", "product_registration", false]],
    [idx("shopping_list_item_product_type_id", "shopping_list_item", ["product_type_id"])]);

  make("purchase", { after: [date("purchase_date"), text("registered_by"), date("created_at")] },
    [["store_id", "store", true]],
    [idx("purchase_user_purchase_date", "purchase", ["user", "purchase_date"])]);

  make("purchase_item", { after: [int("quantity"), int("quantity_in_base_unit"), int("total_paid")] },
    [["purchase_id", "purchase", true, true], ["product_id", "product", true]],
    [idx("purchase_item_purchase_id", "purchase_item", ["purchase_id"]),
     idx("purchase_item_user_product_id", "purchase_item", ["user", "product_id"])]);

  make("list_write_off", { after: [int("quantity_written_off"), bool("cleared_not_found")] },
    [["purchase_item_id", "purchase_item", true, true], ["shopping_list_item_id", "shopping_list_item", true]],
    [idx("list_write_off_shopping_list_item_id", "list_write_off", ["shopping_list_item_id"])]);

  // The unique indexes below back the "update or create" of the cap (one row per owner and key).
  make("spending_cap", { after: [int("amount"), date("effective_from")] }, [],
    ["CREATE UNIQUE INDEX `uq_spending_cap_user_effective_from_upsert` ON `spending_cap` (`user`, `effective_from`)"]);

  make("spending_cap_alert", { after: [date("month"), date("warned_80_at"), date("warned_100_at")] }, [],
    ["CREATE UNIQUE INDEX `uq_spending_cap_alert_user_month_upsert` ON `spending_cap_alert` (`user`, `month`)"]);
}, (app) => {
  const names = ["spending_cap_alert", "spending_cap", "list_write_off", "purchase_item", "purchase",
    "shopping_list_item", "product_barcode", "product", "product_registration", "product_type",
    "store", "brand", "category"];
  for (const name of names) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
