import 'package:supabase_flutter/supabase_flutter.dart';

enum AppRole { director, teacher, parent }

/// One place the user can enter: a specific school in a specific role. A person
/// may hold several — director of one school, teacher in another, parent in a
/// third (or even multiple roles in the same school).
class MembershipContext {
  MembershipContext({
    required this.schoolId,
    required this.schoolName,
    required this.role,
  });

  final String schoolId;
  final String schoolName;
  final AppRole role;
}

/// Resolves every (school, role) the signed-in user has.
class RoleResolver {
  RoleResolver(this._client);
  final SupabaseClient _client;

  Future<List<MembershipContext>> resolve() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final contexts = <MembershipContext>[];

    // director / teacher — via memberships (with the school name)
    final memberships = await _client
        .from('memberships')
        .select('role, school_id, schools(name)')
        .eq('user_id', user.id)
        .inFilter('role', ['director', 'teacher']);
    for (final m in memberships as List) {
      final school = m['schools'] as Map<String, dynamic>?;
      // A null joined school means it's hidden by RLS (e.g. a teacher's school
      // is not activated yet) — skip it so no dead entry shows.
      if (school == null) continue;
      contexts.add(MembershipContext(
        schoolId: m['school_id'] as String,
        schoolName: (school['name'] ?? '') as String,
        role: m['role'] == 'director' ? AppRole.director : AppRole.teacher,
      ));
    }

    // parent — the distinct schools where a student lists this phone as a parent
    final phone = user.phone;
    if (phone != null && phone.isNotEmpty) {
      final kids = await _client
          .from('students')
          .select('school_id, schools(name)')
          .or('parent_phone_1.eq.$phone,parent_phone_2.eq.$phone');
      final seen = <String>{};
      for (final k in kids as List) {
        final sid = k['school_id'] as String;
        final school = k['schools'] as Map<String, dynamic>?;
        // Skip children whose school is not visible (not activated yet).
        if (school == null) continue;
        if (seen.add(sid)) {
          contexts.add(MembershipContext(
            schoolId: sid,
            schoolName: (school['name'] ?? '') as String,
            role: AppRole.parent,
          ));
        }
      }
    }

    contexts.sort((a, b) {
      final c = a.schoolName.toLowerCase().compareTo(b.schoolName.toLowerCase());
      return c != 0 ? c : a.role.index.compareTo(b.role.index);
    });
    return contexts;
  }
}
