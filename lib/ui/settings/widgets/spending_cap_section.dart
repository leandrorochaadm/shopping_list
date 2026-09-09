import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../../../domain/models/money.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/spending_cap.dart';
import '../../core/app_failure.dart';
import '../../core/error_translation.dart';
import '../../core/formatting.dart';
import '../../core/widgets/message_view.dart';
import '../../core/widgets/warning_dialog.dart';
import '../view_model/spending_cap_view_model.dart';

/// The "Teto de gasto do mês" section of `/settings` — the value in force, the
/// field, `[ Salvar ]` and the sentence saying where the month stands.
///
/// [today] arrives from the screen, computed ONCE (rule 9): a fresh instant
/// per frame would build a different `ReportPeriod` every rebuild and make the
/// family read the month over and over.
class SpendingCapSection extends ConsumerStatefulWidget {
  const SpendingCapSection({required this.today, super.key});

  final DateTime today;

  @override
  ConsumerState<SpendingCapSection> createState() => _SpendingCapSectionState();
}

class _SpendingCapSectionState extends ConsumerState<SpendingCapSection> {
  final _controller = TextEditingController();
  bool _saving = false;

  /// What the field was last filled from, so the pre-fill happens once per cap
  /// and never over something half typed.
  SpendingCap? _filledFrom;

  late final ReportPeriod _month = ReportPeriod.monthOf(widget.today);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    // The mask leaves no malformed text to refuse, so the only no the screen
    // still owns is the EMPTY field. A typed zero is a different no, and it
    // is the DOMAIN's: `SpendingCap` has the sentence for it, and reading it
    // here would be the view reimplementing a rule (rule 11).
    if (_controller.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }
    final amount = Money(UnitSpec.currency.parse(_controller.text));

    setState(() => _saving = true);
    final outcome = await ref
        .read(spendingCapViewModelProvider(_month).notifier)
        .save(amount);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      // The reentrancy guard barred a second tap: nothing to show.
      case null:
        return;
      case CapSaved(:final triggered):
        messenger.showSnackBar(
          const SnackBar(content: Text('Teto do mês salvo.')),
        );
        if (triggered != null) await _warnOnTheSpot();
      case CapSaveFailed(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// "Vocês já estão em 87% deste teto neste mês."
  ///
  /// The percentage is ASKED of the domain (rule 11) over the state the save
  /// just wrote — it is not carried in the outcome, which would be a second
  /// place for the same number to live.
  Future<void> _warnOnTheSpot() async {
    final status = ref.read(spendingCapViewModelProvider(_month)).value;
    final cap = status?.cap;
    if (cap == null || !mounted) return;

    await showWarnings(context, [
      'Vocês já estão em ${cap.usagePercent(status!.spent)}% deste teto '
      'neste mês.',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spendingCapViewModelProvider(_month));

    // The pre-fill, done outside `setState` on purpose: it happens while the
    // state is being read, and the controller is not part of the widget's
    // own state.
    final cap = state.value?.cap;
    if (cap != null && cap != _filledFrom) {
      _filledFrom = cap;
      _controller.text = UnitSpec.currency.format(cap.amount.cents);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teto de gasto do mês',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        switch (state) {
          AsyncLoading() when !state.hasValue => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          AsyncError(:final error) when !state.hasValue => _ErrorBody(
            month: _month,
            error: error,
          ),
          _ => _Body(
            status: state.value!,
            controller: _controller,
            saving: _saving,
            onSave: _save,
          ),
        },
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.status,
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final MonthCapStatus status;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cap = status.cap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The empty state is a sentence and not a blank: a month with no cap
          // shows no line on the report either, and this is where that is
          // explained.
          cap == null
              ? 'Nenhum teto definido. O relatório do mês não mostra a linha '
                    '"Gastou X de Y" enquanto não houver um.'
              : 'Gastou ${formatMoney(status.spent)} de '
                    '${formatMoney(cap.amount)} neste mês.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        AppTextField.currency(
          key: const ValueKey('cap-amount'),
          controller: controller,
          enabled: !saving,
          decoration: const InputDecoration(
            labelText: 'Teto do mês',
            border: OutlineInputBorder(),
          ),
          onSubmitted: saving ? null : (_) => onSave(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey('save-cap'),
            onPressed: saving ? null : onSave,
            child: const Text('Salvar'),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.month, required this.error});

  final ReportPeriod month;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      // The raw exception NEVER reaches the screen — it goes to debugPrint.
      MessageView(translateFailure(AppFailure.from(error), 'ler o teto do mês')),
      Center(
        child: FilledButton(
          key: const ValueKey('retry-cap'),
          onPressed: () =>
              ref.read(spendingCapViewModelProvider(month).notifier).refresh(),
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}
