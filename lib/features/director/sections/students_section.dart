import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../data/school_repository.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';
import 'subjects_section.dart' show CatalogList;

/// Manage students within a chosen class. Each student carries up to two parent
/// phone numbers, which is how parents get linked to their child (by phone).
class StudentsSection extends StatefulWidget {
  const StudentsSection({super.key, required this.school});
  final School school;

  @override
  State<StudentsSection> createState() => _StudentsSectionState();
}

class _StudentsSectionState extends State<StudentsSection> {
  SchoolRepository get _schoolRepo => context.read<SchoolRepository>();
  AcademicRepository get _repo => context.read<AcademicRepository>();

  bool _loading = true;
  List<SchoolYear> _years = const [];
  String? _yearId;
  List<SchoolClass> _classes = const [];
  String? _classId;
  Future<List<Student>>? _studentsFuture;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final years = await _schoolRepo.years(widget.school.id);
    SchoolYear? active;
    for (final y in years) {
      if (y.isActive) active = y;
    }
    final yearId = years.isEmpty ? null : (active ?? years.first).id;
    final classes =
        yearId == null ? <SchoolClass>[] : await _repo.classes(yearId);
    if (!mounted) return;
    setState(() {
      _years = years;
      _yearId = yearId;
      _classes = classes;
      _classId = classes.isEmpty ? null : classes.first.id;
      _loading = false;
    });
    _reload();
  }

  Future<void> _onYearChanged(String yearId) async {
    final classes = await _repo.classes(yearId);
    if (!mounted) return;
    setState(() {
      _yearId = yearId;
      _classes = classes;
      _classId = classes.isEmpty ? null : classes.first.id;
    });
    _reload();
  }

  void _reload() {
    if (_classId == null) {
      setState(() => _studentsFuture = Future.value(const []));
      return;
    }
    setState(() {
      _studentsFuture = _repo.students(_classId!);
    });
  }

  Future<void> _add() async {
    if (_classId == null) return;
    final input = await showDialog<StudentInput>(
      context: context,
      builder: (_) => const StudentDialog(),
    );
    if (input == null) return;
    await _repo.addStudent(
      schoolId: widget.school.id,
      classId: _classId!,
      fullName: input.name,
      parentPhone1: input.phone1,
      parentPhone2: input.phone2,
    );
    _reload();
  }

  Future<void> _edit(Student st) async {
    final input = await showDialog<StudentInput>(
      context: context,
      builder: (_) => StudentDialog(
        initialName: st.fullName,
        initialPhone1: st.parentPhone1,
        initialPhone2: st.parentPhone2,
      ),
    );
    if (input == null) return;
    await _repo.updateStudent(
      id: st.id,
      fullName: input.name,
      parentPhone1: input.phone1,
      parentPhone2: input.phone2,
    );
    _reload();
  }

  Future<void> _delete(Student st) async {
    if (!await confirmDelete(context, st.fullName)) return;
    await _repo.deleteStudent(st.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_years.isEmpty) {
      return _centered(context, Icons.event_busy_outlined, s.needYearFirst);
    }
    if (_classes.isEmpty) {
      return _centered(context, Icons.groups_outlined, s.noClasses);
    }

    return CatalogList<Student>(
      future: _studentsFuture ?? Future.value(const []),
      emptyText: s.noStudents,
      addLabel: s.addStudent,
      onAdd: _add,
      titleOf: (st) => st.fullName,
      subtitleOf: (st) =>
          st.parentPhones.isEmpty ? null : st.parentPhones.map((p) => '+$p').join('  ·  '),
      onEdit: _edit,
      onDelete: _delete,
      leadingIcon: Icons.school_outlined,
      header: _selectors(context),
    );
  }

  Widget _selectors(BuildContext context) {
    final s = context.s;
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.academicYear}:',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _yearId,
              onChanged: (v) => v == null ? null : _onYearChanged(v),
              items: [
                for (final y in _years)
                  DropdownMenuItem(
                      value: y.id,
                      child: Text(y.isActive ? '${y.label} •' : y.label)),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.selectClass}:',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _classId,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _classId = v);
                _reload();
              },
              items: [
                for (final c in _classes)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _centered(BuildContext context, IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).hintColor),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
