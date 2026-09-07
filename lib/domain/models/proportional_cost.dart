import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'money.dart';
import 'product_option.dart';

// **This file imports `product_option.dart`, and NEVER the other way round.**
// It is the opposite of `price_increase.dart`, where it is the leaf that
// imports the rule — and the direction here is that one because the
// calculator needs the packaging, the brand and the selling mode whole, while
// the leaf has no need to know a calculator exists. One arrow only, and
// neither owes the other.

/// The technical tie: **less than 1%** of difference crowns nobody
/// (`requisitos §Regras`). Below it the system answers "custo praticamente
/// igual" instead of electing a winner over a cent.
///
/// It is `const` in the domain (rule 6), and no sentence of this feature
/// writes the number: the two that exist — the tie and the advantage —
/// derive from it or from the computed percentage.
const int costTieThreshold = 1;

/// Does this leaf accept the content being **typed** in the panel?
///
/// Only the one with no registered packaging — the chicken on the tray, the
/// cheese at the counter. Where there is a packaging the content is the
/// registered one and there is nothing to ask: typing another value there
/// would be saying the registration is wrong, and the place to fix a
/// registration is screen 4.
///
/// **It is the only place that answers this.** The View asks (rule 11); it
/// does not look at `packaging == null` inside a `build()`.
bool acceptsTypedContentOf(ProductOption option) =>
    option.isSoldByWeight || option.product.packaging == null;

/// How much content **one** typed price buys, in the smallest unit of the
/// base.
///
/// Sold by piece it is the packaging's content: a crate of 12 × 350 ml is
/// 4200 ml, and the line's price is the whole crate's. Sold by weight it is
/// the base unit itself, which is what makes the typed price ALREADY be the
/// price of the kilo or of the litre — there is no content to divide by,
/// which is what requirement 17 says.
///
/// A leaf with no packaging sold by piece is not representable in the schema
/// (decision B1); the fallback only exists so the arithmetic does not lie if
/// one day it is.
///
/// [typedContent] is what was typed in the panel, already converted to the
/// smallest unit of the base — 800 for "0,8" on a type in kilos. It only
/// counts where [acceptsTypedContentOf] is true, and its absence keeps the
/// "1 kg" the weighed line always had: the typed price ALREADY is the kilo's
/// while nobody says otherwise.
int contentPricedOf(ProductOption option, {int? typedContent}) {
  final packaging = option.product.packaging;
  if (option.isSoldByWeight || packaging == null) {
    // The guard costs one line and is the only division by zero that would
    // take the whole panel down: `parseAmount` never returns zero, and a line
    // with no valid content does not even reach here (see `rankCosts`).
    if (typedContent != null && typedContent > 0) return typedContent;
    return option.baseUnit.smallestUnits;
  }
  return packaging.totalContent;
}

/// The price each line of the panel OPENS with: **what one single package
/// cost on the last purchase**, in any store.
///
/// It is not a new query and not a new computation, and that is what matters:
/// it is the two computations `PriceReference` already does, chosen by the
/// selling mode. Three packs of Omo 500 g bought together for R$ 30,00 open
/// the line at **R$ 10,00**, never at R$ 30,00 — without that division the
/// whole comparison would be wrong.
///
/// `null` is the packaging never bought inside the rolling window: it opens
/// empty, so he can type what the shelf tag says. That is exactly the "is the
/// big one worth it, the one I never take" of requirement 17.
Money? openingPriceOf(ProductOption option) {
  final reference = option.priceReference;
  if (reference == null) return null;
  return option.isSoldByWeight
      ? Money(reference.costPerBaseUnit(option.baseUnit))
      : reference.estimateFor(contentPricedOf(option));
}

/// The two lists of the panel: the short one it opens with, and the whole one
/// `[ Ver todas do tipo ]` reveals.
final class CostCandidates {
  const CostCandidates({required this.all, required this.shown});

  /// **Every ACTIVE product of the type**, of any brand, packaged or sold by
  /// weight — which is the definition of "opção" in requirement 17. Whoever
  /// filtered `active` was `fetchProductOptions`, and it is the only filter
  /// there is.
  final IList<ProductOption> all;

  /// The cut the panel opens with: the ones bought inside the **rolling
  /// window** (which is `priceReference != null`) **plus the leaf being
  /// registered**, with a price or without one.
  ///
  /// Two rules, and both exist for a concrete case:
  ///
  /// - **Fewer than two lines in the cut, and it IS [all]** — opening a
  ///   calculator with a single line is opening it with nothing to compare.
  /// - **The leaf being registered never falls out** (decision **F-j**). It
  ///   is the only one that opens ticked, and a product never bought — the
  ///   "big one I never take" of requirement 17, or one registered a minute
  ///   ago on screen 4 — has no `priceReference` and would fall out of the
  ///   cut, leaving the panel to open with no ticked box at all.
  final IList<ProductOption> shown;

  /// Does the `[ Comparar custo ]` button of screen 3 appear? Two options or
  /// more.
  bool get canCompare => all.length >= 2;

  /// Does `[ Ver todas do tipo ]` appear? Only when there is something left
  /// to reveal.
  bool get hasMore => shown.length < all.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostCandidates && other.all == all && other.shown == shown);

  @override
  int get hashCode => Object.hash(all, shown);

  @override
  String toString() => 'CostCandidates(${shown.length} of ${all.length})';
}

/// Splits the options of one type into the two lists of the panel.
///
/// The order inside is the picker's on screen 3 (`compareForPicker`, decision
/// C1): most bought first. That is the order the panel OPENS with — the order
/// of the ANSWER is [rankCosts], and it only exists once there are prices.
///
/// [launching] is the leaf being registered, and it **goes into `shown`
/// either way** (decision **F-j**): it is the only one that opens ticked, and
/// the case that asks for the calculator the most is precisely the packaging
/// he has never taken. Null is the call with no product chosen, and then
/// there is no panel to open.
CostCandidates costCandidatesOf({
  required IList<ProductOption> options,
  required String? typeId,
  required ProductOption? launching,
}) {
  if (typeId == null) {
    return const CostCandidates(all: IList.empty(), shown: IList.empty());
  }

  // **A leaf with no id stays out**, and that is not loose defensiveness: the
  // panel keeps one text controller PER ID, and a leaf with no id would have
  // nowhere to write its price. A leaf with no id has also never been
  // written, has no history, and cannot be the one a purchase points at.
  final all = options
      .where((option) => option.id != null && option.type.id == typeId)
      .toIList()
      .sort(compareForPicker);
  final recent = all.where((option) => option.priceReference != null).toIList();

  // With fewer than two bought inside the window the cut cuts nothing: the
  // panel opens whole, and `[ Ver todas do tipo ]` has nothing to reveal.
  if (recent.length < 2) return CostCandidates(all: all, shown: all);

  // F-j: the leaf being registered is never missing. `add` plus `sort` and
  // not `insert`, so the line comes in on the SAME order the others follow.
  //
  // **`all.contains` and not only the null check:** without that half, a leaf
  // with no id — or of another type — would land in `shown` without having
  // passed the filter above, and the panel would die on
  // `_priceControllers[line.option.id]!`, which would have created no
  // controller for it.
  final shown =
      launching == null ||
          recent.contains(launching) ||
          !all.contains(launching)
      ? recent
      : recent.add(launching).sort(compareForPicker);

  return CostCandidates(all: all, shown: shown);
}

/// One line of the panel, already resolved — the View only writes down what
/// is here (rule 11).
final class CostLine {
  const CostLine({
    required this.option,
    required this.selected,
    this.price,
    this.costPerBaseUnit,
    this.savingPercent,
    this.isBest = false,
  });

  final ProductOption option;

  /// Ticked. **Only the line of the product being registered opens ticked** —
  /// whoever builds the comparison, from two lines up, is him.
  final bool selected;

  /// The price typed on this line, when it is a valid value. `null` is the
  /// line waiting to be filled in.
  ///
  /// **The View does not draw the field from here** — what rules the text is
  /// the line's `TextEditingController`, which is where the cursor lives.
  /// This field is what the RULE read, and it exists so the domain test can
  /// state what went into the computation without mounting a widget.
  final Money? price;

  /// Cents per base unit — per kilo, per litre, per unit — **rounded**, and
  /// for the screen only.
  ///
  /// `null` when the line **does not compete**: unticked, or ticked and with
  /// no price. An unticked line shows neither cost per base unit nor
  /// difference, **even with the price filled in** — that is a written
  /// criterion.
  final int? costPerBaseUnit;

  /// How much cheaper the best cost is than this line, as a whole percentage,
  /// rounded half-up over the full value.
  ///
  /// `null` on the best line itself, on the ones that do not compete, and on
  /// the ones less than [costTieThreshold] per cent away from the best — the
  /// same ruler that bars the `★` (decision **F-d**).
  final int? savingPercent;

  /// The `★`. Never on more than one line, and on none when there was a
  /// technical tie or when two lines with a price are missing.
  final bool isBest;

  /// Does this line have a quantity field? It is the question `_CostRow`
  /// asks (rule 11) instead of looking at the packaging inside a `build()`.
  ///
  /// A getter, not a field: it derives from [option], which `==` already
  /// compares — and one more field here would be one more field to forget in
  /// the `==` (rule 8).
  bool get acceptsTypedContent => acceptsTypedContentOf(option);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostLine &&
          other.option == option &&
          other.selected == selected &&
          other.price == price &&
          other.costPerBaseUnit == costPerBaseUnit &&
          other.savingPercent == savingPercent &&
          other.isBest == isBest);

  @override
  int get hashCode => Object.hash(
    option,
    selected,
    price,
    costPerBaseUnit,
    savingPercent,
    isBest,
  );

  @override
  String toString() =>
      'CostLine(${option.label}, $costPerBaseUnit, best: $isBest)';
}

/// What the whole panel draws: the lines in the right order, who won, where
/// `[ Usar… ]` points, and the sentence of the footer.
final class CostRanking {
  const CostRanking({
    required this.lines,
    required this.headline,
    this.best,
    this.usable,
  });

  /// Every line of the panel, **ordered**: first the ones that compete, from
  /// the lowest to the highest cost per base unit; then the ticked ones still
  /// without a price; last the unticked ones. Inside the last two blocks, the
  /// picker's order (`compareForPicker`).
  final IList<CostLine> lines;

  /// pt-BR: the fixed footer. Four sentences, and choosing between them is a
  /// rule — never an `if` inside a `build()`.
  final String headline;

  /// The leaf of the `★`. `null` on a technical tie and while two lines with
  /// a price are missing.
  final ProductOption? best;

  /// Where `[ Usar… ]` points. **It survives the technical tie** (decision
  /// F-h): the system stops ASSERTING an advantage, but it does not take away
  /// the way out of choosing without closing the panel. `null` is the locked
  /// button.
  final ProductOption? usable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostRanking &&
          other.lines == lines &&
          other.headline == headline &&
          other.best == best &&
          other.usable == usable);

  @override
  int get hashCode => Object.hash(lines, headline, best, usable);

  @override
  String toString() => 'CostRanking(${lines.length} lines, best: ${best?.id})';
}

/// The whole rule of the calculator: pure, in integers, and without a single
/// division in floating point.
///
/// [prices] are only the **valid** prices — the View has already dropped what
/// `Money.parse` refused, because a field with "1,2,3" in it is a field being
/// typed, not an error to report. [selected] are the ticked ids.
///
/// The answer is rebuilt whole on every keystroke: that is what the
/// requirement means by "não há botão calcular nem tela de resultado".
CostRanking rankCosts({
  required IList<ProductOption> options,
  required IMap<String, Money> prices,

  /// The content typed on each line, in the smallest unit of the base.
  ///
  /// **Null is an answer, absence is another thing** — the same pattern as
  /// `RestoredListItem`:
  ///
  /// - key missing: nobody typed anything; it is worth one base unit, as it
  ///   always was;
  /// - key with a value: that is the line's divisor;
  /// - key with `null`: the field was cleared or has rubbish in it, and the
  ///   line WAITS — with no cost and no `−%`, just like a ticked line with
  ///   no price.
  ///
  /// A line with a registered packaging ignores this whole map.
  required IMap<String, int?> contents,
  required ISet<String> selected,
  required BaseUnit baseUnit,
}) {
  // Who competes: ticked AND with a price. A ticked line with no price waits
  // and stays out of the computation; a line with a price and unticked stays
  // out too.
  final competing = <_Contender>[];
  final waiting = <ProductOption>[];
  final aside = <ProductOption>[];

  for (final option in options) {
    final id = option.id;
    final price = id == null ? null : prices[id];
    final isSelected = id != null && selected.contains(id);
    // **`containsKey` TOGETHER with the `== null`** is what tells "the field
    // was cleared" from "this line has no field at all" — without it every
    // packaged line would fall into the waiting branch.
    final hasTypedContent = id != null && contents.containsKey(id);
    final typedContent = hasTypedContent ? contents[id] : null;

    if (!isSelected) {
      aside.add(option);
    } else if (price == null || price.cents <= 0) {
      waiting.add(option);
    } else if (acceptsTypedContentOf(option) &&
        hasTypedContent &&
        typedContent == null) {
      // Ticked, with a price, and the quantity field empty or invalid: it
      // waits. Falling back to one kilo here would show a plausible and wrong
      // cost, which is the worst outcome a calculator has.
      waiting.add(option);
    } else {
      competing.add(
        _Contender(
          option: option,
          cents: price.cents,
          content: contentPricedOf(option, typedContent: typedContent),
        ),
      );
    }
  }

  competing.sort(_compareContenders);
  waiting.sort(compareForPicker);
  aside.sort(compareForPicker);

  // **Two lines with a price are already enough** for there to be an answer.
  final hasAnswer = competing.length >= 2;
  final leader = hasAnswer ? competing.first : null;
  // The tie is between the FIRST and the SECOND: below the cut nobody is
  // crowned.
  final tied = hasAnswer && !_differs(competing[1], leader!);

  final lines = <CostLine>[
    for (final contender in competing)
      CostLine(
        option: contender.option,
        selected: true,
        price: Money(contender.cents),
        costPerBaseUnit: contender.costPerBaseUnit(baseUnit),
        // On the leader there is never a difference to show; on the others,
        // only when it reaches the cut (F-d).
        savingPercent: leader == null || identical(contender, leader)
            ? null
            : _savingPercent(contender, leader),
        isBest: !tied && identical(contender, leader),
      ),
    for (final option in waiting) CostLine(option: option, selected: true),
    for (final option in aside)
      CostLine(
        option: option,
        selected: false,
        // The price shows in the field, but the line does not compete: no
        // cost and no difference beside it.
        price: option.id == null ? null : prices[option.id!],
      ),
  ];

  return CostRanking(
    lines: lines.lock,
    best: tied ? null : leader?.option,
    usable: leader?.option,
    headline: _headline(
      competing: competing,
      leader: leader,
      tied: tied,
      // **Only the VISIBLE lines count**, and not `prices.isNotEmpty`: the
      // panel creates a controller for every leaf of the type, including the
      // ones `[ Ver todas do tipo ]` still hides. Asking the whole map would
      // let a hidden leaf with a price swap "Digite os preços" for "Preencha
      // o preço de duas opções" on a screen where nothing has a price.
      anyPrice: options.any(
        (option) => option.id != null && prices[option.id!] != null,
      ),
      baseUnit: baseUnit,
    ),
  );
}

/// A competing line, reduced to the fraction that compares it: cents over
/// content. Private because it is [rankCosts]'s machinery and does not leave
/// this file.
final class _Contender {
  const _Contender({
    required this.option,
    required this.cents,
    required this.content,
  });

  final ProductOption option;
  final int cents;
  final int content;

  /// The only rounded number of the rule, and it is for the screen only — the
  /// same half-up formula as `PriceReference.costPerBaseUnit`.
  int costPerBaseUnit(BaseUnit baseUnit) {
    final smallest = baseUnit.smallestUnits;
    return (cents * smallest * 2 + content) ~/ (content * 2);
  }
}

/// Cross multiplication: `p₁/q₁` against `p₂/q₂` is `p₁·q₂` against `p₂·q₁`.
/// **Nothing rounded before comparing** — which is what the requirement asks.
///
/// Two lines of the same cost fall back to the picker's order, so the list
/// does not tremble between two reads — and no third tiebreak is written
/// here, because `compareForPicker` already ends on the id.
int _compareContenders(_Contender a, _Contender b) {
  final byCost = (a.cents * b.content).compareTo(b.cents * a.content);
  if (byCost != 0) return byCost;
  return compareForPicker(a.option, b.option);
}

/// Is [line] above the 1% cut against the best [leader]?
///
/// `100 × (p·q_b − p_b·q) >= threshold × (p·q_b)`, all in integers and over
/// the full value (the ruler of D-s).
bool _differs(_Contender line, _Contender leader) {
  final mine = line.cents * leader.content;
  final theirs = leader.cents * line.content;
  final excess = mine - theirs;
  if (excess <= 0) return false;
  return excess * 100 >= costTieThreshold * mine;
}

/// How much cheaper the best one is than this line, as a whole percentage —
/// `null` when the difference does not reach the cut.
int? _savingPercent(_Contender line, _Contender leader) {
  if (!_differs(line, leader)) return null;
  final mine = line.cents * leader.content;
  final excess = mine - leader.cents * line.content;
  // Half-up without a single division in floating point:
  // floor(v + 0.5) == (2·numerator + denominator) ~/ (2·denominator).
  return (excess * 100 * 2 + mine) ~/ (mine * 2);
}

/// The footer. **Four sentences, and choosing between them is the rule** —
/// which is why it lives here and not in an `if` inside a `build()`.
String _headline({
  required List<_Contender> competing,
  required _Contender? leader,
  required bool tied,
  required bool anyPrice,
  required BaseUnit baseUnit,
}) {
  // No purchase of the type inside the window at all: the panel opened whole
  // and empty.
  if (!anyPrice) return 'Digite os preços que você está vendo.';
  if (leader == null || competing.length < 2) {
    return 'Preencha o preço de duas opções.';
  }
  if (tied) return 'Custo praticamente igual.';

  // The BIGGEST difference — against the dearest line — which is what the
  // wireframe has the footer repeat in a sentence.
  final worst = competing.last;
  final percent = _savingPercent(worst, leader);
  if (percent == null) return 'Custo praticamente igual.';
  return '${leader.option.label} — $percent% mais barato ${_perUnit(baseUnit)}';
}

/// pt-BR: the title of the panel says **which unit the computation is in**,
/// because the one that rules is the type's base unit, not the size of any
/// of the packagings.
String costHeaderFor(BaseUnit baseUnit) => switch (baseUnit) {
  BaseUnit.kilogram => 'custo por kg',
  BaseUnit.liter => 'custo por litro',
  BaseUnit.unit => 'custo por unidade',
};

/// pt-BR: the end of the footer's sentence. **The article changes with the
/// unit** — "o kg", "o litro", "a unidade" — which is why it does not come
/// out of mechanical concatenation with the column's label.
String _perUnit(BaseUnit baseUnit) => switch (baseUnit) {
  BaseUnit.kilogram => 'o kg',
  BaseUnit.liter => 'o litro',
  BaseUnit.unit => 'a unidade',
};
