/// <reference path="../pb_data/types.d.ts" />
// Drops product_registration.selling_mode: the loose leaf (Product.isLoose) replaces it.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("product_registration");
  collection.fields.removeByName("selling_mode");
  app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("product_registration");
  collection.fields.add(new TextField({ name: "selling_mode" }));
  app.save(collection);
  // The old app needs a value: by_weight only when every leaf has no total content.
  for (const registration of app.findAllRecords("product_registration")) {
    const leaves = app.findRecordsByFilter("product", "product_registration_id = {:id}", "", 0, 0, { id: registration.id });
    const loose = leaves.length > 0 && leaves.every((leaf) => !leaf.get("total_content"));
    registration.set("selling_mode", loose ? "by_weight" : "by_piece");
    app.save(registration);
  }
});
