import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Data access for classes and subjects. Runs under RLS as the signed-in user
/// (only a director of the school can write; see supabase/migrations/0002_rls).
class AcademicRepository {
  AcademicRepository(this._c);
  final SupabaseClient _c;

  // ── Classes (scoped to an academic year) ──────────────────────────────────

  Future<List<SchoolClass>> classes(String schoolYearId) async {
    final rows = await _c
        .from('classes')
        .select()
        .eq('school_year_id', schoolYearId)
        .order('name');
    return (rows as List)
        .map((r) => SchoolClass.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<SchoolClass> createClass({
    required String schoolId,
    required String schoolYearId,
    required String name,
  }) async {
    final row = await _c
        .from('classes')
        .insert({
          'school_id': schoolId,
          'school_year_id': schoolYearId,
          'name': name,
        })
        .select()
        .single();
    return SchoolClass.fromMap(row);
  }

  Future<void> renameClass(String id, String name) async {
    await _c.from('classes').update({'name': name}).eq('id', id);
  }

  Future<void> deleteClass(String id) async {
    await _c.from('classes').delete().eq('id', id);
  }

  // ── Subjects (school-wide catalog) ────────────────────────────────────────

  Future<List<Subject>> subjects(String schoolId) async {
    final rows = await _c
        .from('subjects')
        .select()
        .eq('school_id', schoolId)
        .order('name');
    return (rows as List)
        .map((r) => Subject.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Subject> createSubject({
    required String schoolId,
    required String name,
  }) async {
    final row = await _c
        .from('subjects')
        .insert({'school_id': schoolId, 'name': name})
        .select()
        .single();
    return Subject.fromMap(row);
  }

  Future<void> renameSubject(String id, String name) async {
    await _c.from('subjects').update({'name': name}).eq('id', id);
  }

  Future<void> deleteSubject(String id) async {
    await _c.from('subjects').delete().eq('id', id);
  }

  // ── Teachers (memberships, role = 'teacher') ──────────────────────────────

  Future<List<Teacher>> teachers(String schoolId) async {
    final rows = await _c
        .from('memberships')
        .select('id, school_id, phone, user_id, full_name')
        .eq('school_id', schoolId)
        .eq('role', 'teacher')
        .order('full_name');
    return (rows as List)
        .map((r) => Teacher.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Teacher> addTeacher({
    required String schoolId,
    required String phone,
    String? fullName,
  }) async {
    final row = await _c
        .from('memberships')
        .insert({
          'school_id': schoolId,
          'role': 'teacher',
          'phone': phone,
          'full_name': fullName,
        })
        .select('id, school_id, phone, user_id, full_name')
        .single();
    return Teacher.fromMap(row);
  }

  Future<void> updateTeacher({
    required String id,
    required String phone,
    String? fullName,
  }) async {
    await _c
        .from('memberships')
        .update({'phone': phone, 'full_name': fullName}).eq('id', id);
  }

  Future<void> deleteTeacher(String id) async {
    // class_subjects.teacher_membership_id is ON DELETE SET NULL, so any classes
    // this teacher was assigned to simply become unassigned.
    await _c.from('memberships').delete().eq('id', id);
  }

  // ── Class ↔ subject assignment (coefficient + teacher) ────────────────────

  Future<List<ClassSubject>> classSubjects(String classId) async {
    final rows = await _c
        .from('class_subjects')
        .select(
            'id, subject_id, teacher_membership_id, coefficient, subjects(name), memberships(full_name, phone)')
        .eq('class_id', classId);
    final list = (rows as List)
        .map((r) => ClassSubject.fromMap(r as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return list;
  }

  Future<void> assignSubject({
    required String classId,
    required String subjectId,
    required double coefficient,
    String? teacherMembershipId,
  }) async {
    await _c.from('class_subjects').insert({
      'class_id': classId,
      'subject_id': subjectId,
      'coefficient': coefficient,
      'teacher_membership_id': teacherMembershipId,
    });
  }

  Future<void> updateClassSubject({
    required String id,
    required double coefficient,
    String? teacherMembershipId,
  }) async {
    await _c.from('class_subjects').update({
      'coefficient': coefficient,
      'teacher_membership_id': teacherMembershipId,
    }).eq('id', id);
  }

  Future<void> removeClassSubject(String id) async {
    await _c.from('class_subjects').delete().eq('id', id);
  }

  // ── Timetable (schedule_slots) ────────────────────────────────────────────

  /// All weekly slots for a class, joined with subject + teacher names.
  Future<List<ScheduleSlot>> slotsForClass(String classId) async {
    final rows = await _c
        .from('schedule_slots')
        .select(
            'id, class_subject_id, weekday, start_time, end_time, room, '
            'class_subjects!inner(class_id, subjects(name), memberships(full_name, phone))')
        .eq('class_subjects.class_id', classId)
        .order('weekday')
        .order('start_time');
    return (rows as List)
        .map((r) => ScheduleSlot.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSlot({
    required String classSubjectId,
    required int weekday,
    required String startTime, // 'HH:mm:00'
    required String endTime,
    String? room,
  }) async {
    await _c.from('schedule_slots').insert({
      'class_subject_id': classSubjectId,
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
    });
  }

  Future<void> updateSlot({
    required String id,
    required String classSubjectId,
    required int weekday,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    await _c.from('schedule_slots').update({
      'class_subject_id': classSubjectId,
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
    }).eq('id', id);
  }

  Future<void> deleteSlot(String id) async {
    await _c.from('schedule_slots').delete().eq('id', id);
  }

  // ── Students ──────────────────────────────────────────────────────────────

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

  Future<Student> addStudent({
    required String schoolId,
    required String classId,
    required String fullName,
    String? parentPhone1,
    String? parentPhone2,
  }) async {
    final row = await _c
        .from('students')
        .insert({
          'school_id': schoolId,
          'class_id': classId,
          'full_name': fullName,
          'parent_phone_1': parentPhone1,
          'parent_phone_2': parentPhone2,
        })
        .select()
        .single();
    return Student.fromMap(row);
  }

  Future<void> updateStudent({
    required String id,
    required String fullName,
    String? parentPhone1,
    String? parentPhone2,
  }) async {
    await _c.from('students').update({
      'full_name': fullName,
      'parent_phone_1': parentPhone1,
      'parent_phone_2': parentPhone2,
    }).eq('id', id);
  }

  Future<void> deleteStudent(String id) async {
    await _c.from('students').delete().eq('id', id);
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  Future<List<Announcement>> announcements(String schoolId) async {
    final rows = await _c
        .from('announcements')
        .select('id, school_id, class_id, audience, title, body, created_at, classes(name)')
        .eq('school_id', schoolId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Announcement.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAnnouncement({
    required String schoolId,
    String? classId,
    required AnnouncementAudience audience,
    required String title,
    String? body,
  }) async {
    await _c.from('announcements').insert({
      'school_id': schoolId,
      'class_id': classId,
      'audience': audience.db,
      'title': title,
      'body': body,
      'created_by': _c.auth.currentUser?.id,
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    String? classId,
    required AnnouncementAudience audience,
    required String title,
    String? body,
  }) async {
    await _c.from('announcements').update({
      'class_id': classId,
      'audience': audience.db,
      'title': title,
      'body': body,
    }).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _c.from('announcements').delete().eq('id', id);
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────

  Future<DashboardStats> stats(String schoolId, {String? activeYearId}) async {
    final classesRows = activeYearId == null
        ? const []
        : await _c
            .from('classes')
            .select('id')
            .eq('school_year_id', activeYearId);
    final studentsRows =
        await _c.from('students').select('id').eq('school_id', schoolId);
    final teachersRows = await _c
        .from('memberships')
        .select('id')
        .eq('school_id', schoolId)
        .eq('role', 'teacher');
    final subjectsRows =
        await _c.from('subjects').select('id').eq('school_id', schoolId);
    final annRows =
        await _c.from('announcements').select('id').eq('school_id', schoolId);
    return DashboardStats(
      classes: classesRows.length,
      students: (studentsRows as List).length,
      teachers: (teachersRows as List).length,
      subjects: (subjectsRows as List).length,
      announcements: (annRows as List).length,
    );
  }
}

class DashboardStats {
  DashboardStats({
    required this.classes,
    required this.students,
    required this.teachers,
    required this.subjects,
    required this.announcements,
  });
  final int classes;
  final int students;
  final int teachers;
  final int subjects;
  final int announcements;
}
