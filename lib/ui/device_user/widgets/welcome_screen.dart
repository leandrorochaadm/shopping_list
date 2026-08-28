import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/message_view.dart';
import '../view_model/device_user_view_model.dart';
import 'device_user_options.dart';

/// First opening of a device: it asks who is using it, once, and never again.
///
/// It carries NO exit of its own, and that is not an oversight of `R11`: with
/// no label saved, every other route redirects straight back here, so a way
/// out would be a button that returns to this same screen. The exit is
/// answering the question.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String? _selected;
  bool _saving = false;

  Future<void> _save(String name) async {
    // Captured BEFORE the await: after it, this context may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _saving = true);
    final error = await ref.read(deviceUserViewModelProvider.notifier).save(
      name,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    router.go(Routes.shoppingList);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceUserViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quem está usando?')),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => switch (state) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError() => _RetryView(
            onRetry: () =>
                ref.read(deviceUserViewModelProvider.notifier).refresh(),
          ),
          _ => _Form(
            selected: _selected,
            saving: _saving,
            onChanged: (name) => setState(() => _selected = name),
            onConfirm: _save,
          ),
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.selected,
    required this.saving,
    required this.onChanged,
    required this.onConfirm,
  });

  final String? selected;
  final bool saving;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onConfirm;

  @override
  Widget build(BuildContext context) => ListView(
    // Scrollable in every state, so the screen behaves the same on a small
    // phone with the keyboard up.
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Este aparelho fica marcado com um nome, e é ele que aparece em cada '
        'compra lançada aqui. Dá para trocar depois, em Configurações.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      DeviceUserOptions(
        selected: selected,
        onChanged: saving ? null : onChanged,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: selected == null || saving
            ? null
            : () => onConfirm(selected!),
        child: Text(saving ? 'Salvando...' : 'Continuar'),
      ),
    ],
  );
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry});

  final Future<String?> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(
        child: MessageView('Não foi possível abrir o app neste aparelho.'),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton(
          onPressed: onRetry,
          child: const Text('Tentar de novo'),
        ),
      ),
    ],
  );
}
