import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/beep/beep_platform.dart';

/// The checkout beep. Not `final`: a test extends it with a spy, the same way
/// the `_local` fakes are extended.
class Beep {
  const Beep();

  /// Must run inside a tap: iOS only plays sound after a gesture.
  void unlock() => unlockBeep();

  void play() => playBeep();
}

final beepProvider = Provider<Beep>((ref) => const Beep());
