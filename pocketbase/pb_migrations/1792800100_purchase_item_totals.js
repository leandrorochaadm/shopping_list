/// <reference path="../pb_data/types.d.ts" />
// The only view: counts purchases per product so the domain does not read the whole
// history just to count (~8 trips/month x ~20 items = ~2k rows per year).
const OWNER = "user = @request.auth.id";

migrate((app) => {
  const view = new Collection({
    type: "view",
    name: "purchase_item_totals",
    listRule: OWNER,
    viewRule: OWNER,
    viewQuery:
      "SELECT (pi.user || '_' || pi.product_id) AS id, pi.user AS user, pi.product_id AS product_id, COUNT(*) AS purchase_count " +
      "FROM purchase_item pi GROUP BY pi.user, pi.product_id",
  });
  app.save(view);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("purchase_item_totals"));
});
