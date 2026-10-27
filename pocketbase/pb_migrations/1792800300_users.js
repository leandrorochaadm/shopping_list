/// <reference path="../pb_data/types.d.ts" />
// Users: nobody reads or changes another account; sign-up is closed (superuser only).
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  users.updateRule = "id = @request.auth.id";
  users.deleteRule = "id = @request.auth.id";
  users.createRule = null;
  users.authToken.duration = 7776000; // 90 days
  users.fields.getByName("password").min = 8;
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.createRule = "";
  users.authToken.duration = 604800;
  users.fields.getByName("password").min = 8;
  app.save(users);
});
