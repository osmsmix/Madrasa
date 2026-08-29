import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/locale_controller.dart';

/// A globe button that switches the app language (ar / fr / en). Language names
/// are shown in their own script, not translated. Drop it into any AppBar's
/// actions, or anywhere on a screen.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  static const _languages = [
    ('ar', 'العربية'),
    ('fr', 'Français'),
    ('en', 'English'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    final current = controller.locale?.languageCode;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: 'Language / اللغة',
      onSelected: (code) =>
          context.read<LocaleController>().setLocale(Locale(code)),
      itemBuilder: (context) => [
        for (final (code, name) in _languages)
          CheckedPopupMenuItem<String>(
            value: code,
            checked: current == code,
            child: Text(name),
          ),
      ],
    );
  }
}
