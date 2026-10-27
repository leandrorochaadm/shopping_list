import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/ui/barcode/widgets/barcode_camera_view.dart';

/// A camera that sees only what the test tells it.
///
/// Call [read] and [failToOpen] OUTSIDE a `build`, and `pump` afterwards.
final class FakeBarcodeCamera {
  ValueChanged<String>? _onRaw;
  VoidCallback? _onUnavailable;

  Widget build(
    BuildContext context, {
    required ValueChanged<String> onRaw,
    required VoidCallback onUnavailable,
  }) {
    _onRaw = onRaw;
    _onUnavailable = onUnavailable;
    return const SizedBox.expand(key: ValueKey('fake-camera'));
  }

  /// What the camera would see.
  void read(String raw) => _onRaw!(raw);

  /// Permission denied or no camera.
  void failToOpen() => _onUnavailable!();

  Override get override =>
      barcodeCameraBuilderProvider.overrideWithValue(build);
}
