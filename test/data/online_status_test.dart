import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/services/connectivity/online_status_stub.dart';

/// What the Dart VM sees. The browser half is ten lines behind a conditional
/// import and is the one file the suite cannot reach — by design: importing
/// `package:web` unconditionally would break every test, which is the risk
/// §13 of the plan names.
///
/// The `Notifier` that exposes this reading lives in `ui/core/`, under rule
/// 17, and so does its test.
void main() {
  test('the stub is online and mute', () {
    // "Always online" is the honest answer off the browser: there is no
    // navigator to ask, and a fake "offline" would send every test down the
    // pending-submission path.
    expect(readOnlineStatus(), isTrue);
    expect(watchOnlineStatus(), emitsDone);
  });
}
