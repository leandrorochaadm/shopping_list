import 'package:flutter/material.dart';

/// The fill of a field that is showing a value the user cannot type into.
///
/// `AppTextField` defaults its `disabledFillColor` to `Colors.grey.shade800`,
/// which belongs to a dark theme; this app has a light one only
/// (`ui/core/themes/app_theme.dart`). Passing that default through would paint a
/// near-black box in the middle of a white screen.
///
/// The color comes from the scheme, not from a literal, so it follows the seed
/// the theme was built from.
Color appDisabledFillColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;
