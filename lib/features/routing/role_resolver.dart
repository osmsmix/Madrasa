import 'package:supabase_flutter/supabase_flutter.dart';

enum AppRole { director, teacher, parent }

/// Resolves which role(s) the signed-in user has. A phone can be director/teacher
/// (via memberships) AND/OR parent (matched to students by phone) — possibly
/// across different schools. Returns them in priority order.
class RoleResolver {
  RoleResolver(this._client);
  final SupabaseClient _client;

  Future<List<AppRole>> resolve() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final roles = <AppRole>{};

    // director / teacher — via memberships (RLS lets a user read their own rows)
    final memberships = await _client
        .from('memberships')
        .select('role')
        .eq('user_id', user.id);
    for (final row in memberships as List) {
      switch (row['role']) {
        case 'director':
          roles.add(AppRole.director);
        case 'teacher':
          roles.add(AppRole.teacher);
      }
    }

    // parent — explicit phone match (independent of any membership role)
    final phone = user.phone;
    if (phone != null && phone.isNotEmpty) {
      final kids = await _client
          .from('students')
          .select('id')
          .or('parent_phone_1.eq.$phone,parent_phone_2.eq.$phone')
          .limit(1);
      if ((kids as List).isNotEmpty) roles.add(AppRole.parent);
    }

    // priority order for the picker / auto-route
    return [
      if (roles.contains(AppRole.director)) AppRole.director,
      if (roles.contains(AppRole.teacher)) AppRole.teacher,
      if (roles.contains(AppRole.parent)) AppRole.parent,
    ];
  }
}
