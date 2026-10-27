import 'dart:core';
import 'dart:core' as core;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/ui/core/beep.dart';

/// Counts what the screen asks of the beep; the sound itself needs a browser.
final class SpyBeep extends Beep {
  int plays = 0;
  int unlocks = 0;

  // The `override` getter below shadows the annotation inside this class.
  @core.override
  void play() => plays++;

  @core.override
  void unlock() => unlocks++;

  Override get override => beepProvider.overrideWithValue(this);
}
