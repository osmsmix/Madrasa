import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// One subject line on a report card.
class BulletinLine {
  BulletinLine({
    required this.subjectName,
    required this.coefficient,
    required this.average,
    required this.count,
    required this.types,
  });

  final String subjectName;
  final double coefficient; // the subject's per-class coefficient
  final double average; // out of the school's grade scale (e.g. /20)
  final int count; // number of graded assessments
  final List<AssessmentType> types; // distinct exam types the student took
}

/// A computed report card for one student in one term.
class BulletinData {
  BulletinData({required this.lines, required this.overall});
  final List<BulletinLine> lines;
  final double? overall; // weighted overall average, out of the grade scale
}

/// Computes report-card data. Averages normalize each grade to a fraction
/// (value / max), weight it by the assessment coefficient within a subject, then
/// weight subjects by their per-class coefficient for the overall average.
class BulletinRepository {
  BulletinRepository(this._c);
  final SupabaseClient _c;

  /// The terms of the student's academic year (to pick which term's bulletin).
  Future<List<Term>> termsForStudent(Student student) async {
    if (student.classId == null) return const [];
    final cls = await _c
        .from('classes')
        .select('school_year_id')
        .eq('id', student.classId!)
        .maybeSingle();
    if (cls == null) return const [];
    final rows = await _c
        .from('terms')
        .select()
        .eq('school_year_id', cls['school_year_id'] as String)
        .order('idx');
    return (rows as List)
        .map((r) => Term.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// The name of a class (for the report-card header).
  Future<String> className(String? classId) async {
    if (classId == null) return '';
    final row = await _c
        .from('classes')
        .select('name')
        .eq('id', classId)
        .maybeSingle();
    return (row?['name'] ?? '') as String;
  }

  /// Rank in class for a term (or the whole year when [termId] is null).
  /// Returns null when the student has no grades in that period.
  Future<({int rank, int total})?> rank({
    required String studentId,
    String? termId,
  }) async {
    try {
      final res = await _c.rpc('bulletin_rank',
          params: {'p_student': studentId, 'p_term': termId});
      final list = res as List;
      if (list.isEmpty) return null;
      final m = list.first as Map<String, dynamic>;
      return (
        rank: (m['the_rank'] as num).toInt(),
        total: (m['the_total'] as num).toInt(),
      );
    } catch (_) {
      // e.g. migration not applied yet — show the bulletin without a rank.
      return null;
    }
  }

  /// Report-card data for a term, or for the whole year when [termId] is null.
  Future<BulletinData> compute({
    required String studentId,
    String? termId,
    required double gradeMax,
  }) async {
    var query = _c
        .from('grades')
        .select(
            'value, assessments!inner(term_id, type, max_grade, coefficient, class_subject_id, class_subjects(coefficient, subjects(name)))')
        .eq('student_id', studentId)
        .not('value', 'is', null);
    if (termId != null) query = query.eq('assessments.term_id', termId);
    final rows = await query;

    // Group grades by class_subject.
    final groups = <String, _SubjectAgg>{};
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final a = m['assessments'] as Map<String, dynamic>?;
      if (a == null) continue;
      final csId = a['class_subject_id'] as String;
      final cs = a['class_subjects'] as Map<String, dynamic>?;
      final subjectName = (cs?['subjects']?['name'] ?? '') as String;
      final subjectCoef = (cs?['coefficient'] as num?)?.toDouble() ?? 1;
      final max = (a['max_grade'] as num?)?.toDouble() ?? gradeMax;
      final aCoef = (a['coefficient'] as num?)?.toDouble() ?? 1;
      final value = (m['value'] as num).toDouble();
      final type = AssessmentType.fromDb(a['type'] as String?);
      if (max <= 0) continue;

      final g = groups.putIfAbsent(
          csId, () => _SubjectAgg(subjectName, subjectCoef));
      g.weightedFraction += (value / max) * aCoef;
      g.weightSum += aCoef;
      g.count += 1;
      g.types.add(type);
    }

    final lines = <BulletinLine>[];
    double overallWeighted = 0, overallWeight = 0;
    for (final g in groups.values) {
      if (g.weightSum == 0) continue;
      final fraction = g.weightedFraction / g.weightSum; // 0..1
      lines.add(BulletinLine(
        subjectName: g.subjectName,
        coefficient: g.subjectCoef,
        average: fraction * gradeMax,
        count: g.count,
        types: _orderedTypes(g.types),
      ));
      overallWeighted += fraction * g.subjectCoef;
      overallWeight += g.subjectCoef;
    }
    lines.sort((a, b) => a.subjectName.compareTo(b.subjectName));

    return BulletinData(
      lines: lines,
      overall: overallWeight == 0 ? null : (overallWeighted / overallWeight) * gradeMax,
    );
  }
}

/// Distinct types in a stable order (exam, test, homework).
List<AssessmentType> _orderedTypes(Set<AssessmentType> types) => [
      for (final t in [
        AssessmentType.exam,
        AssessmentType.test,
        AssessmentType.homework,
      ])
        if (types.contains(t)) t,
    ];

class _SubjectAgg {
  _SubjectAgg(this.subjectName, this.subjectCoef);
  final String subjectName;
  final double subjectCoef;
  double weightedFraction = 0;
  double weightSum = 0;
  int count = 0;
  final Set<AssessmentType> types = {};
}
