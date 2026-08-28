import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/catalog_entry.dart';
import '../../../domain/models/category.dart';
import '../../core/widgets/single_field_dialog.dart';
import '../view_model/catalog_view_model.dart';

/// "Nova categoria", one field.
///
/// Opened by the `[+Novo]` of the category field on screen 4, and reused by
/// the mini registration of `#1a` (H4): without it the first item of a new
/// category — the first nappy, the first bakery item — would have nowhere to
/// go, with the receipt still in hand.
abstract final class NewCategoryDialog {
  static Future<Category?> show(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => SingleFieldDialog(
        title: 'Nova categoria',
        fieldLabel: 'Nome da categoria',
        onSubmit: (name) =>
            ref.read(catalogViewModelProvider.notifier).createCategory(name),
      ),
    );
    if (name == null) return null;

    return findNameConflict(
      ref.read(catalogViewModelProvider).value?.categories ??
          const <Category>[],
      name,
    );
  }
}
