import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/message_view.dart';
import '../../device_user/view_model/device_user_view_model.dart';
import '../../device_user/widgets/device_user_options.dart';

/// Settings, and for now ONLY the device user label.
///
/// The spending cap and the rest of the screen arrive with H13. This much
/// exists here because one of H1's acceptance criteria is changing the label
/// after the first opening — "sem senha e sem confirmação" — and without this
/// screen that criterion would have no owner until H13.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

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
      body: Builder(
        builder: (context) => switch (state) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError() => const MessageView(
            'Não foi possível ler quem está usando este aparelho.',
          ),
          // The change is applied on the tap: no password and no confirmation
          // dialog, by decision — it is a label, not an identity.
          _ => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Quem está usando este aparelho',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'A troca vale a partir da próxima compra lançada aqui. As '
                'compras já lançadas continuam com o nome de quem as lançou.',
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
      ),
    );
  }
}
