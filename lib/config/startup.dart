/// What `main` should do, decided from the two facts that change between
/// builds: whether `AppConfig` has no missing key, and debug mode. It is a pure function so the decision can be tested: everything
/// around it in `main` — the awaits, the runApp — cannot be.
///
/// The two failures that can still happen after this decision (local storage
/// blocked, the PocketBase client failing to start) are not plans: they are the outcome of
/// trying, and `main` catches them where they happen.
enum StartupPlan {
  /// Every key of `config/<env>.json` is there: talk to the PocketBase server.
  remote,

  /// Debug only, no config file: run on the `_local` fakes. Nothing is
  /// saved anywhere, which is why the screen carries a mark saying so.
  fakes,

  /// Outside debug with no config file. Falling back to the fakes
  /// here would ship an app that looks like it works and saves nothing.
  missingConfiguration,
}

/// [debug] is `kDebugMode` — not `kReleaseMode`, so a profile build cannot
/// slip through the gap between the two.
StartupPlan resolveStartup({required bool configured, required bool debug}) {
  if (configured) return StartupPlan.remote;
  return debug ? StartupPlan.fakes : StartupPlan.missingConfiguration;
}
