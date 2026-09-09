import 'package:flutter/material.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/catalog_entry.dart';

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
    this.footnote,
    this.leadingActions = const [],
    this.findReactivable,
    this.onReactivate,
    this.reactivateLabel = 'Reativar',
    super.key,
  });

  final String title;
  final String fieldLabel;
  final String confirmLabel;
  final String initialValue;

  /// Returns null on success, or the pt-BR sentence to show under the field.
  final Future<String?> Function(String value) onSubmit;

  /// Shown below the field, in `bodySmall`. It is where the maintenance
  /// screen explains why there is no delete; the three dialogs of H2 pass
  /// nothing and nothing changes for them.
  final String? footnote;

  /// Extra actions to the LEFT of the two that already exist — the
  /// `[ Desativar ]`/`[ Reativar ]` of the maintenance screen.
  final List<Widget> leadingActions;

  /// Given the value [onSubmit] has just REFUSED, the deactivated row that
  /// can be reactivated — or null, when the conflict was with an active one
  /// and there is no way out to offer.
  ///
  /// It cannot be a ready-made widget in [leadingActions]: a widget does not
  /// know when to appear, and this one appears only AFTER a refusal, and only
  /// when what refused was a deactivated row. The caller already has the
  /// answer in hand — the same list the ViewModel watches — and the question
  /// is pure.
  final CatalogEntry? Function(String value)? findReactivable;

  /// Reactivates and returns null, or the pt-BR sentence. The same shape as
  /// every action (rule 16, two outcomes with no payload).
  final Future<String?> Function(CatalogEntry entry)? onReactivate;

  /// What the button says. The product registration's door words it
  /// differently: reactivating there is the first half of adding a packaging.
  final String reactivateLabel;

  @override
  State<SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<SingleFieldDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;
  bool _saving = false;

  /// The deactivated row the last refusal was about. Null while nothing was
  /// refused, and null again as soon as the text changes: an offer to
  /// reactivate "Limpeza" standing over a field that now reads "Limpezas"
  /// would reactivate the wrong row.
  CatalogEntry? _reactivable;

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
      _reactivable = null;
    });
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
      _reactivable = error == null
          ? null
          : widget.findReactivable?.call(_controller.text);
    });
    // The failure stays UNDER THE FIELD, not in a SnackBar: the dialog covers
    // the screen, and "já existe o mercado Carrefour" is an answer about what
    // was just typed — it belongs next to what was typed.
    if (error == null) navigator.pop(_controller.text);
  }

  Future<void> _reactivate() async {
    final entry = _reactivable;
    final onReactivate = widget.onReactivate;
    if (entry == null || onReactivate == null) return;

    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await onReactivate(entry);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
    // Closes handing back the TEXT, exactly as a successful save does: the
    // caller then finds the row in the list the ViewModel has just updated,
    // and no new return path is invented (rule 16).
    if (error == null) navigator.pop(entry.name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            onSubmitted: _saving ? null : (_) => _submit(),
            onChanged: (_) {
              if (_reactivable != null) setState(() => _reactivable = null);
            },
            errorText: _error,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              // The message can be two lines long, and the default clips it.
              errorMaxLines: 3,
            ),
          ),
          if (_reactivable != null && widget.onReactivate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('reactivate'),
                onPressed: _saving ? null : _reactivate,
                child: Text(widget.reactivateLabel),
              ),
            ),
          if (widget.footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.footnote!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
    actions: [
      ...widget.leadingActions,
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
