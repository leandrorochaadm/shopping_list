import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The package exports a `Barcode` that collides with the domain one, and
// `show` keeps it from leaking out of this file.
import 'package:mobile_scanner/mobile_scanner.dart'
    show
        BarcodeCapture,
        BarcodeFormat,
        DetectionSpeed,
        MobileScanner,
        MobileScannerController,
        MobileScannerException;

/// Builds the live camera. [onRaw] gets every raw text the camera sees, and
/// [onUnavailable] is called when the camera cannot open.
typedef BarcodeCameraBuilder =
    Widget Function(
      BuildContext context, {
      required ValueChanged<String> onRaw,
      required VoidCallback onUnavailable,
    });

/// The real camera, backed by `mobile_scanner`.
Widget liveBarcodeCamera(
  BuildContext context, {
  required ValueChanged<String> onRaw,
  required VoidCallback onUnavailable,
}) => _LiveCamera(onRaw: onRaw, onUnavailable: onUnavailable);

/// The test seam: widget tests swap the camera for a fake with
/// `overrideWithValue`, including on screens built by the router.
final barcodeCameraBuilderProvider = Provider<BarcodeCameraBuilder>(
  (ref) => liveBarcodeCamera,
);

/// The camera viewfinder. Calls [onDetect] once for every code that ENTERS
/// the view, not once per frame.
class BarcodeCameraView extends ConsumerStatefulWidget {
  const BarcodeCameraView({required this.onDetect, this.hint, super.key});

  /// How long a code must go unseen to count as having left the view. It is
  /// camera timing, not a business rule, so it lives in the widget.
  static const codeGoneGap = Duration(milliseconds: 400);

  /// Called once per code that enters the view, with the raw text.
  final ValueChanged<String> onDetect;

  /// The sentence over the viewfinder. Null when the caller draws its own.
  final String? hint;

  @override
  ConsumerState<BarcodeCameraView> createState() => _BarcodeCameraViewState();
}

class _BarcodeCameraViewState extends ConsumerState<BarcodeCameraView> {
  final _inView = <String, Timer>{};
  bool _unavailable = false;

  void _onRaw(String raw) {
    // A late sighting after dispose would start a Timer nobody cancels.
    if (!mounted) return;
    // Every sighting pushes the deadline: the code only "leaves" after a whole
    // codeGoneGap without being seen.
    final seen = _inView.remove(raw)?..cancel();
    _inView[raw] = Timer(
      BarcodeCameraView.codeGoneGap,
      () => _inView.remove(raw),
    );
    if (seen == null) widget.onDetect(raw);
  }

  void _onUnavailable() {
    if (!mounted || _unavailable) return;
    setState(() => _unavailable = true);
  }

  @override
  void dispose() {
    for (final timer in _inView.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const Text('Libere a câmera nos Ajustes do iPhone.');
    }
    final hint = widget.hint;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ref.watch(barcodeCameraBuilderProvider)(
              context,
              onRaw: _onRaw,
              onUnavailable: _onUnavailable,
            ),
            if (hint != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    hint,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveCamera extends StatefulWidget {
  const _LiveCamera({required this.onRaw, required this.onUnavailable});

  final ValueChanged<String> onRaw;
  final VoidCallback onUnavailable;

  static const formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.qrCode,
  ];

  @override
  State<_LiveCamera> createState() => _LiveCameraState();
}

class _LiveCameraState extends State<_LiveCamera> {
  late final MobileScannerController _controller;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: _LiveCamera.formats,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 150,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw != null && raw.isNotEmpty) widget.onRaw(raw);
    }
  }

  Widget _onError(BuildContext context, MobileScannerException error) {
    // Called during build: reporting right away would `setState` mid-build.
    if (!_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onUnavailable(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: _onDetect,
    errorBuilder: _onError,
  );
}
