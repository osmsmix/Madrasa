import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/env.dart';
import '../../l10n/strings.dart';
import '../../widgets/madrasa_logo.dart';
import 'auth_service.dart';

/// Single-screen phone → OTP flow. On successful verification the Supabase
/// session changes and AuthGate swaps this screen out for the role router, so
/// there is no manual navigation here.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Step { phone, otp }

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  String _normalizedPhone = '';

  AuthService get _auth => context.read<AuthService>();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final phone = AuthService.normalizePhone(_phoneCtrl.text);
      await _auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _normalizedPhone = phone;
        _step = _Step.otp;
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.s.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.s.otpRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.verifyAndSignIn(_normalizedPhone, code);
      // success → AuthGate rebuilds; nothing to do here.
    } on InvalidOtpException {
      if (mounted) setState(() => _error = context.s.invalidCode);
    } catch (_) {
      if (mounted) setState(() => _error = context.s.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() {
    setState(() {
      _step = _Step.phone;
      _otpCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
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
                  const SizedBox(height: 24),
                  const Center(child: MadrasaLogo(size: 88)),
                  const SizedBox(height: 12),
                  Text(s.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  if (_step == _Step.phone) ..._phoneStep(s) else ..._otpStep(s),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(AppStrings s) => [
        Text(s.signInTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: InputDecoration(
              labelText: s.phoneLabel,
              hintText: s.phoneHint,
              prefixIcon: const Icon(Icons.phone),
              prefixText: '+${Env.defaultCountryCode} ',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: _busy
              ? const _Spinner()
              : Text(s.sendCode),
        ),
      ];

  List<Widget> _otpStep(AppStrings s) => [
        Text(s.otpTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          s.otpSentTo('+$_normalizedPhone'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: s.otpLabel),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy ? const _Spinner() : Text(s.verify),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy ? null : _changeNumber,
              child: Text(s.changeNumber),
            ),
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(s.resendCode),
            ),
          ],
        ),
      ];
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
}
