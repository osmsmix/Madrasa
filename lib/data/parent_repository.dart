import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Data access for a parent: their children in a school, and each child's grades
/// and attendance. Parents are matched to students by phone via RLS; a parent
/// may also mark an absence excused.
class ParentRepository {
  ParentRepository(this._c);
  final SupabaseClient _c;

  /// The signed-in parent's children in [schoolId] (matched by phone in RLS).
  Future<List<Student>> children(String schoolId) async {
    final phone = _c.auth.currentUser?.phone;
    if (phone == null) return const [];
    final rows = await _c
        .from('students')
        .select()
        .eq('school_id', schoolId)
        .or('parent_phone_1.eq.$phone,parent_phone_2.eq.$phone')
        .order('full_name');
    return (rows as List)
        .map((r) => Student.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// A child's grades, grouped by subject.
  Future<List<ParentSubjectGrades>> grades(String studentId) async {
    final rows = await _c
        .from('grades')
        .select(
            'value, assessments(title, type, date, max_grade, coefficient, class_subjects(subjects(name)))')
        .eq('student_id', studentId);

    final bySubject = <String, List<ParentGradeEntry>>{};
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final a = m['assessments'] as Map<String, dynamic>?;
      if (a == null) continue;
      final cs = a['class_subjects'] as Map<String, dynamic>?;
      final subj = cs?['subjects'] as Map<String, dynamic>?;
      final subjectName = (subj?['name'] ?? '') as String;
      bySubject.putIfAbsent(subjectName, () => []).add(ParentGradeEntry(
            title: (a['title'] ?? '') as String,
            type: AssessmentType.fromDb(a['type'] as String?),
            date: DateTime.tryParse('${a['date']}') ?? DateTime.now(),
            maxGrade: (a['max_grade'] as num?)?.toDouble() ?? 20,
            coefficient: (a['coefficient'] as num?)?.toDouble() ?? 1,
            value: (m['value'] as num?)?.toDouble(),
          ));
    }
    final result = bySubject.entries
        .map((e) => ParentSubjectGrades(
            subjectName: e.key,
            entries: e.value
              ..sort((a, b) => b.date.compareTo(a.date))))
        .toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return result;
  }

  /// A child's attendance records (most recent first).
  Future<List<ParentAttendanceEntry>> attendance(String studentId) async {
    final rows = await _c
        .from('attendance')
        .select(
            'id, status, excused, excuse_reason, sessions(date, schedule_slots(class_subjects(subjects(name))))')
        .eq('student_id', studentId);

    final list = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final session = m['sessions'] as Map<String, dynamic>?;
      final slot = session?['schedule_slots'] as Map<String, dynamic>?;
      final cs = slot?['class_subjects'] as Map<String, dynamic>?;
      final subj = cs?['subjects'] as Map<String, dynamic>?;
      return ParentAttendanceEntry(
        id: m['id'] as String,
        date: DateTime.tryParse('${session?['date']}') ?? DateTime.now(),
        subjectName: (subj?['name'] ?? '') as String,
        status: AttendanceStatus.fromDb(m['status'] as String?),
        excused: (m['excused'] as bool?) ?? false,
        reason: m['excuse_reason'] as String?,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Mark (or unmark) an absence/late as excused, with an optional reason.
  Future<void> setExcused(String attendanceId, bool excused,
      {String? reason}) async {
    await _c.from('attendance').update({
      'excused': excused,
      'excuse_reason': excused ? reason : null,
      'excused_by': excused ? _c.auth.currentUser?.id : null,
      'excused_at': excused ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', attendanceId);
  }
}
