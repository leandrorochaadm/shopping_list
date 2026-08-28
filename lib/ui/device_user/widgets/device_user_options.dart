import 'package:flutter/material.dart';

import '../../../domain/models/device_user.dart';

/// The "Quem está usando?" picker, shared by the welcome screen and by
/// settings — and, from H4 on, by the `👤` of screen 1.
///
/// Writing it three times is the mistake to avoid: the two names and the
/// 48-pixel touch target would then drift apart between the screens.
class DeviceUserOptions extends StatelessWidget {
  const DeviceUserOptions({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The name currently marked, or null on a phone that was never asked.
  final String? selected;

  /// Null while an action is running, which disables the whole group.
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: selected,
    onChanged: onChanged ?? (_) {},
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in DeviceUser.suggestedNames)
          RadioListTile<String>(
            key: Key('device-user-$name'),
            value: name,
            title: Text(name),
            enabled: onChanged != null,
            // Comfortably above the 48-pixel target the checklist asks for.
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
      ],
    ),
  );
}
