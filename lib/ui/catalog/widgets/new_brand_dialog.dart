import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/brand.dart';
import '../../../domain/models/catalog_entry.dart';
import '../../core/widgets/single_field_dialog.dart';
import '../view_model/catalog_view_model.dart';

/// "Nova marca", one field — same shape as the store dialog of screen 3, and
/// for the same reason: the brand groups and compares prices, so "Omo" and
/// "OMO" typed on different days would split its history in two.
abstract final class NewBrandDialog {
  static Future<Brand?> show(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => SingleFieldDialog(
        title: 'Nova marca',
        fieldLabel: 'Nome da marca',
        onSubmit: (name) =>
            ref.read(catalogViewModelProvider.notifier).createBrand(name),
        // Same door, same reason as the category's — see there.
        findReactivable: (name) {
          final conflict = findNameConflict(
            ref.read(catalogViewModelProvider).value?.brands ?? const <Brand>[],
            name,
          );
          return conflict == null || conflict.active ? null : conflict;
        },
        onReactivate: (entry) => ref
            .read(catalogViewModelProvider.notifier)
            .reactivateBrand(entry as Brand),
      ),
    );
    if (name == null) return null;

    return findNameConflict(
      ref.read(catalogViewModelProvider).value?.brands ?? const <Brand>[],
      name,
    );
  }
}
