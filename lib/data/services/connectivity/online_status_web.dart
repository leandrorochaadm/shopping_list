import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's own answer, read synchronously — decision 22 rules out
/// `connectivity_plus`, and a polling Timer would wake the WebKit up for
/// nothing.
///
/// `navigator.onLine` is a weak signal on purpose: it says the device has a
/// network interface, not that the server is reachable. That is why the save
/// path treats a transport failure with the browser saying "online" — a hotel
/// Wi-Fi, a captive portal — as offline too.
bool readOnlineStatus() => web.window.navigator.onLine;

/// The `online` / `offline` events, which is what makes the resend of H8
/// happen while the app is open.
///
/// **Nothing here fires with the app closed.** WebKit has no Background Sync
/// (`R16`), and the banner's wording says exactly that much and no more.
Stream<bool> watchOnlineStatus() {
  late final StreamController<bool> controller;
  void report(web.Event event) => controller.add(readOnlineStatus());
  final listener = report.toJS;

  controller = StreamController<bool>(
    onListen: () {
      web.window.addEventListener('online', listener);
      web.window.addEventListener('offline', listener);
    },
    onCancel: () {
      web.window.removeEventListener('online', listener);
      web.window.removeEventListener('offline', listener);
    },
  );
  return controller.stream;
}
