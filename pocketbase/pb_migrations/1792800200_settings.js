/// <reference path="../pb_data/types.d.ts" />
// Batch on (purchase, correction and catalog save in one request) and rate limits
// that do not block normal use by logged-in users.
migrate((app) => {
  const settings = app.settings();
  settings.batch.enabled = true;
  settings.batch.maxRequests = 300;
  settings.batch.timeout = 10;
  settings.rateLimits.enabled = true;
  for (const rule of settings.rateLimits.rules) {
    // Login protection (*:auth) stays for everyone; the rest only throttles guests.
    rule.audience = rule.label === "*:auth" ? "" : "@guest";
  }
  app.save(settings);
}, (app) => {
  const settings = app.settings();
  settings.batch.enabled = false;
  settings.batch.maxRequests = 50;
  settings.batch.timeout = 3;
  settings.rateLimits.enabled = false;
  for (const rule of settings.rateLimits.rules) {
    rule.audience = "";
  }
  app.save(settings);
});
