import 'package:flutter/material.dart';

/// Holds the app locale. `null` = follow the device language (resolved to one of
/// ar/fr/en, defaulting to Arabic). Switching happens via [setLocale] later
/// (e.g. a settings screen); RTL is handled automatically by MaterialApp for ar.
class LocaleController extends ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  /// Resolve the device/app locale to a supported one, defaulting to Arabic.
  static Locale resolve(Locale? device, Iterable<Locale> supported) {
    if (device != null) {
      for (final l in supported) {
        if (l.languageCode == device.languageCode) return l;
      }
    }
    return const Locale('ar');
  }
}
