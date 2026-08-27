import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/strings.dart';
import '../routing/role_resolver.dart';
import '../routing/role_select_screen.dart';
import '../shells/placeholder_shells.dart';
import 'auth_screen.dart';

/// Root gate: no session → auth screen; session → resolve role(s) → route.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        if (session == null) return const AuthScreen();
        // Key by user id so switching accounts re-resolves the role.
        return _RoleRouter(key: ValueKey(session.user.id));
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  const _RoleRouter({super.key});
  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<List<AppRole>> _future;
  AppRole? _selected;

  @override
  void initState() {
    super.initState();
    _future = context.read<RoleResolver>().resolve();
  }

  void _reload() =>
      setState(() => _future = context.read<RoleResolver>().resolve());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppRole>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _ErrorRetry(onRetry: _reload);
        }

        final roles = snapshot.data ?? const [];
        if (roles.isEmpty) return const NotLinkedScreen();

        final role = _selected ?? (roles.length == 1 ? roles.first : null);
        if (role == null) {
          return RoleSelectScreen(
            roles: roles,
            onSelected: (r) => setState(() => _selected = r),
          );
        }
        return _shellFor(role);
      },
    );
  }

  Widget _shellFor(AppRole role) => switch (role) {
        AppRole.director => const DirectorHome(),
        AppRole.teacher => const TeacherHome(),
        AppRole.parent => const ParentHome(),
      };
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(s.genericError),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(s.retry)),
          ],
        ),
      ),
    );
  }
}
