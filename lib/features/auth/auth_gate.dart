import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/strings.dart';
import '../director/director_app.dart';
import '../parent/parent_app.dart';
import '../routing/role_controller.dart';
import '../routing/role_resolver.dart';
import '../routing/role_select_screen.dart';
import '../teacher/teacher_app.dart';
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
  late Future<List<MembershipContext>> _future;
  MembershipContext? _selected;

  @override
  void initState() {
    super.initState();
    _future = context.read<RoleResolver>().resolve();
  }

  void _reload() {
    setState(() {
      _selected = null;
      _future = context.read<RoleResolver>().resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MembershipContext>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _ErrorRetry(onRetry: _reload);
        }

        // Everyone goes through the chooser each sign-in (even with a single
        // context), and can create their own school from there.
        final contexts = snapshot.data ?? const [];
        if (_selected != null) {
          // Expose a "back to chooser" action to the active role app.
          return Provider<RoleController>.value(
            value: RoleController(() => setState(() => _selected = null)),
            child: _shellFor(_selected!),
          );
        }
        return SchoolRoleSelectScreen(
          contexts: contexts,
          onSelected: (c) => setState(() => _selected = c),
          onReload: _reload,
        );
      },
    );
  }

  Widget _shellFor(MembershipContext ctx) => switch (ctx.role) {
        AppRole.director => DirectorApp(initialSchoolId: ctx.schoolId),
        AppRole.teacher => TeacherApp(schoolId: ctx.schoolId),
        AppRole.parent => ParentApp(schoolId: ctx.schoolId),
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
