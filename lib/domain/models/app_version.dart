/// The three numbers that identify a published build: the version from
/// `pubspec.yaml`, the build number the CI counted, and the commit it was
/// built from.
///
/// A LOCAL build has neither a build number nor a commit — nobody counted the
/// run and nothing was published. That is what [isLocalBuild] answers, and it
/// is why the two fields are nullable instead of defaulting to zero: `0` is a
/// build that ran, `null` is a build that never did.
///
/// No screen text lives here: this class does not know the word "Versão".
final class AppVersion {
  const AppVersion({required this.name, this.buildNumber, this.commit});

  /// `1.0.0` — the `version:` of `pubspec.yaml`, without the `+build` suffix.
  final String name;

  /// The CI run counter. `null` on a local build.
  final int? buildNumber;

  /// The short commit hash (7 chars). `null` on a local build.
  final String? commit;

  bool get isLocalBuild => buildNumber == null || commit == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          other.name == name &&
          other.buildNumber == buildNumber &&
          other.commit == commit;

  @override
  int get hashCode => Object.hash(name, buildNumber, commit);

  @override
  String toString() => 'AppVersion($name, $buildNumber, $commit)';
}
