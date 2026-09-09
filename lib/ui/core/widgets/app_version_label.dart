import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/app_version.dart';

/// The `≡` footer: which build of the app is on this phone.
///
/// It exists for one situation — one of the two phones showing something the
/// other does not — where the first question is whether both are on the same
/// build. Hence the tap: the two lines go to the clipboard AS ONE LINE, ready
/// to paste into a message.
///
/// It is deliberately NOT a `ListTile`: the doors of the menu are tiles, and
/// `main_menu_test` reads the door labels by listing every `ListTile` in the
/// sheet. A tile here would enter that list and would read as a fifth door.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({required this.version, super.key});

  final AppVersion version;

  /// `Versão 1.0.0 (build 42)` — or `Versão 1.0.0 (local)` when nothing was
  /// published.
  String get _firstLine => version.isLocalBuild
      ? 'Versão ${version.name} (local)'
      : 'Versão ${version.name} (build ${version.buildNumber})';

  /// `Commit a1b2c3d`, or nothing at all on a local build.
  String? get _secondLine =>
      version.isLocalBuild ? null : 'Commit ${version.commit}';

  /// The two lines joined by a single space — what the tap copies.
  String get _copiedText => [_firstLine, ?_secondLine].join(' ');

  Future<void> _copy(BuildContext context) async {
    // Captured BEFORE the await and BEFORE the pop: after the sheet closes
    // this context is gone, and the messenger has to be the screen's.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await Clipboard.setData(ClipboardData(text: _copiedText));

    // The sheet is closed before the SnackBar, and not after: a bottom sheet
    // sits ON TOP of the SnackBar, which would show up hidden behind it.
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Versão copiada.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_firstLine, style: style),
            if (_secondLine case final line?) Text(line, style: style),
          ],
        ),
      ),
    );
  }
}
