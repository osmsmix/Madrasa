import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Data access for the teacher's daily work: their schedule, sessions, and
/// attendance. All calls run under RLS as the signed-in teacher.
class TeacherRepository {
  TeacherRepository(this._c);
  final SupabaseClient _c;

  Future<List<String>> _myMembershipIds({String? schoolId}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    var q = _c
        .from('memberships')
        .select('id')
        .eq('user_id', uid)
        .eq('role', 'teacher');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final rows = await q;
    return (rows as List).map((r) => r['id'] as String).toList();
  }

  /// The class_subjects this teacher is assigned to teach (optionally scoped to
  /// a single school — the one picked at login).
  Future<List<TeachingAssignment>> myAssignments({String? schoolId}) async {
    final ids = await _myMembershipIds(schoolId: schoolId);
    if (ids.isEmpty) return const [];
    final rows = await _c
        .from('class_subjects')
        .select('id, class_id, coefficient, classes(name), subjects(name)')
        .inFilter('teacher_membership_id', ids);
    final list = (rows as List)
        .map((r) => TeachingAssignment.fromMap(r as Map<String, dynamic>))
        .toList();
    list.sort((a, b) {
      final c = a.className.compareTo(b.className);
      return c != 0 ? c : a.subjectName.compareTo(b.subjectName);
    });
    return list;
  }

  /// All weekly timetable slots for this teacher's assignments.
  Future<List<TeacherSlot>> mySlots({String? schoolId}) async {
    final assignments = await myAssignments(schoolId: schoolId);
    if (assignments.isEmpty) return const [];
    final byCs = {for (final a in assignments) a.classSubjectId: a};
    final rows = await _c
        .from('schedule_slots')
        .select('id, class_subject_id, weekday, start_time, end_time, room')
        .inFilter('class_subject_id', byCs.keys.toList())
        .order('weekday')
        .order('start_time');
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final a = byCs[m['class_subject_id']]!;
      return TeacherSlot(
        id: m['id'] as String,
        classSubjectId: a.classSubjectId,
        classId: a.classId,
        className: a.className,
        subjectName: a.subjectName,
        weekday: (m['weekday'] as num).toInt(),
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        room: m['room'] as String?,
      );
    }).toList();
  }

  /// Find or create the concrete session for a slot on a given date; returns id.
  Future<String> ensureSession(String slotId, DateTime date) async {
    final dateStr = dateToDb(date)!;
    final existing = await _c
        .from('sessions')
        .select('id')
        .eq('schedule_slot_id', slotId)
        .eq('date', dateStr)
        .limit(1);
    if ((existing as List).isNotEmpty) {
      return existing.first['id'] as String;
    }
    final row = await _c
        .from('sessions')
        .insert({'schedule_slot_id': slotId, 'date': dateStr})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Student>> students(String classId) async {
    final rows = await _c
        .from('students')
        .select()
        .eq('class_id', classId)
        .order('full_name');
    return (rows as List)
        .map((r) => Student.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Current attendance for a session: student id → status.
  Future<Map<String, AttendanceStatus>> attendanceForSession(
      String sessionId) async {
    final rows = await _c
        .from('attendance')
        .select('student_id, status')
        .eq('session_id', sessionId);
    return {
      for (final r in rows as List)
        r['student_id'] as String:
            AttendanceStatus.fromDb(r['status'] as String?),
    };
  }

  /// Upsert a student's attendance for a session (leaves parent 'excused' alone).
  Future<void> setAttendance(
      String sessionId, String studentId, AttendanceStatus status) async {
    await _c.from('attendance').upsert({
      'session_id': sessionId,
      'student_id': studentId,
      'status': status.db,
    }, onConflict: 'session_id,student_id');
  }

  // ── Assessments & grades ──────────────────────────────────────────────────

  /// Terms of the class's academic year (assessments belong to a term).
  Future<List<Term>> termsForClass(String classId) async {
    final cls = await _c
        .from('classes')
        .select('school_year_id')
        .eq('id', classId)
        .single();
    final rows = await _c
        .from('terms')
        .select()
        .eq('school_year_id', cls['school_year_id'] as String)
        .order('idx');
    return (rows as List)
        .map((r) => Term.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Assessment>> assessments(String classSubjectId) async {
    final rows = await _c
        .from('assessments')
        .select()
        .eq('class_subject_id', classSubjectId)
        .order('date', ascending: false);
    return (rows as List)
        .map((r) => Assessment.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Assessment> createAssessment({
    required String classSubjectId,
    required String termId,
    required AssessmentType type,
    required String title,
    required DateTime date,
    required double maxGrade,
    required double coefficient,
  }) async {
    final row = await _c
        .from('assessments')
        .insert({
          'class_subject_id': classSubjectId,
          'term_id': termId,
          'type': type.db,
          'title': title,
          'date': dateToDb(date),
          'max_grade': maxGrade,
          'coefficient': coefficient,
          'created_by': _c.auth.currentUser?.id,
        })
        .select()
        .single();
    return Assessment.fromMap(row);
  }

  Future<void> deleteAssessment(String id) async {
    await _c.from('assessments').delete().eq('id', id);
  }

  /// Existing grades for an assessment: student id → value (nullable).
  Future<Map<String, double?>> gradesForAssessment(String assessmentId) async {
    final rows = await _c
        .from('grades')
        .select('student_id, value')
        .eq('assessment_id', assessmentId);
    return {
      for (final r in rows as List)
        r['student_id'] as String: (r['value'] as num?)?.toDouble(),
    };
  }

  /// Upsert one student's grade (null clears it).
  Future<void> setGrade(
      String assessmentId, String studentId, double? value) async {
    await _c.from('grades').upsert({
      'assessment_id': assessmentId,
      'student_id': studentId,
      'value': value,
    }, onConflict: 'assessment_id,student_id');
  }
}
