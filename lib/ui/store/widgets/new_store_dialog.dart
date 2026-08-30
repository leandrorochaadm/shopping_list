import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/store.dart';
import '../../core/widgets/single_field_dialog.dart';
import '../view_model/store_view_model.dart';

/// "Mercado novo", one field and nothing else.
///
/// It has no screen of its own: it is opened by the `[+Novo]` next to the
/// store field of screen 3, which is H7's. Registering the store where it was
/// missed is the point — leaving the purchase to go find a catalog screen is
/// what the two-minute budget of requirement 3 cannot pay for.
abstract final class NewStoreDialog {
  /// Opens the dialog and returns the store that was created, or null when it
  /// was dismissed. The caller selects whatever comes back.
  static Future<Store?> show(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => SingleFieldDialog(
        title: 'Novo mercado',
        fieldLabel: 'Nome do mercado',
        onSubmit: (name) =>
            ref.read(storeViewModelProvider.notifier).create(name),
        // The market goes with the four doors of screen 4, and it opens from
        // screen 3 — with the purchase typed behind it. Leaving only screen 4
        // with the button would be two answers to the same block in the same
        // app.
        findReactivable: (name) {
          final conflict = findNameConflict(
            ref.read(storeViewModelProvider).value ?? const <Store>[],
            name,
          );
          return conflict == null || conflict.active ? null : conflict;
        },
        onReactivate: (entry) => ref
            .read(storeViewModelProvider.notifier)
            .reactivate(entry as Store),
      ),
    );
    if (name == null) return null;

    // The ViewModel already put it in the list; asking the domain which entry
    // matches the typed name is how the caller gets the row WITH its id,
    // without a second round trip and using the same comparison the guard
    // used to let it through.
    return findNameConflict(
      ref.read(storeViewModelProvider).value ?? const <Store>[],
      name,
    );
  }
}
