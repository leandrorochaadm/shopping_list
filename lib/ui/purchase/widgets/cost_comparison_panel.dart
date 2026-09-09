import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/proportional_cost.dart';
import '../../core/formatting.dart';

/// The `#3a` panel — **Comparar custo**, the proportional cost calculator.
///
/// It is a panel anchored at the bottom, not a screen: the purchase stays
/// behind it, and closing gives the cursor back where it was. That is what
/// keeps it clear the calculator is a ten-second detour, not somewhere you
/// go into.
///
/// **Three bands, and only the middle one scrolls:** a fixed header with the
/// type and the unit of the computation, the list scrolling in the middle, a
/// fixed footer with the verdict and the button. On a small phone the answer
/// never scrolls out of sight.
///
/// **Nothing typed here becomes a record.** There is no repository, no
/// provider and not a single `await`: the prices live in
/// `TextEditingController`s that die with the panel. Whoever writes a price
/// down is the purchase.
class CostComparisonPanel extends StatefulWidget {
  const CostComparisonPanel({
    required this.candidates,
    required this.launching,
    super.key,
  });

  /// Hands back the chosen leaf, or `null` when it closes choosing nothing.
  ///
  /// `isScrollControlled` is the `══` of the wireframe and what lets the
  /// keyboard come up without covering the lines — the same as panel `#1a`.
  static Future<ProductOption?> show(
    BuildContext context, {
    required CostCandidates candidates,
    required ProductOption launching,
  }) => showModalBottomSheet<ProductOption>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        CostComparisonPanel(candidates: candidates, launching: launching),
  );

  final CostCandidates candidates;

  /// The product being registered — **the only line that opens ticked**.
  final ProductOption launching;

  @override
  State<CostComparisonPanel> createState() => _CostComparisonPanelState();
}

class _CostComparisonPanelState extends State<CostComparisonPanel> {
  /// One price controller per leaf, and they live only as long as the panel
  /// does. That is the shape of "nothing he types here survives the closing".
  final _priceControllers = <String, TextEditingController>{};

  /// One quantity controller **only for the leaves with no packaging** — the
  /// only ones the domain lets the content be typed for. Whoever is not here
  /// has no field, and this is the map the line asks to know whether it draws
  /// one.
  final _contentControllers = <String, TextEditingController>{};

  /// The ticked ids. It opens with exactly one: the product being registered
  /// — which `costCandidatesOf` guaranteed is in `shown` (F-j).
  ///
  /// The null-aware element and not an `if case`: it is what
  /// `use_null_aware_elements` asks for, and the lint is the project's — the
  /// `if case` version leaves `flutter analyze` with an issue on it.
  late final Set<String> _selected = {?widget.launching.id};

  /// Has `[ Ver todas do tipo ]` been tapped?
  bool _showingAll = false;

  IList<ProductOption> get _lines =>
      _showingAll ? widget.candidates.all : widget.candidates.shown;

  @override
  void initState() {
    super.initState();
    // Pre-fills EVERY leaf of the type, not only the visible ones:
    // [ Ver todas do tipo ] reveals lines that already carry the right price,
    // and creating a controller in the middle of a build would be the wrong
    // way to do that.
    for (final option in widget.candidates.all) {
      final id = option.id;
      if (id == null) continue;
      final opening = openingPriceOf(option);
      _priceControllers[id] = TextEditingController(
        text: opening == null ? '' : formatMoneyPlain(opening),
      );
      // The quantity opens at what ONE typed price buys — which the domain
      // already answers, and is one pricing unit on the weighed line. So the
      // panel opens exactly as it opened, and the field is an invitation to
      // correct, not a question to answer before using it.
      if (acceptsTypedContentOf(option)) {
        _contentControllers[id] = TextEditingController(
          text: option.baseUnit.typedText(contentPricedOf(option)),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _contentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// What is typed, already filtered by what `Money.parse` accepts — a field
  /// with "1,2,3" in it is a field being typed, not an error to report.
  ///
  /// **Only the visible lines**, and not the whole of `_priceControllers`:
  /// `initState` creates a controller for every leaf of the type, and a leaf
  /// still hidden by `[ Ver todas do tipo ]` coming in here would swap the
  /// footer's sentence on a screen where nothing has a price.
  IMap<String, Money> get _prices {
    final parsed = <String, Money>{};
    for (final option in _lines) {
      final id = option.id;
      if (id == null) continue;
      try {
        final money = Money.parse(_priceControllers[id]!.text);
        if (money.cents > 0) parsed[id] = money;
      } on InvalidMoney {
        // It stays out of the computation, and the line simply shows no cost.
      }
    }
    return parsed.lock;
  }

  /// What was typed as a quantity, converted to the smallest unit of the base
  /// — plus the explicit `null` of whoever cleared the field or typed what is
  /// not a number. The two cases are different to the domain, and that is why
  /// the map holds a nullable value (see `rankCosts`).
  ///
  /// **Only the visible lines**, for the same reason as `_prices`: a leaf
  /// still hidden by `[ Ver todas do tipo ]` cannot sway the footer's
  /// sentence.
  IMap<String, int?> get _contents {
    final parsed = <String, int?>{};
    for (final option in _lines) {
      final id = option.id;
      final controller = id == null ? null : _contentControllers[id];
      if (id == null || controller == null) continue;
      try {
        parsed[id] = option.baseUnit.parseAmount(controller.text);
      } on InvalidAmount {
        parsed[id] = null;
      } on AmountMustBeWhole {
        parsed[id] = null;
      }
    }
    return parsed.lock;
  }

  void _toggle(ProductOption option) {
    final id = option.id;
    if (id == null) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseUnit = widget.launching.baseUnit;
    // The rule, asked whole on every frame (rule 11). The View compares no
    // cents of its own.
    final ranking = rankCosts(
      options: _lines,
      prices: _prices,
      contents: _contents,
      selected: _selected.lock,
      baseUnit: baseUnit,
    );

    return Padding(
      // The keyboard. Without this the fixed footer sits behind it on the
      // iPhone.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Band 1: fixed header ─────────────────────────────────────
          // The `══` the wireframe draws: it is what says "this is a panel,
          // not a screen".
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ListTile(
            title: const Text('Comparar custo'),
            subtitle: Text(
              '${widget.launching.type.name.toLowerCase()} · '
              '${costHeaderFor(baseUnit)}',
            ),
            trailing: IconButton(
              key: const ValueKey('cost-close'),
              icon: const Icon(Icons.close),
              // `tecnico §7.5`: an icon-only button carries a semantic label.
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Divider(height: 1),
          // ── Band 2: the only one that scrolls ────────────────────────
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final line in ranking.lines)
                  _CostRow(
                    // The key is the leaf, not the position: without it the
                    // line that moves up when it is ticked would take the
                    // focus and the cursor of whoever was typing in it away.
                    key: ValueKey('cost-row-${line.option.id}'),
                    line: line,
                    baseUnit: baseUnit,
                    priceController: _priceControllers[line.option.id]!,
                    contentController: _contentControllers[line.option.id],
                    onToggle: () => _toggle(line.option),
                    onEdited: () => setState(() {}),
                  ),
                if (widget.candidates.hasMore && !_showingAll)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('cost-show-all'),
                      onPressed: () => setState(() => _showingAll = true),
                      child: const Text('Ver todas do tipo'),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Band 3: fixed footer ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ranking.headline,
                  key: const ValueKey('cost-headline'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('cost-use'),
                  // Locked while there are not two lines with a price. On a
                  // technical tie it STAYS, pointing at the cheaper one.
                  onPressed: ranking.usable == null
                      ? null
                      : () => Navigator.of(context).pop(ranking.usable),
                  child: Text(
                    ranking.usable == null
                        ? 'Usar'
                        : 'Usar ${ranking.usable!.label}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the panel, in **two heights** (decision F-k): the name alone
/// on top, and below it the box, the price, the cost per base unit and the
/// difference.
///
/// **It is not a concession of space, it is the alignment.** The four columns
/// below add up to ~220 pt of fixed width with the box's touch target; on an
/// iPhone 12 (390 pt) that leaves little over 100 pt for "Coca-Cola original
/// 12 × 350 ml", which wraps into three lines and pushes each item's columns
/// to a different height. The comparison on this screen is made with the eye,
/// going down the cost column — and a column that moves up and down cannot be
/// gone down. In two heights the fields below sit in the same place on every
/// line, whatever the name.
///
/// The quantity column only carries a field where `line.acceptsTypedContent`
/// is true — **and the View does not decide that**: it is
/// `acceptsTypedContentOf`, in the domain, that builds the map of controllers.
class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.line,
    required this.baseUnit,
    required this.priceController,
    required this.onToggle,
    required this.onEdited,
    this.contentController,
    super.key,
  });

  final CostLine line;
  final BaseUnit baseUnit;
  final TextEditingController priceController;

  /// Only the leaf with no packaging has one — and it is
  /// `line.acceptsTypedContent`, in the domain, that says which those are.
  /// Null here does not wipe the column out: it goes on taking the same
  /// space, empty.
  final TextEditingController? contentController;

  final VoidCallback onToggle;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = line.costPerBaseUnit;
    final saving = line.savingPercent;

    return Material(
      // The winning line is found without reading a number. `withValues` and
      // not `withOpacity`, which is deprecated in Flutter 3.44.
      color: line.isBest
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Height 1: the name, with the whole width ────────────────
            // The name toggles the line too. Height 2 is NOT wrapped: an
            // `InkWell` over the two fields would steal the tap of whoever
            // is aiming at them to type.
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    if (line.isBest)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star,
                          size: 20,
                          color: theme.colorScheme.primary,
                          // The `★` is information, not decoration: without
                          // this a screen reader has no idea which line won.
                          semanticLabel: 'Melhor custo',
                        ),
                      ),
                    Expanded(child: Text(line.option.label)),
                    if (line.isBest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        // The colour goes INSIDE the decoration: `color`
                        // beside `decoration` trips an assertion at runtime.
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MELHOR CUSTO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ── Height 2: the fields, always in the same place ──────────
            Row(
              children: [
                Checkbox(
                  key: ValueKey('cost-check-${line.option.id}'),
                  value: line.selected,
                  onChanged: (_) => onToggle(),
                ),
                SizedBox(
                  width: 118,
                  child: TextField(
                    key: ValueKey('cost-price-${line.option.id}'),
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // The iOS keyboard offers a comma or a dot depending on
                    // the layout, and the domain's parser reads both.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                    ],
                    decoration: _fieldBox('Preço', prefix: r'R$ '),
                    onChanged: (_) => onEdited(),
                  ),
                ),
                // The quantity column exists on EVERY line, with a field or
                // without one: it is what keeps the cost and the difference
                // in the same place when a weighed leaf and a packaging sit
                // side by side, which is the whole reason the line has two
                // heights (F-k).
                SizedBox(
                  width: 104,
                  child: contentController == null
                      ? const SizedBox.shrink()
                      : TextField(
                          key: ValueKey('cost-content-${line.option.id}'),
                          controller: contentController,
                          // Digits only: the content is typed in the small
                          // unit of the magnitude, always a whole number.
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _fieldBox(
                            'Quanto vem',
                            suffix: baseUnit.label,
                          ),
                          onChanged: (_) => onEdited(),
                        ),
                ),
                Expanded(
                  // `min` and not the default `max`: the item of a `ListView`
                  // is given an unbounded height, and a `RenderFlex` with an
                  // unbounded main axis and `MainAxisSize.max` trips an
                  // assertion.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // **No "R$ " here**, and it is not saving pixels: the
                        // panel's header already says "custo por litro", the
                        // field beside it already carries the symbol in its
                        // `prefixText`, and repeating it on every line is a
                        // whole column saying the same thing.
                        //
                        // A line that does not compete shows neither cost nor
                        // difference, EVEN with the price filled in.
                        //
                        // `priceLabel` and NEVER `label`: this column is read
                        // in the type's pricing unit.
                        cost == null
                            ? ''
                            : '${formatMoneyPlain(Money(cost))}'
                                  '/${baseUnit.priceLabel}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleMedium,
                      ),
                      // The difference, in words. The View does not decide
                      // whether there is one: `savingPercent`, in the domain,
                      // does (F-d).
                      if (line.isBest)
                        Text(
                          'melhor',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else if (saving != null)
                        Text(
                          // `savingPercent` measures what the best one saves
                          // over THIS line, and the sentence says exactly
                          // that. A `−29%` in red on the dearest line is the
                          // grammar of a discount and reads backwards (F-o).
                          'a melhor economiza $saving%',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The box of the two fields of a line. A function and not two literals: the
/// two fields have to keep the same height, and two copies drift apart at the
/// first padding tweak.
InputDecoration _fieldBox(String label, {String? prefix, String? suffix}) =>
    InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      // **Without this the label hides the `R$ ` and the unit.** In Material's
      // `InputDecorator` the prefix and the suffix only show while the label
      // floats — a focused or filled field. The still-empty line is exactly
      // where the hint matters.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: true,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
