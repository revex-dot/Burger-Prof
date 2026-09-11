import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/common.dart';

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('🐾', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    l.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(l.tagline, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .signIn(_email.text.trim(), _password.text);
    } on FirebaseAuthException {
      if (mounted) showSnack(context, context.l10n.authError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showSnack(context, context.l10n.invalidEmail);
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) showSnack(context, context.l10n.resetEmailSent);
    } on FirebaseAuthException {
      if (mounted) showSnack(context, context.l10n.errorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _AuthScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l.email),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? l.invalidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: l.password),
              validator: (v) =>
                  (v == null || v.length < 8) ? l.passwordTooShort : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _reset,
                child: Text(l.forgotPassword),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.signIn),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(Routes.signup),
              child: Text(l.noAccountYet),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signUp(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            locale: Localizations.localeOf(context).languageCode,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, e.message ?? context.l10n.authError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _AuthScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.displayName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l.email),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? l.invalidEmail : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l.password),
              validator: (v) =>
                  (v == null || v.length < 8) ? l.passwordTooShort : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(l.createAccount),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: Text(l.alreadyHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
