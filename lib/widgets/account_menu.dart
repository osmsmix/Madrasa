import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/routing/role_controller.dart';
import '../l10n/strings.dart';

/// App-bar account menu: sign out, and delete account (required by the App
/// Store for any app with account creation). Replaces the plain sign-out icon.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  Future<void> _delete(BuildContext context) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final client = Supabase.instance.client;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(s.deleteAccount),
        content: Text(s.deleteAccountWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await client.functions.invoke('delete-account');
      await client.auth.signOut();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Available only inside a role app (not on the chooser itself).
    RoleController? role;
    try {
      role = context.read<RoleController>();
    } catch (_) {
      role = null;
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: s.account,
      onSelected: (v) {
        if (v == 'switch') {
          role?.backToChooser();
        } else if (v == 'signout') {
          Supabase.instance.client.auth.signOut();
        } else if (v == 'delete') {
          _delete(context);
        }
      },
      itemBuilder: (context) => [
        if (role != null)
          PopupMenuItem(
            value: 'switch',
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, size: 18),
                const SizedBox(width: 10),
                Text(s.switchAccess),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18),
              const SizedBox(width: 10),
              Text(s.signOut),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 10),
              Text(s.deleteAccount,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
