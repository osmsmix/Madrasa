import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/teacher_repository.dart';
import '../../l10n/strings.dart';

/// Enter grades for one assessment: a numeric field per student (out of the
/// assessment's max), saved together via the Save button.
class AssessmentGradesScreen extends StatefulWidget {
  const AssessmentGradesScreen({
    super.key,
    required this.assignment,
    required this.assessment,
  });
  final TeachingAssignment assignment;
  final Assessment assessment;

  @override
  State<AssessmentGradesScreen> createState() => _AssessmentGradesScreenState();
}

class _AssessmentGradesScreenState extends State<AssessmentGradesScreen> {
  TeacherRepository get _repo => context.read<TeacherRepository>();

  bool _loading = true;
  Object? _error;
  bool _saving = false;
  List<Student> _students = const [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : '$v';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await _repo.students(widget.assignment.classId);
      final grades = await _repo.gradesForAssessment(widget.assessment.id);
      if (!mounted) return;
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      for (final st in students) {
        final v = grades[st.id];
        _controllers[st.id] =
            TextEditingController(text: v == null ? '' : _fmt(v));
      }
      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final max = widget.assessment.maxGrade;
    // Validate first.
    for (final st in _students) {
      final text = _controllers[st.id]!.text.trim().replaceAll(',', '.');
      if (text.isEmpty) continue;
      final v = double.tryParse(text);
      if (v == null || v < 0 || v > max) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.s.gradeOutOfRange)));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      for (final st in _students) {
        final text = _controllers[st.id]!.text.trim().replaceAll(',', '.');
        final v = text.isEmpty ? null : double.tryParse(text);
        await _repo.setGrade(widget.assessment.id, st.id, v);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.s.gradesSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final maxStr = _fmt(widget.assessment.maxGrade);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${widget.assignment.className} · ${widget.assignment.subjectName} · ${s.outOf} $maxStr',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (_loading || _error != null || _students.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(s.saveGrades),
            ),
      body: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = context.s;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(s.retry)),
          ],
        ),
      );
    }
    if (_students.isEmpty) {
      return Center(child: Text(s.noStudentsInClass));
    }
    final maxStr = _fmt(widget.assessment.maxGrade);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final st = _students[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(st.fullName)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _controllers[st.id],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: '/ $maxStr',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
