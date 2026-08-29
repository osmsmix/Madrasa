import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';
import 'subjects_section.dart' show CatalogList;

/// Manage the school's teachers. Each teacher is added by phone (+ name) and
/// activates automatically when they first sign in.
class TeachersSection extends StatefulWidget {
  const TeachersSection({super.key, required this.school});
  final School school;

  @override
  State<TeachersSection> createState() => _TeachersSectionState();
}

class _TeachersSectionState extends State<TeachersSection> {
  AcademicRepository get _repo => context.read<AcademicRepository>();
  late Future<List<Teacher>> _future = _repo.teachers(widget.school.id);

  void _reload() {
    setState(() {
      _future = _repo.teachers(widget.school.id);
    });
  }

  Future<void> _add() async {
    final input = await showDialog<TeacherInput>(
      context: context,
      builder: (_) => const TeacherDialog(),
    );
    if (input == null) return;
    await _repo.addTeacher(
      schoolId: widget.school.id,
      phone: input.phone,
      fullName: input.name,
    );
    _reload();
  }

  Future<void> _edit(Teacher t) async {
    final input = await showDialog<TeacherInput>(
      context: context,
      builder: (_) =>
          TeacherDialog(initialName: t.fullName, initialPhone: t.phone),
    );
    if (input == null) return;
    await _repo.updateTeacher(
      id: t.id,
      phone: input.phone,
      fullName: input.name,
    );
    _reload();
  }

  Future<void> _delete(Teacher t) async {
    if (!await confirmDelete(context, t.displayName)) return;
    await _repo.deleteTeacher(t.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return CatalogList<Teacher>(
      future: _future,
      emptyText: s.noTeachers,
      addLabel: s.addTeacher,
      onAdd: _add,
      titleOf: (t) => t.displayName,
      subtitleOf: (t) =>
          '+${t.phone}${t.isActivated ? '' : '  ·  ${s.pendingTeacher}'}',
      onEdit: _edit,
      onDelete: _delete,
      leadingIcon: Icons.co_present_outlined,
    );
  }
}
