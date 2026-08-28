import 'package:flutter/material.dart';

/// The one-field dialog three catalogs share: category, brand and store.
///
/// It exists because the three are the same dialog with different words, and
/// three copies would be three places to fix the day the duplicate guard's
/// message moves. What each caller supplies is the wording and [onSubmit];
/// the rules stay in the ViewModel that [onSubmit] calls.
///
/// It pops the TEXT that was accepted once [onSubmit] reports success, and
/// null when it was dismissed. The caller looks the new row up in the list it
/// already watches — the ViewModel put it there — using the same normalized
/// comparison the guard used to let it through.
class SingleFieldDialog extends StatefulWidget {
  const SingleFieldDialog({
    required this.title,
    required this.fieldLabel,
    required this.onSubmit,
    this.confirmLabel = 'Salvar',
    this.initialValue = '',
    super.key,
  });

  final String title;
  final String fieldLabel;
  final String confirmLabel;
  final String initialValue;

  /// Returns null on success, or the pt-BR sentence to show under the field.
  final Future<String?> Function(String value) onSubmit;

  @override
  State<SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<SingleFieldDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Captured BEFORE the await: after it this context may be gone.
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
    // The failure stays UNDER THE FIELD, not in a SnackBar: the dialog covers
    // the screen, and "já existe o mercado Carrefour" is an answer about what
    // was just typed — it belongs next to what was typed.
    if (error == null) navigator.pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      enabled: !_saving,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: _saving ? null : (_) => _submit(),
      decoration: InputDecoration(
        labelText: widget.fieldLabel,
        errorText: _error,
        // The message can be two lines long, and the default clips it.
        errorMaxLines: 3,
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Salvando...' : widget.confirmLabel),
      ),
    ],
  );
}
