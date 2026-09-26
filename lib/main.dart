import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'config/locale_controller.dart';
import 'config/theme.dart';
import 'data/academic_repository.dart';
import 'data/bulletin_repository.dart';
import 'data/parent_repository.dart';
import 'data/school_repository.dart';
import 'data/teacher_repository.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_service.dart';
import 'features/routing/role_resolver.dart';
import 'l10n/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make every framework/uncaught error visible in the console during setup.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  await Future.wait(
    ['ar', 'fr', 'en'].map((l) => initializeDateFormatting(l, null)),
  );

  if (!Env.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // publishable/anon key — safe to ship in a client; RLS protects the data.
    // ignore: deprecated_member_use
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const MadrasaApp());
}

class MadrasaApp extends StatelessWidget {
  const MadrasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        Provider(create: (_) => AuthService(client)),
        Provider(create: (_) => RoleResolver(client)),
        Provider(create: (_) => SchoolRepository(client)),
        Provider(create: (_) => AcademicRepository(client)),
        Provider(create: (_) => TeacherRepository(client)),
        Provider(create: (_) => ParentRepository(client)),
        Provider(create: (_) => BulletinRepository(client)),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => MaterialApp(
          title: 'Madrasa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: locale.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Default to device language when supported, else Arabic (RTL handled
          // automatically by the framework for 'ar').
          localeResolutionCallback: (device, supported) =>
              LocaleController.resolve(device, supported),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY were not provided via --dart-define.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Missing Supabase configuration.\n\n'
              'Run with:\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
