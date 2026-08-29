import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../config/env.dart';
import '../../l10n/strings.dart';
import '../../widgets/language_menu.dart';
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

  static const _resendCooldown = 30; // seconds between SMS sends

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  String _normalizedPhone = '';
  int _resendIn = 0;
  Timer? _resendTimer;

  AuthService get _auth => context.read<AuthService>();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  /// Send (phone step): validate the form, then send to the entered number.
  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _send(AuthService.normalizePhone(_phoneCtrl.text), firstTime: true);
  }

  /// Resend (otp step): re-send to the already-known number, no form involved.
  Future<void> _resend() async {
    if (_resendIn > 0) return;
    await _send(_normalizedPhone, firstTime: false);
  }

  Future<void> _send(String phone, {required bool firstTime}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _normalizedPhone = phone;
        if (firstTime) _step = _Step.otp;
      });
      _startCooldown();
      if (!firstTime) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.otpSentTo('+$phone'))),
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
    } on AuthException catch (e) {
      // Surface the real cause (server/config error) while we're setting up.
      if (mounted) setState(() => _error = e.message);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageMenu()],
      ),
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
              onPressed: (_busy || _resendIn > 0) ? null : _resend,
              child: Text(
                _resendIn > 0 ? '${s.resendCode} ($_resendIn)' : s.resendCode,
              ),
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
