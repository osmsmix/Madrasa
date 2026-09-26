import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';

/// Detail screen for one class: assign subjects to it, each with a per-class
/// coefficient and (optionally) a teacher. This builds the `class_subjects`
/// links the timetable and grading depend on.
class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.school,
    required this.schoolClass,
  });

  final School school;
  final SchoolClass schoolClass;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  AcademicRepository get _repo => context.read<AcademicRepository>();

  bool _loadingMeta = true;
  List<Subject> _catalog = const [];
  List<Teacher> _teachers = const [];
  late Future<List<ClassSubject>> _assigned =
      _repo.classSubjects(widget.schoolClass.id);

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final catalog = await _repo.subjects(widget.school.id);
    final teachers = await _repo.teachers(widget.school.id);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _teachers = teachers;
      _loadingMeta = false;
    });
  }

  void _reload() {
    setState(() {
      _assigned = _repo.classSubjects(widget.schoolClass.id);
    });
  }

  Future<void> _assign() async {
    final s = context.s;
    if (_catalog.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.needSubjectsFirst)));
      return;
    }
    final assigned = await _repo.classSubjects(widget.schoolClass.id);
    final takenIds = assigned.map((cs) => cs.subjectId).toSet();
    final available =
        _catalog.where((subj) => !takenIds.contains(subj.id)).toList();
    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.allSubjectsAssigned)));
      return;
    }
    final result = await showDialog<_AssignResult>(
      context: context,
      builder: (_) =>
          _AssignDialog(availableSubjects: available, teachers: _teachers),
    );
    if (result == null) return;
    await _repo.assignSubject(
      classId: widget.schoolClass.id,
      subjectId: result.subjectId!,
      coefficient: result.coefficient,
      teacherMembershipId: result.teacherMembershipId,
    );
    _reload();
  }

  Future<void> _edit(ClassSubject cs) async {
    final result = await showDialog<_AssignResult>(
      context: context,
      builder: (_) => _AssignDialog(
        availableSubjects: const [],
        teachers: _teachers,
        editing: cs,
      ),
    );
    if (result == null) return;
    await _repo.updateClassSubject(
      id: cs.id,
      coefficient: result.coefficient,
      teacherMembershipId: result.teacherMembershipId,
    );
    _reload();
  }

  Future<void> _remove(ClassSubject cs) async {
    if (!await confirmDelete(context, cs.subjectName)) return;
    await _repo.removeClassSubject(cs.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(widget.schoolClass.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadingMeta ? null : _assign,
        icon: const Icon(Icons.add),
        label: Text(s.assignSubject),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.classSubjectsTitle,
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            FutureBuilder<List<ClassSubject>>(
                              future: _assigned,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                final items = snap.data ?? const [];
                                if (items.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 24),
                                    child: Center(
                                        child: Text(s.noAssignedSubjects,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium)),
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final cs in items) _row(context, cs),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, ClassSubject cs) {
    final s = context.s;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(
          gradeMaxLabelValue(cs.coefficient),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(cs.subjectName),
      subtitle: Text(cs.teacherName ?? s.unassignedTeacher),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: s.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(cs),
          ),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _remove(cs),
          ),
        ],
      ),
    );
  }
}

class _AssignResult {
  _AssignResult({this.subjectId, required this.coefficient, this.teacherMembershipId});
  final String? subjectId; // null when editing (subject fixed)
  final double coefficient;
  final String? teacherMembershipId;
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({
    required this.availableSubjects,
    required this.teachers,
    this.editing,
  });

  final List<Subject> availableSubjects;
  final List<Teacher> teachers;
  final ClassSubject? editing;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  String? _subjectId;
  String? _teacherId;
  late final _coeffCtrl = TextEditingController(
      text: gradeMaxLabelValue(widget.editing?.coefficient ?? 1));

  @override
  void initState() {
    super.initState();
    _subjectId = widget.editing?.subjectId;
    _teacherId = widget.editing?.teacherMembershipId;
  }

  @override
  void dispose() {
    _coeffCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.editing != null;

  void _submit() {
    final coeff = double.tryParse(_coeffCtrl.text.replaceAll(',', '.'));
    if (coeff == null || coeff <= 0) return;
    if (!_isEdit && _subjectId == null) return;
    Navigator.of(context).pop(_AssignResult(
      subjectId: _isEdit ? null : _subjectId,
      coefficient: coeff,
      teacherMembershipId: _teacherId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(_isEdit ? widget.editing!.subjectName : s.assignSubject),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEdit)
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.selectSubject),
                items: [
                  for (final subj in widget.availableSubjects)
                    DropdownMenuItem(value: subj.id, child: Text(subj.name)),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _coeffCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(labelText: s.coefficientLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _teacherId,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.teacherLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(s.unassignedTeacher)),
                for (final t in widget.teachers)
                  DropdownMenuItem(value: t.id, child: Text(t.displayName)),
              ],
              onChanged: (v) => setState(() => _teacherId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
