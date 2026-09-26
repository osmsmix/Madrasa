/// Plain data models mirroring the Supabase tables (see supabase/migrations).
/// Manual fromMap/toMap — no codegen — to keep the build simple.
library;

import 'package:flutter/material.dart' show TimeOfDay;

enum TermType {
  trimester,
  semester;

  /// Number of terms in a school year.
  int get count => this == TermType.trimester ? 3 : 2;

  String get db => name; // 'trimester' | 'semester'

  static TermType fromDb(String? v) =>
      v == 'semester' ? TermType.semester : TermType.trimester;
}

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

String? _dateStr(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

class School {
  School({
    required this.id,
    required this.name,
    required this.termType,
    required this.gradeMax,
    this.isActive = false,
  });

  final String id;
  final String name;
  final TermType termType;
  final double gradeMax;

  /// Activated by the vendor. A deactivated school is unusable/hidden.
  final bool isActive;

  factory School.fromMap(Map<String, dynamic> m) => School(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        termType: TermType.fromDb(m['term_type'] as String?),
        gradeMax: (m['grade_max'] as num?)?.toDouble() ?? 20,
        isActive: (m['is_active'] as bool?) ?? false,
      );

  School copyWith({String? name, TermType? termType, double? gradeMax}) =>
      School(
        id: id,
        name: name ?? this.name,
        termType: termType ?? this.termType,
        gradeMax: gradeMax ?? this.gradeMax,
        isActive: isActive,
      );
}

class SchoolYear {
  SchoolYear({
    required this.id,
    required this.schoolId,
    required this.label,
    this.startsOn,
    this.endsOn,
    this.isActive = true,
  });

  final String id;
  final String schoolId;
  final String label;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final bool isActive;

  factory SchoolYear.fromMap(Map<String, dynamic> m) => SchoolYear(
        id: m['id'] as String,
        schoolId: m['school_id'] as String,
        label: (m['label'] ?? '') as String,
        startsOn: _date(m['starts_on']),
        endsOn: _date(m['ends_on']),
        isActive: (m['is_active'] as bool?) ?? true,
      );
}

class Term {
  Term({
    required this.id,
    required this.schoolYearId,
    required this.idx,
    required this.label,
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final String schoolYearId;
  final int idx;
  final String label;
  final DateTime? startsOn;
  final DateTime? endsOn;

  factory Term.fromMap(Map<String, dynamic> m) => Term(
        id: m['id'] as String,
        schoolYearId: m['school_year_id'] as String,
        idx: (m['idx'] as num).toInt(),
        label: (m['label'] ?? '') as String,
        startsOn: _date(m['starts_on']),
        endsOn: _date(m['ends_on']),
      );
}

/// A class (e.g. "1ère année A") within an academic year. The name carries the
/// grade level + section — this is where "first year / second year" is entered.
class SchoolClass {
  SchoolClass({
    required this.id,
    required this.schoolId,
    required this.schoolYearId,
    required this.name,
  });

  final String id;
  final String schoolId;
  final String schoolYearId;
  final String name;

  factory SchoolClass.fromMap(Map<String, dynamic> m) => SchoolClass(
        id: m['id'] as String,
        schoolId: m['school_id'] as String,
        schoolYearId: m['school_year_id'] as String,
        name: (m['name'] ?? '') as String,
      );
}

/// A subject (matière) in the school's catalog. Coefficient is NOT here — it is
/// per class, on the class↔subject link.
class Subject {
  Subject({required this.id, required this.schoolId, required this.name});

  final String id;
  final String schoolId;
  final String name;

  factory Subject.fromMap(Map<String, dynamic> m) => Subject(
        id: m['id'] as String,
        schoolId: m['school_id'] as String,
        name: (m['name'] ?? '') as String,
      );
}

/// A teacher = a `memberships` row with role 'teacher'. Created by the director
/// with a phone (+ name) before the teacher ever logs in; user_id is backfilled
/// on first sign-in by the handle_new_user trigger.
class Teacher {
  Teacher({
    required this.id,
    required this.schoolId,
    required this.phone,
    this.fullName,
    this.userId,
  });

  final String id; // membership id
  final String schoolId;
  final String phone;
  final String? fullName;
  final String? userId;

  /// True once the teacher has signed in at least once.
  bool get isActivated => userId != null;

  /// Best display name — the name if set, else the phone.
  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : phone;

  factory Teacher.fromMap(Map<String, dynamic> m) => Teacher(
        id: m['id'] as String,
        schoolId: m['school_id'] as String,
        phone: (m['phone'] ?? '') as String,
        fullName: m['full_name'] as String?,
        userId: m['user_id'] as String?,
      );
}

/// A subject assigned to a class: carries the per-class coefficient and the
/// assigned teacher. Includes joined display fields (subject/teacher names).
class ClassSubject {
  ClassSubject({
    required this.id,
    required this.subjectId,
    required this.coefficient,
    required this.subjectName,
    this.teacherMembershipId,
    this.teacherName,
  });

  final String id;
  final String subjectId;
  final double coefficient;
  final String subjectName;
  final String? teacherMembershipId;
  final String? teacherName;

  factory ClassSubject.fromMap(Map<String, dynamic> m) {
    final subject = m['subjects'] as Map<String, dynamic>?;
    final teacher = m['memberships'] as Map<String, dynamic>?;
    String? tName;
    if (teacher != null) {
      final fn = teacher['full_name'] as String?;
      tName = (fn != null && fn.trim().isNotEmpty)
          ? fn
          : teacher['phone'] as String?;
    }
    return ClassSubject(
      id: m['id'] as String,
      subjectId: m['subject_id'] as String,
      coefficient: (m['coefficient'] as num?)?.toDouble() ?? 1,
      subjectName: (subject?['name'] ?? '') as String,
      teacherMembershipId: m['teacher_membership_id'] as String?,
      teacherName: tName,
    );
  }
}

/// A student in a class. Carries up to two parent phone numbers — parents are
/// linked to their child purely by phone match (E.164 without '+'), so these
/// must be normalized before saving.
class Student {
  Student({
    required this.id,
    required this.schoolId,
    required this.fullName,
    this.classId,
    this.parentPhone1,
    this.parentPhone2,
  });

  final String id;
  final String schoolId;
  final String? classId;
  final String fullName;
  final String? parentPhone1;
  final String? parentPhone2;

  List<String> get parentPhones => [
        if (parentPhone1 != null && parentPhone1!.isNotEmpty) parentPhone1!,
        if (parentPhone2 != null && parentPhone2!.isNotEmpty) parentPhone2!,
      ];

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: m['id'] as String,
        schoolId: m['school_id'] as String,
        classId: m['class_id'] as String?,
        fullName: (m['full_name'] ?? '') as String,
        parentPhone1: m['parent_phone_1'] as String?,
        parentPhone2: m['parent_phone_2'] as String?,
      );
}

/// A recurring weekly timetable slot: a class_subject taught on a given weekday
/// and time range (+ optional room). Includes joined subject/teacher names.
class ScheduleSlot {
  ScheduleSlot({
    required this.id,
    required this.classSubjectId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    this.room,
    this.teacherName,
  });

  final String id;
  final String classSubjectId;
  final int weekday; // ISO: 1 = Monday … 7 = Sunday
  final String startTime; // 'HH:mm:ss'
  final String endTime;
  final String? room;
  final String subjectName;
  final String? teacherName;

  TimeOfDay get start => _parseTime(startTime);
  TimeOfDay get end => _parseTime(endTime);

  factory ScheduleSlot.fromMap(Map<String, dynamic> m) {
    final cs = m['class_subjects'] as Map<String, dynamic>?;
    final subject = cs?['subjects'] as Map<String, dynamic>?;
    final teacher = cs?['memberships'] as Map<String, dynamic>?;
    String? tName;
    if (teacher != null) {
      final fn = teacher['full_name'] as String?;
      tName = (fn != null && fn.trim().isNotEmpty)
          ? fn
          : teacher['phone'] as String?;
    }
    return ScheduleSlot(
      id: m['id'] as String,
      classSubjectId: m['class_subject_id'] as String,
      weekday: (m['weekday'] as num).toInt(),
      startTime: m['start_time'] as String,
      endTime: m['end_time'] as String,
      room: m['room'] as String?,
      subjectName: (subject?['name'] ?? '') as String,
      teacherName: tName,
    );
  }
}

TimeOfDay _parseTime(String hms) {
  final parts = hms.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
  );
}

/// Format a TimeOfDay as 'HH:mm:00' for a Postgres `time` column.
String timeToDb(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

/// Format a TimeOfDay as 'HH:mm' for display (24h, LTR).
String timeLabel(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

enum AttendanceStatus {
  present,
  absent,
  late;

  String get db => name;

  static AttendanceStatus fromDb(String? v) => switch (v) {
        'absent' => AttendanceStatus.absent,
        'late' => AttendanceStatus.late,
        _ => AttendanceStatus.present,
      };
}

/// A subject a teacher teaches in a class (their class_subject link).
class TeachingAssignment {
  TeachingAssignment({
    required this.classSubjectId,
    required this.classId,
    required this.className,
    required this.subjectName,
    required this.coefficient,
  });

  final String classSubjectId;
  final String classId;
  final String className;
  final String subjectName;
  final double coefficient;

  factory TeachingAssignment.fromMap(Map<String, dynamic> m) {
    final classes = m['classes'] as Map<String, dynamic>?;
    final subject = m['subjects'] as Map<String, dynamic>?;
    return TeachingAssignment(
      classSubjectId: m['id'] as String,
      classId: m['class_id'] as String,
      className: (classes?['name'] ?? '') as String,
      subjectName: (subject?['name'] ?? '') as String,
      coefficient: (m['coefficient'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// A concrete timetable slot as seen by the teacher (with class + subject names).
class TeacherSlot {
  TeacherSlot({
    required this.id,
    required this.classSubjectId,
    required this.classId,
    required this.className,
    required this.subjectName,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  final String id; // schedule_slot id
  final String classSubjectId;
  final String classId;
  final String className;
  final String subjectName;
  final int weekday;
  final String startTime;
  final String endTime;
  final String? room;

  TimeOfDay get start => _parseTime(startTime);
  TimeOfDay get end => _parseTime(endTime);
}

enum AssessmentType {
  exam,
  homework,
  test;

  String get db => name;

  static AssessmentType fromDb(String? v) => switch (v) {
        'homework' => AssessmentType.homework,
        'test' => AssessmentType.test,
        _ => AssessmentType.exam,
      };
}

/// A graded item (exam / homework / test) for a class_subject in a term.
class Assessment {
  Assessment({
    required this.id,
    required this.classSubjectId,
    required this.termId,
    required this.type,
    required this.title,
    required this.date,
    required this.maxGrade,
    required this.coefficient,
  });

  final String id;
  final String classSubjectId;
  final String termId;
  final AssessmentType type;
  final String title;
  final DateTime date;
  final double maxGrade;
  final double coefficient;

  factory Assessment.fromMap(Map<String, dynamic> m) => Assessment(
        id: m['id'] as String,
        classSubjectId: m['class_subject_id'] as String,
        termId: m['term_id'] as String,
        type: AssessmentType.fromDb(m['type'] as String?),
        title: (m['title'] ?? '') as String,
        date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
        maxGrade: (m['max_grade'] as num?)?.toDouble() ?? 20,
        coefficient: (m['coefficient'] as num?)?.toDouble() ?? 1,
      );
}

/// A single grade a parent sees for their child.
class ParentGradeEntry {
  ParentGradeEntry({
    required this.title,
    required this.type,
    required this.date,
    required this.maxGrade,
    required this.coefficient,
    this.value,
  });

  final String title;
  final AssessmentType type;
  final DateTime date;
  final double maxGrade;
  final double coefficient;
  final double? value;
}

/// A child's grades within one subject, plus a weighted average (out of 20).
class ParentSubjectGrades {
  ParentSubjectGrades({required this.subjectName, required this.entries});
  final String subjectName;
  final List<ParentGradeEntry> entries;

  /// Weighted average normalized to /20 (ignores ungraded entries).
  double? get average {
    double sumW = 0, sum = 0;
    for (final e in entries) {
      if (e.value == null || e.maxGrade <= 0) continue;
      final pct = (e.value! / e.maxGrade) * 20;
      sum += pct * e.coefficient;
      sumW += e.coefficient;
    }
    return sumW == 0 ? null : sum / sumW;
  }
}

/// A child's attendance record as a parent sees it.
class ParentAttendanceEntry {
  ParentAttendanceEntry({
    required this.id,
    required this.date,
    required this.subjectName,
    required this.status,
    required this.excused,
    this.reason,
  });

  final String id;
  final DateTime date;
  final String subjectName;
  final AttendanceStatus status;
  final bool excused;
  final String? reason;
}

enum AnnouncementAudience {
  teachers,
  parents,
  both;

  String get db => name;

  static AnnouncementAudience fromDb(String? v) => switch (v) {
        'teachers' => AnnouncementAudience.teachers,
        'parents' => AnnouncementAudience.parents,
        _ => AnnouncementAudience.both,
      };
}

/// A director announcement, targeted by audience (teachers/parents/both) and
/// optionally scoped to a single class (null = the whole audience).
class Announcement {
  Announcement({
    required this.id,
    required this.schoolId,
    required this.audience,
    required this.title,
    required this.createdAt,
    this.classId,
    this.className,
    this.body,
  });

  final String id;
  final String schoolId;
  final String? classId;
  final String? className;
  final AnnouncementAudience audience;
  final String title;
  final String? body;
  final DateTime createdAt;

  factory Announcement.fromMap(Map<String, dynamic> m) {
    final cls = m['classes'] as Map<String, dynamic>?;
    return Announcement(
      id: m['id'] as String,
      schoolId: m['school_id'] as String,
      classId: m['class_id'] as String?,
      className: cls?['name'] as String?,
      audience: AnnouncementAudience.fromDb(m['audience'] as String?),
      title: (m['title'] ?? '') as String,
      body: m['body'] as String?,
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Helper re-exported for repositories that need to serialize dates.
String? dateToDb(DateTime? d) => _dateStr(d);
