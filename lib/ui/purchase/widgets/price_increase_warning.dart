import 'package:flutter/material.dart';

import '../../../domain/models/price_increase.dart';

/// The `⚠ Subiu 18% sobre a média` line of screen 3 — **the only warning that
/// shows WHILE typing**, because it is the only one that depends solely on
/// the item being filled in. The other two (the same-day item and the month's
/// cap) can only be computed after saving, which is why the wireframe puts
/// them in Estados and not in the form.
///
/// **It is not on the correction screen** (decision D-p): `handoff §H15` writes
/// "Telas envolvidas: Tela 3 `#3`", and a correction fixes a purchase already
/// made — warning there is information that arrives late and with no action
/// left.
///
/// A dumb widget: it takes the [PriceIncrease] ready and writes the sentence
/// the entity already built. It does not know what 10% is.
class PriceIncreaseWarning extends StatelessWidget {
  const PriceIncreaseWarning({required this.increase, super.key});

  final PriceIncrease increase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              increase.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
