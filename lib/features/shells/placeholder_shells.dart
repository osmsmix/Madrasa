import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/strings.dart';
import '../../widgets/language_menu.dart';

/// Temporary landing screens per role. Step 2 only wires auth + routing; the real
/// director/teacher/parent features replace these in later steps.
class _RolePlaceholder extends StatelessWidget {
  const _RolePlaceholder({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          const LanguageMenu(),
          IconButton(
            tooltip: s.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class DirectorHome extends StatelessWidget {
  const DirectorHome({super.key});
  @override
  Widget build(BuildContext context) =>
      _RolePlaceholder(title: context.s.roleDirector, icon: Icons.apartment);
}

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});
  @override
  Widget build(BuildContext context) =>
      _RolePlaceholder(title: context.s.roleTeacher, icon: Icons.co_present);
}

class ParentHome extends StatelessWidget {
  const ParentHome({super.key});
  @override
  Widget build(BuildContext context) =>
      _RolePlaceholder(title: context.s.roleParent, icon: Icons.family_restroom);
}

/// Shown when a verified phone isn't linked to any school yet.
class NotLinkedScreen extends StatelessWidget {
  const NotLinkedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.notLinkedTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 72),
              const SizedBox(height: 16),
              Text(
                s.notLinkedBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(s.signOut),
                onPressed: () => Supabase.instance.client.auth.signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
