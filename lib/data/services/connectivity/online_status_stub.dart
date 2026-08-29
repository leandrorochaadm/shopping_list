/// What the Dart VM compiles — every test, and any non-web target.
///
/// Always online, and never an event: there is no `navigator` outside a
/// browser, and a test that wants the offline path overrides
/// `onlineStatusProvider` whole rather than pretending a network exists.
bool readOnlineStatus() => true;

Stream<bool> watchOnlineStatus() => const Stream<bool>.empty();
