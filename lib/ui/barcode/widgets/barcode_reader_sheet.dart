import 'package:flutter/material.dart';
import 'package:tekton_core/tekton_core.dart';

import 'barcode_camera_view.dart';

/// The reader panel: a bottom sheet with a typed-code field ABOVE the camera.
///
/// It returns the RAW text, read or typed. Whoever opens it interprets it
/// (`resolveScan`, `Barcode.typed`, `ScaleLabel.parse`).
class BarcodeReaderSheet extends StatefulWidget {
  const BarcodeReaderSheet({super.key});

  /// Null when the panel is dismissed without a code.
  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const BarcodeReaderSheet(),
      );

  @override
  State<BarcodeReaderSheet> createState() => _BarcodeReaderSheetState();
}

class _BarcodeReaderSheetState extends State<BarcodeReaderSheet> {
  final _typed = TextEditingController();
  bool _closed = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// The ONLY way out by code. It guards against two `pop`s: two reads in the
  /// same frame, or a read arriving while the panel is already leaving (after
  /// the X, a tap outside or a drag down). The camera keeps reading during the
  /// exit animation, and a `pop` on a route that left the top closes the one
  /// below.
  void _closeWith(String? raw) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop(raw);
  }

  void _useTyped() {
    final text = _typed.text.trim();
    if (text.isNotEmpty) _closeWith(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ler código',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('reader-close'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                      onPressed: () => _closeWith(null),
                    ),
                  ],
                ),
                const Text('Não leu? Digite:'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        key: const ValueKey('reader-typed'),
                        controller: _typed,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _useTyped(),
                        decoration: const InputDecoration(
                          hintText: 'Código de barras',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _typed,
                      builder: (context, value, _) => FilledButton(
                        key: const ValueKey('reader-use'),
                        onPressed: value.text.trim().isEmpty ? null : _useTyped,
                        child: const Text('Usar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BarcodeCameraView(
                  onDetect: _closeWith,
                  hint: 'Aponte para o código',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
