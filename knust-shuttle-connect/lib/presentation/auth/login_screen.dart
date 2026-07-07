import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

enum _AuthMethod { email, phone }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();
  _AuthMethod _method = _AuthMethod.email;
  bool _registering = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    if (_registering) {
      await auth.register(_email.text, _password.text);
      if (auth.error == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created — check your email to verify it.'),
        ));
      }
    } else {
      await auth.signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.directions_bus_filled,
                      size: 72, color: AppColors.knustRed),
                  const SizedBox(height: 12),
                  Text(
                    'KNUST Shuttle Connect',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (!auth.awaitingSmsCode)
                    SegmentedButton<_AuthMethod>(
                      segments: const [
                        ButtonSegment(
                          value: _AuthMethod.email,
                          icon: Icon(Icons.email_outlined),
                          label: Text('Student email'),
                        ),
                        ButtonSegment(
                          value: _AuthMethod.phone,
                          icon: Icon(Icons.sms_outlined),
                          label: Text('Phone (OTP)'),
                        ),
                      ],
                      selected: {_method},
                      onSelectionChanged: auth.busy
                          ? null
                          : (selection) =>
                              setState(() => _method = selection.first),
                    ),
                  const SizedBox(height: 20),
                  if (auth.error != null) ...[
                    Text(
                      auth.error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (auth.awaitingSmsCode)
                    _buildOtpEntry(auth)
                  else if (_method == _AuthMethod.email)
                    _buildEmailForm(auth)
                  else
                    _buildPhoneEntry(auth),
                  const SizedBox(height: 16),
                  Text(
                    'Drivers: use the account provided by the transport '
                    'office. Your identity is never shown to other users — '
                    'see the privacy policy in Settings.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(AuthController auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@st.knust.edu.gh',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
            onFieldSubmitted: (_) => _submitEmail(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.busy ? null : _submitEmail,
            child: auth.busy
                ? const _ButtonSpinner()
                : Text(_registering ? 'Create account' : 'Sign in'),
          ),
          TextButton(
            onPressed: auth.busy
                ? null
                : () => setState(() => _registering = !_registering),
            child: Text(_registering
                ? 'Already have an account? Sign in'
                : 'New student? Create an account'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneEntry(AuthController auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '055 123 4567',
            prefixText: '🇬🇭 ',
            border: OutlineInputBorder(),
            helperText: 'We’ll text you a one-time code (standard SMS rates).',
          ),
          onSubmitted: (_) => auth.startPhoneSignIn(_phone.text),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: auth.busy ? null : () => auth.startPhoneSignIn(_phone.text),
          child: auth.busy ? const _ButtonSpinner() : const Text('Send code'),
        ),
      ],
    );
  }

  Widget _buildOtpEntry(AuthController auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to\n${auth.pendingPhoneNumber ?? 'your phone'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _smsCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => auth.confirmSmsCode(_smsCode.text),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed:
              auth.busy ? null : () => auth.confirmSmsCode(_smsCode.text),
          child: auth.busy ? const _ButtonSpinner() : const Text('Verify'),
        ),
        TextButton(
          onPressed: auth.busy
              ? null
              : () {
                  _smsCode.clear();
                  auth.cancelPhoneSignIn();
                },
          child: const Text('Wrong number / resend'),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
}
