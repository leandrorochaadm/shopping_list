import 'package:flutter/material.dart';

/// The sentence a code read leaves behind, with an optional button. The same
/// drawing under the Tipo field of the `#1a` panel and above the list of the
/// pantry check. A null [onAction] turns the button off — it is "working".
class ScanNotice extends StatelessWidget {
  const ScanNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        Expanded(child: Text(message, key: const ValueKey('scan-notice'))),
        if (actionLabel case final label?)
          TextButton(
            key: const ValueKey('scan-notice-action'),
            onPressed: onAction,
            child: Text(label),
          ),
      ],
    ),
  );
}
