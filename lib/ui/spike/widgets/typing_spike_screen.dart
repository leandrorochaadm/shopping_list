import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';

/// **Throwaway screen — spike S1.** Delete it, its route and its test as soon
/// as the measurement is recorded in `docs/pendencias-lista-de-compras.md`
/// (item A2).
///
/// It exists to measure `R1` (Flutter Web performance on an iPhone 12) and
/// `R10` (the keyboard covering the field, focus escaping, the caret landing
/// somewhere else) TOGETHER, on the installed PWA — never in a Safari tab.
/// Requirement 3 is twenty fields in two minutes, eight times a month: if
/// typing does not hold up, decision 2 (PWA as the only platform) goes back on
/// the table on day one instead of after forty days of built screens.
///
/// The three fields are the three kinds the real purchase screen has — free
/// text, a whole number and an amount — because each one opens a different
/// iOS keyboard, and the amount is the one that historically misplaces the
/// caret.
class TypingSpikeScreen extends StatefulWidget {
  const TypingSpikeScreen({super.key});

  @override
  State<TypingSpikeScreen> createState() => _TypingSpikeScreenState();
}

class _TypingSpikeScreenState extends State<TypingSpikeScreen> {
  // A Stopwatch, not DateTime.now(): what is being measured is elapsed time on
  // this device, and no rule of the domain reads this clock.
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Starts on the FIRST keystroke, not when the screen opens: the number that
  /// matters is typing time, not how long it took to reach for the phone.
  void _startOnFirstKeystroke() {
    if (_stopwatch.isRunning || _stopwatch.elapsed > Duration.zero) return;
    _stopwatch.start();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  void _finish() {
    _ticker?.cancel();
    _stopwatch.stop();
    setState(() {});
  }

  void _reset() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {});
  }

  String get _elapsedLabel {
    final elapsed = _stopwatch.elapsed;
    final seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return '${elapsed.inMinutes}min ${seconds.padLeft(4, '0')}s';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Teste de digitação'),
      leading: IconButton(
        icon: const Icon(Icons.home_outlined),
        tooltip: 'Ir para a lista',
        onPressed: () => context.go(Routes.shoppingList),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Preencha os três campos como se estivesse no corredor do '
            'mercado. O cronômetro começa na primeira tecla.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            _elapsedLabel,
            key: const Key('spike-elapsed'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('spike-product'),
            decoration: const InputDecoration(
              labelText: 'Produto',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _startOnFirstKeystroke(),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('spike-quantity'),
            decoration: const InputDecoration(
              labelText: 'Quantidade',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _startOnFirstKeystroke(),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('spike-amount'),
            decoration: const InputDecoration(
              labelText: 'Valor pago',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => _startOnFirstKeystroke(),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _finish, child: const Text('Concluir')),
          const SizedBox(height: 8),
          TextButton(onPressed: _reset, child: const Text('Zerar')),
          // Room to scroll the last field above the iOS keyboard: without it
          // the screen would fail R10 for a reason that is ours, not the
          // platform's, and the measurement would blame the wrong thing.
          const SizedBox(height: 320),
        ],
      ),
    ),
  );
}
