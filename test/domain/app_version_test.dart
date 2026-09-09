import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/app_version.dart';

void main() {
  const published = AppVersion(
    name: '1.0.0',
    buildNumber: 42,
    commit: 'a1b2c3d',
  );

  test('two instances with the same fields are equal', () {
    expect(
      published,
      const AppVersion(name: '1.0.0', buildNumber: 42, commit: 'a1b2c3d'),
    );
    expect(
      published.hashCode,
      const AppVersion(
        name: '1.0.0',
        buildNumber: 42,
        commit: 'a1b2c3d',
      ).hashCode,
    );
  });

  test('changing one field at a time breaks equality', () {
    // One case per field: this is what catches a field left out of `==`.
    expect(
      published ==
          const AppVersion(name: '1.0.1', buildNumber: 42, commit: 'a1b2c3d'),
      isFalse,
    );
    expect(
      published ==
          const AppVersion(name: '1.0.0', buildNumber: 43, commit: 'a1b2c3d'),
      isFalse,
    );
    expect(
      published ==
          const AppVersion(name: '1.0.0', buildNumber: 42, commit: 'e5f6a7b'),
      isFalse,
    );
  });

  test('a build with a number and a commit is not local', () {
    expect(published.isLocalBuild, isFalse);
  });

  test('a build missing the number or the commit is local', () {
    expect(const AppVersion(name: '1.0.0').isLocalBuild, isTrue);
    expect(const AppVersion(name: '1.0.0', buildNumber: 42).isLocalBuild, isTrue);
    expect(
      const AppVersion(name: '1.0.0', commit: 'a1b2c3d').isLocalBuild,
      isTrue,
    );
  });

  test('toString carries the three fields', () {
    expect(published.toString(), 'AppVersion(1.0.0, 42, a1b2c3d)');
  });
}
