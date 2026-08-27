// Smoke tests that don't require a live Supabase connection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madrasa/features/auth/auth_service.dart';
import 'package:madrasa/l10n/strings.dart';

void main() {
  test('phone normalizes to E.164 without +', () {
    expect(AuthService.normalizePhone('12345678', countryCode: '222'),
        '22212345678');
    expect(AuthService.normalizePhone('012345678', countryCode: '222'),
        '22212345678');
    expect(AuthService.normalizePhone('+222 12 34 56 78', countryCode: '222'),
        '22212345678');
    expect(AuthService.normalizePhone('00222 12345678', countryCode: '222'),
        '22212345678');
  });

  testWidgets('localized strings resolve for ar/fr/en', (tester) async {
    for (final code in ['ar', 'fr', 'en']) {
      final s = AppStrings(Locale(code));
      expect(s.sendCode, isNotEmpty);
      expect(s.otpSentTo('222X').contains('222X'), isTrue);
    }
  });
}
