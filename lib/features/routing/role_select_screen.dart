import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import 'role_resolver.dart';

/// Shown only when a user holds more than one role (e.g. teacher in one school,
/// parent in another). Lets them pick which hat to wear for this entry.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({
    super.key,
    required this.roles,
    required this.onSelected,
  });

  final List<AppRole> roles;
  final ValueChanged<AppRole> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.chooseRole)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final role in roles)
            Card(
              child: ListTile(
                leading: Icon(_icon(role)),
                title: Text(_label(context, role)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelected(role),
              ),
            ),
        ],
      ),
    );
  }

  IconData _icon(AppRole role) => switch (role) {
        AppRole.director => Icons.apartment,
        AppRole.teacher => Icons.co_present,
        AppRole.parent => Icons.family_restroom,
      };

  String _label(BuildContext context, AppRole role) {
    final s = context.s;
    return switch (role) {
      AppRole.director => s.roleDirector,
      AppRole.teacher => s.roleTeacher,
      AppRole.parent => s.roleParent,
    };
  }
}
