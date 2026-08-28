/// What `main` should do, decided from the two facts that change between
/// builds. It is a pure function so the decision can be tested: everything
/// around it in `main` — the awaits, the runApp — cannot be.
///
/// The two failures that can still happen after this decision (local storage
/// blocked, Supabase refusing to start) are not plans: they are the outcome of
/// trying, and `main` catches them where they happen.
enum StartupPlan {
  /// The two --dart-define values are there: talk to the real project.
  remote,

  /// Debug only, with no --dart-define: run on the `_local` fakes. Nothing is
  /// saved anywhere, which is why the screen carries a mark saying so.
  fakes,

  /// A build outside debug with no --dart-define. Falling back to the fakes
  /// here would ship an app that looks like it works and saves nothing.
  missingConfiguration,
}

/// [debug] is `kDebugMode` — not `kReleaseMode`, so a profile build cannot
/// slip through the gap between the two.
StartupPlan resolveStartup({required bool configured, required bool debug}) {
  if (configured) return StartupPlan.remote;
  return debug ? StartupPlan.fakes : StartupPlan.missingConfiguration;
}
