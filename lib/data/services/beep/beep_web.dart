import 'package:web/web.dart' as web;

// A checkout till tone, not a business rule.
const _hertz = 1800.0;
const _seconds = 0.08;
const _volume = 0.2;

web.AudioContext? _context;

/// iOS keeps every AudioContext suspended until a gesture resumes it, so this
/// runs inside the tap on the button that opens checkout mode.
void unlockBeep() {
  try {
    (_context ??= web.AudioContext()).resume();
  } on Object {
    // Silence: the flash of the border is enough.
  }
}

/// With the iPhone on silent the Web Audio does not play, and the flash is
/// enough. Not `HapticFeedback`: Safari on iOS does not vibrate.
void playBeep() {
  final context = _context;
  if (context == null) return; // never unlocked: the flash is enough
  try {
    final tone = context.createOscillator()..frequency.value = _hertz;
    final volume = context.createGain()..gain.value = _volume;
    tone.connect(volume);
    volume.connect(context.destination);
    tone.start();
    tone.stop(context.currentTime + _seconds);
  } on Object {
    // Silence.
  }
}
