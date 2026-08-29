import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Auth wiring for the ChinqIT OTP flow.
///
/// The provider (via the `send-otp` / `verify-otp` Edge Functions) generates and
/// verifies the code. The password is a throwaway secret the user never sees:
/// we generate it, `verify-otp` sets it on the account, and we immediately sign
/// in with it. The persistent Supabase session then takes over.
class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  static final _rand = Random.secure();

  /// Normalise a user-entered phone to E.164 WITHOUT '+', e.g. 222XXXXXXXX.
  /// Strips non-digits and a single leading zero, then prepends the country code
  /// unless the number already starts with it.
  static String normalizePhone(String raw, {String? countryCode}) {
    final cc = countryCode ?? Env.defaultCountryCode;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith(cc)) return digits;
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '$cc$digits';
  }

  static String _randomPassword() {
    final bytes = List<int>.generate(24, (_) => _rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Ask ChinqIT to send a code to [phone] (already normalised).
  Future<void> sendOtp(String phone, {String? language}) async {
    try {
      await _client.functions.invoke(
        'send-otp',
        body: {'phone_number': phone, 'language': ?language},
      );
    } on FunctionException catch (e) {
      throw AuthException(
          _errorFrom(e.details) ?? 'send-otp failed (HTTP ${e.status})');
    }
  }

  /// Verify [code] with ChinqIT, then sign the user in.
  /// Returns the signed-in [User]. Throws [InvalidOtpException] on a bad code.
  Future<User> verifyAndSignIn(
    String phone,
    String code, {
    String? fullName,
  }) async {
    final password = _randomPassword();
    try {
      await _client.functions.invoke(
        'verify-otp',
        body: {
          'phone_number': phone,
          'user_code': code,
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
        },
      );
    } on FunctionException catch (e) {
      // Edge Function returned non-2xx (invoke throws rather than returning it).
      if (e.status == 401) throw const InvalidOtpException();
      throw AuthException(
          _errorFrom(e.details) ?? 'verify-otp failed (HTTP ${e.status})');
    }

    // verify-otp succeeded → sign in with the throwaway password.
    final auth = await _client.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
    final user = auth.user;
    if (user == null) throw const AuthException('sign-in failed');
    return user;
  }

  Future<void> signOut() => _client.auth.signOut();

  String? _errorFrom(dynamic data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['error'] is String) {
          return decoded['error'] as String;
        }
      } catch (_) {}
    }
    return null;
  }
}

class InvalidOtpException extends AuthException {
  const InvalidOtpException() : super('invalid or expired code');
}
