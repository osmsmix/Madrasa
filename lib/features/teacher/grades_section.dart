import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/teacher_repository.dart';
import '../../l10n/strings.dart';
import 'assessment_grades_screen.dart';

String _fmtNum(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : '$v';

/// Grades tab: the teacher picks one of their class-subjects, sees its
/// assessments, creates new ones, and opens one to enter grades.
class GradesSection extends StatefulWidget {
  const GradesSection({super.key, required this.schoolId});
  final String schoolId;
  @override
  State<GradesSection> createState() => _GradesSectionState();
}

class _GradesSectionState extends State<GradesSection> {
  TeacherRepository get _repo => context.read<TeacherRepository>();

  bool _loading = true;
  List<TeachingAssignment> _assignments = const [];
  String? _csId;
  Future<List<Assessment>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final assignments = await _repo.myAssignments(schoolId: widget.schoolId);
    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _csId = assignments.isEmpty ? null : assignments.first.classSubjectId;
      _loading = false;
    });
    _reload();
  }

  void _reload() {
    if (_csId == null) return;
    setState(() {
      _future = _repo.assessments(_csId!);
    });
  }

  TeachingAssignment? get _current =>
      _assignments.where((a) => a.classSubjectId == _csId).firstOrNull;

  Future<void> _new() async {
    final a = _current;
    if (a == null) return;
    final terms = await _repo.termsForClass(a.classId);
    if (!mounted) return;
    if (terms.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s.needYearFirst)));
      return;
    }
    final r = await showDialog<_AssessmentResult>(
      context: context,
      builder: (_) => _AssessmentDialog(terms: terms),
    );
    if (r == null) return;
    await _repo.createAssessment(
      classSubjectId: a.classSubjectId,
      termId: r.termId,
      type: r.type,
      title: r.title,
      date: r.date,
      maxGrade: r.maxGrade,
      coefficient: r.coefficient,
    );
    _reload();
  }

  Future<void> _delete(Assessment a) async {
    await _repo.deleteAssessment(a.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.noSessions, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _csId,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: s.selectAssignment),
                        items: [
                          for (final a in _assignments)
                            DropdownMenuItem(
                              value: a.classSubjectId,
                              child: Text('${a.className} — ${a.subjectName}'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _csId = v);
                          _reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _new,
                      icon: const Icon(Icons.add),
                      label: Text(s.newAssessment),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Assessment>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: Text(s.noAssessments,
                                style: Theme.of(context).textTheme.bodyMedium)),
                      );
                    }
                    return Column(
                      children: [
                        for (final a in items) _card(context, a),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Assessment a) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    final maxStr = a.maxGrade % 1 == 0
        ? a.maxGrade.toStringAsFixed(0)
        : '${a.maxGrade}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(child: Icon(_typeIcon(a.type))),
        title: Text(a.title),
        subtitle: Text(
          '${s.assessmentTypeName(a.type)} · ${DateFormat.yMMMd(lang).format(a.date)} · '
          '${s.outOf} $maxStr · ${s.coefficientLabel} ${_fmtNum(a.coefficient)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(a),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          final assignment = _current;
          if (assignment == null) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                AssessmentGradesScreen(assignment: assignment, assessment: a),
          ));
        },
      ),
    );
  }

  IconData _typeIcon(AssessmentType t) => switch (t) {
        AssessmentType.exam => Icons.assignment_outlined,
        AssessmentType.homework => Icons.home_work_outlined,
        AssessmentType.test => Icons.quiz_outlined,
      };
}

class _AssessmentResult {
  _AssessmentResult({
    required this.type,
    required this.title,
    required this.date,
    required this.termId,
    required this.maxGrade,
    required this.coefficient,
  });
  final AssessmentType type;
  final String title;
  final DateTime date;
  final String termId;
  final double maxGrade;
  final double coefficient;
}

class _AssessmentDialog extends StatefulWidget {
  const _AssessmentDialog({required this.terms});
  final List<Term> terms;
  @override
  State<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends State<_AssessmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '20');
  final _coeffCtrl = TextEditingController(text: '1');
  AssessmentType _type = AssessmentType.exam;
  DateTime _date = DateTime.now();
  late String _termId = _defaultTerm();

  /// Trimester (3 terms) vs semester (2) — inferred from the term count so the
  /// term names below stay translated regardless of the stored label.
  TermType get _termType =>
      widget.terms.length >= 3 ? TermType.trimester : TermType.semester;

  String _defaultTerm() {
    final now = DateTime.now();
    for (final t in widget.terms) {
      final start = t.startsOn, end = t.endsOn;
      if (start != null &&
          end != null &&
          !now.isBefore(start) &&
          !now.isAfter(end)) {
        return t.id;
      }
    }
    return widget.terms.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _maxCtrl.dispose();
    _coeffCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final max = double.tryParse(_maxCtrl.text.replaceAll(',', '.'));
    if (max == null || max <= 0) return;
    final coeff = double.tryParse(_coeffCtrl.text.replaceAll(',', '.'));
    if (coeff == null || coeff <= 0) return;
    Navigator.of(context).pop(_AssessmentResult(
      type: _type,
      title: _titleCtrl.text.trim(),
      date: _date,
      termId: _termId,
      maxGrade: max,
      coefficient: coeff,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    return AlertDialog(
      title: Text(s.newAssessment),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<AssessmentType>(
                segments: [
                  ButtonSegment(
                      value: AssessmentType.exam, label: Text(s.typeExam)),
                  ButtonSegment(
                      value: AssessmentType.homework,
                      label: Text(s.typeHomework)),
                  ButtonSegment(
                      value: AssessmentType.test, label: Text(s.typeTest)),
                ],
                selected: {_type},
                onSelectionChanged: (set) => setState(() => _type = set.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: s.announcementTitle),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: s.dateLabel),
                  child: Text(DateFormat.yMMMd(lang).format(_date),
                      textDirection: TextDirection.ltr),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(labelText: s.gradeMaxLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _coeffCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration:
                          InputDecoration(labelText: s.coefficientLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _termId,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.term),
                items: [
                  for (final t in widget.terms)
                    DropdownMenuItem(
                        value: t.id,
                        child: Text(s.termName(_termType, t.idx))),
                ],
                onChanged: (v) => setState(() => _termId = v ?? _termId),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.create)),
      ],
    );
  }
}
