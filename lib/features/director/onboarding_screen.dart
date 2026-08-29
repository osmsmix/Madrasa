import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../l10n/strings.dart';
import '../../widgets/language_menu.dart';
import '../../widgets/madrasa_logo.dart';
import 'widgets.dart';

/// Shown when a signed-in user is linked to no school. Lets them self-onboard as
/// a director by creating a school; otherwise explains they may be pending.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onSchoolCreated});

  /// Called after a school is created so the router can re-resolve the role.
  final VoidCallback onSchoolCreated;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Future<void> _openCreateDialog() async {
    final created = await showDialog<School>(
      context: context,
      builder: (_) => const CreateSchoolDialog(),
    );
    if (created != null) widget.onSchoolCreated();
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MadrasaLogo(size: 88),
                  const SizedBox(height: 20),
                  Text(s.welcomeTitle,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(s.welcomeBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_business),
                    label: Text(s.createSchoolCta),
                    onPressed: _openCreateDialog,
                  ),
                  const SizedBox(height: 16),
                  Text(s.waitingNote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor)),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(s.signOut),
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
