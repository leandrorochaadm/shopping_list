import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/report_period.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/message_view.dart';
import '../../device_user/view_model/device_user_view_model.dart';
import '../../device_user/widgets/device_user_options.dart';
import '../view_model/spending_cap_view_model.dart';
import 'spending_cap_section.dart';

/// Settings — the month's spending cap (H13) and the device user label (H1).
///
/// The cap comes first because it is the one thing here that is read and
/// changed more than once: the label is written on the first opening and then
/// almost never again.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

  /// The phone's day, read ONCE and rounded (rule 9). A fresh instant per
  /// frame would build a different `ReportPeriod` on every rebuild, and the
  /// cap family would read the month over and over.
  late final DateTime _today = dayOf(DateTime.now());

  late final ReportPeriod _month = ReportPeriod.monthOf(_today);

  Future<void> _save(String name) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    final error = await ref.read(deviceUserViewModelProvider.notifier).save(
      name,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Agora este aparelho é $name.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceUserViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        // R11: installed on the home screen there is no browser Back button.
        leading: context.canPop()
            ? BackButton(onPressed: context.pop)
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Ir para a lista',
                onPressed: () => context.go(Routes.shoppingList),
              ),
      ),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => RefreshIndicator(
          // The other half of how the cap stays current: whoever already had
          // this screen open when a purchase was registered on the other
          // phone pulls, and the month's spending comes back updated.
          onRefresh: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await ref
                .read(spendingCapViewModelProvider(_month).notifier)
                .refresh();
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
            }
          },
          // A ListView in EVERY state — the loading and the error of both
          // sections live INSIDE it, so the pull to refresh never lands on a
          // plain Center, which is exactly where it is needed most.
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              SpendingCapSection(today: _today),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Quem está usando este aparelho',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              switch (state) {
                AsyncLoading() when !state.hasValue => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                AsyncError() when !state.hasValue => const MessageView(
                  'Não foi possível ler quem está usando este aparelho.',
                ),
                // The change is applied on the tap: no password and no
                // confirmation dialog, by decision — it is a label, not an
                // identity.
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A troca vale a partir da próxima compra lançada aqui. '
                      'As compras já lançadas continuam com o nome de quem as '
                      'lançou.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    DeviceUserOptions(
                      selected: state.value?.name,
                      onChanged: _saving
                          ? null
                          : (name) {
                              if (name != null) _save(name);
                            },
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
