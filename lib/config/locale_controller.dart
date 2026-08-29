import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app locale and persists the user's choice. `null` = follow the
/// device language (resolved to one of ar/fr/en, defaulting to Arabic).
class LocaleController extends ChangeNotifier {
  LocaleController() {
    _load();
  }

  static const _key = 'app_locale';
  static const supported = ['ar', 'fr', 'en'];

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && supported.contains(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
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
