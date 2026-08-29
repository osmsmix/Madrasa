import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../data/school_repository.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';
import 'class_detail_screen.dart';
import 'subjects_section.dart' show CatalogList;

/// Manage classes (e.g. "1ère année A") within a chosen academic year. The class
/// name is where the grade level + section is entered.
class ClassesSection extends StatefulWidget {
  const ClassesSection({super.key, required this.school});
  final School school;

  @override
  State<ClassesSection> createState() => _ClassesSectionState();
}

class _ClassesSectionState extends State<ClassesSection> {
  SchoolRepository get _schoolRepo => context.read<SchoolRepository>();
  AcademicRepository get _repo => context.read<AcademicRepository>();

  bool _loadingYears = true;
  List<SchoolYear> _years = const [];
  String? _yearId;
  Future<List<SchoolClass>>? _classesFuture;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    setState(() => _loadingYears = true);
    final years = await _schoolRepo.years(widget.school.id);
    if (!mounted) return;
    SchoolYear? active;
    for (final y in years) {
      if (y.isActive) active = y;
    }
    setState(() {
      _years = years;
      _yearId = years.isEmpty ? null : (active ?? years.first).id;
      _loadingYears = false;
    });
    _reloadClasses();
  }

  void _reloadClasses() {
    if (_yearId == null) return;
    setState(() {
      _classesFuture = _repo.classes(_yearId!);
    });
  }

  Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: context.s.addClass,
        label: context.s.className,
        hint: context.s.classNameHint,
      ),
    );
    if (name == null || name.isEmpty || _yearId == null) return;
    await _repo.createClass(
      schoolId: widget.school.id,
      schoolYearId: _yearId!,
      name: name,
    );
    _reloadClasses();
  }

  Future<void> _rename(SchoolClass c) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: context.s.edit,
        label: context.s.className,
        hint: context.s.classNameHint,
        initial: c.name,
      ),
    );
    if (name == null || name.isEmpty || name == c.name) return;
    await _repo.renameClass(c.id, name);
    _reloadClasses();
  }

  Future<void> _delete(SchoolClass c) async {
    if (!await confirmDelete(context, c.name)) return;
    await _repo.deleteClass(c.id);
    _reloadClasses();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (_loadingYears) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_years.isEmpty || _yearId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined,
                  size: 48, color: Theme.of(context).hintColor),
              const SizedBox(height: 12),
              Text(s.needYearFirst, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return CatalogList<SchoolClass>(
      future: _classesFuture ?? _repo.classes(_yearId!),
      emptyText: s.noClasses,
      addLabel: s.addClass,
      onAdd: _add,
      titleOf: (c) => c.name,
      onEdit: _rename,
      onDelete: _delete,
      onTap: (c) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClassDetailScreen(school: widget.school, schoolClass: c),
        ),
      ),
      leadingIcon: Icons.groups_outlined,
      header: _yearSelector(context),
    );
  }

  Widget _yearSelector(BuildContext context) {
    final s = context.s;
    return Row(
      children: [
        Text('${s.academicYear}:',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _yearId,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _yearId = v);
            _reloadClasses();
          },
          items: [
            for (final y in _years)
              DropdownMenuItem(
                value: y.id,
                child: Text(y.isActive ? '${y.label}  •' : y.label),
              ),
          ],
        ),
      ],
    );
  }
}
