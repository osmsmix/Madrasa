import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Data access for the director's school setup: school, school years, terms.
/// All calls run under RLS as the signed-in user.
class SchoolRepository {
  SchoolRepository(this._c);
  final SupabaseClient _c;

  // ── School ────────────────────────────────────────────────────────────────

  /// Create a school and make the caller its director (atomic RPC).
  Future<School> createSchool({
    required String name,
    required TermType termType,
    required double gradeMax,
  }) async {
    final row = await _c.rpc('create_school_with_director', params: {
      'p_name': name,
      'p_term_type': termType.db,
      'p_grade_max': gradeMax,
    });
    // RPC returns the schools row (as a map, or a single-element list).
    final map = row is List ? row.first as Map<String, dynamic> : row as Map<String, dynamic>;
    return School.fromMap(map);
  }

  /// Schools where the current user is a director. Matched by phone (the stable
  /// identity) so memberships created after the account existed are still found.
  Future<List<School>> mySchools() async {
    final phone = _c.auth.currentUser?.phone ?? '';
    final rows = await _c
        .from('memberships')
        .select('schools(*)')
        .eq('phone', phone)
        .eq('role', 'director');
    return (rows as List)
        .map((r) => r['schools'])
        .whereType<Map<String, dynamic>>()
        .map(School.fromMap)
        .toList();
  }

  /// Permanently delete a school and everything under it (cascades via FKs).
  /// RLS allows this only for a director of that school.
  Future<void> deleteSchool(String id) async {
    await _c.from('schools').delete().eq('id', id);
  }

  /// Fetch a single school by id (visible to its director/teacher/parent via RLS).
  Future<School?> schoolById(String id) async {
    final row = await _c.from('schools').select().eq('id', id).maybeSingle();
    return row == null ? null : School.fromMap(row);
  }

  Future<School> updateSchool(School s) async {
    final row = await _c
        .from('schools')
        .update({
          'name': s.name,
          'term_type': s.termType.db,
          'grade_max': s.gradeMax,
        })
        .eq('id', s.id)
        .select()
        .single();
    return School.fromMap(row);
  }

  // ── School years ────────────────────────────────────────────────────────

  Future<List<SchoolYear>> years(String schoolId) async {
    final rows = await _c
        .from('school_years')
        .select()
        .eq('school_id', schoolId)
        .order('starts_on', ascending: false)
        .order('label', ascending: false);
    return (rows as List)
        .map((r) => SchoolYear.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Create a year and its terms (count from [termType]) in one flow.
  /// [termLabels] must have exactly [termType].count entries (localized in UI).
  Future<SchoolYear> createYearWithTerms({
    required String schoolId,
    required String label,
    required TermType termType,
    required List<String> termLabels,
    DateTime? startsOn,
    DateTime? endsOn,
    bool makeActive = true,
  }) async {
    if (makeActive) {
      await _c
          .from('school_years')
          .update({'is_active': false})
          .eq('school_id', schoolId);
    }
    final yearRow = await _c
        .from('school_years')
        .insert({
          'school_id': schoolId,
          'label': label,
          'starts_on': dateToDb(startsOn),
          'ends_on': dateToDb(endsOn),
          'is_active': makeActive,
        })
        .select()
        .single();
    final year = SchoolYear.fromMap(yearRow);

    final terms = [
      for (var i = 0; i < termType.count; i++)
        {
          'school_year_id': year.id,
          'idx': i + 1,
          'label': i < termLabels.length ? termLabels[i] : '${i + 1}',
        }
    ];
    await _c.from('terms').insert(terms);
    return year;
  }

  Future<void> setActiveYear(String schoolId, String yearId) async {
    await _c
        .from('school_years')
        .update({'is_active': false})
        .eq('school_id', schoolId);
    await _c.from('school_years').update({'is_active': true}).eq('id', yearId);
  }

  /// Returns the number of rows actually deleted. 0 usually means an RLS policy
  /// silently blocked it (no exception is raised for a filtered delete).
  Future<int> deleteYear(String yearId) async {
    final rows =
        await _c.from('school_years').delete().eq('id', yearId).select('id');
    return (rows as List).length;
  }

  // ── Terms ─────────────────────────────────────────────────────────────────

  Future<List<Term>> terms(String yearId) async {
    final rows = await _c
        .from('terms')
        .select()
        .eq('school_year_id', yearId)
        .order('idx');
    return (rows as List)
        .map((r) => Term.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
