import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekton_core/tekton_core.dart';

import '../view_model/login_view_model.dart';

/// Sign-in: e-mail and password on top, then the button.
///
/// The screen has no route here and does not navigate: once the session
/// exists, the router's redirect takes the person out.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    // Captured BEFORE the await: after it, this context may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(loginViewModelProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!mounted || error == null) return;
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(loginViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de compras')),
      // A Builder so the SnackBar finds a context BELOW the Scaffold.
      body: Builder(
        builder: (context) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppTextField(
              controller: _email,
              hintText: 'E-mail',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autofocus: true,
              enabled: !busy,
            ),
            const SizedBox(height: 16),
            // AppTextField has no `obscureText`, and a password must never
            // show on screen: this one field is a plain TextField dressed
            // like it (filled, label always floating).
            TextField(
              controller: _password,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(context),
              decoration: const InputDecoration(
                labelText: 'Senha',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : () => _submit(context),
              child: Text(busy ? 'Entrando...' : 'Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
