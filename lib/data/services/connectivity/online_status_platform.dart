/// Which of the two implementations gets compiled.
///
/// The stub is what the Dart VM of `flutter test` sees; the web one is what
/// the browser gets. The conditional import is the whole reason `package:web`
/// can be used at all without breaking the test suite (risk of §13).
library;

export 'online_status_stub.dart'
    if (dart.library.js_interop) 'online_status_web.dart';
