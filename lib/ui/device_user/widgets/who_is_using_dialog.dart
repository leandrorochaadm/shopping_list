import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_model/device_user_view_model.dart';
import 'device_user_options.dart';

/// The `👤` of the app bar — the same [DeviceUserOptions] picker H1 wrote.
///
/// Extracted out of screen 1 when screen 5 grew the same header: written a
/// third time it would be three touch targets drifting apart.
///
/// **It lives in `ui/device_user/` and not in `ui/core/widgets/`**, next to the
/// [DeviceUserOptions] it builds: it needs a feature's ViewModel, and no file
/// of `ui/core/widgets/` imports a feature folder today — putting it there
/// would invert the dependency. The `≡` beside it has no such need, which is
/// why it could move to `core`.
Future<void> showWhoIsUsingDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quem está usando?'),
        content: Consumer(
          builder: (context, ref, _) => DeviceUserOptions(
            selected: ref.watch(deviceUserViewModelProvider).value?.name,
            onChanged: (name) async {
              if (name == null) return;
              final navigator = Navigator.of(dialogContext);
              await ref.read(deviceUserViewModelProvider.notifier).save(name);
              navigator.pop();
            },
          ),
        ),
      ),
    );
