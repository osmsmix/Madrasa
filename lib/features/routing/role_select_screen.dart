import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../l10n/strings.dart';
import '../../widgets/language_menu.dart';
import '../../widgets/madrasa_logo.dart';
import '../director/widgets.dart';
import 'role_resolver.dart';

/// Always shown after sign-in: the user picks which school + role to enter, or
/// creates their own school (becoming its director). A brand-new user with no
/// links just sees the create option and a note that their school may add them.
class SchoolRoleSelectScreen extends StatelessWidget {
  const SchoolRoleSelectScreen({
    super.key,
    required this.contexts,
    required this.onSelected,
    required this.onReload,
  });

  final List<MembershipContext> contexts;
  final ValueChanged<MembershipContext> onSelected;

  /// Re-resolve contexts (e.g. after creating a new school).
  final VoidCallback onReload;

  Future<void> _createSchool(BuildContext context) async {
    final created = await showDialog<School>(
      context: context,
      builder: (_) => const CreateSchoolDialog(),
    );
    if (created != null) onReload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final empty = contexts.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.chooseAccess),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              const Center(child: MadrasaLogo(size: 64)),
              const SizedBox(height: 16),
              if (empty) ...[
                Text(s.welcomeBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
              ],
              for (final ctx in contexts)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(_icon(ctx.role),
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                    title: Text(ctx.schoolName,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(_roleLabel(context, ctx.role)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelected(ctx),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_business),
                label: Text(s.createSchoolCta),
                onPressed: () => _createSchool(context),
              ),
              if (empty) ...[
                const SizedBox(height: 16),
                Text(s.waitingNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(AppRole role) => switch (role) {
        AppRole.director => Icons.apartment,
        AppRole.teacher => Icons.co_present,
        AppRole.parent => Icons.family_restroom,
      };

  String _roleLabel(BuildContext context, AppRole role) {
    final s = context.s;
    return switch (role) {
      AppRole.director => s.roleDirector,
      AppRole.teacher => s.roleTeacher,
      AppRole.parent => s.roleParent,
    };
  }
}
