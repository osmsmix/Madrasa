import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';

/// Manage the school-wide catalog of subjects (matières). Coefficients are set
/// per class later, on the class↔subject link — not here.
class SubjectsSection extends StatefulWidget {
  const SubjectsSection({super.key, required this.school});
  final School school;

  @override
  State<SubjectsSection> createState() => _SubjectsSectionState();
}

class _SubjectsSectionState extends State<SubjectsSection> {
  AcademicRepository get _repo => context.read<AcademicRepository>();
  late Future<List<Subject>> _future = _repo.subjects(widget.school.id);

  void _reload() {
    setState(() {
      _future = _repo.subjects(widget.school.id);
    });
  }

  Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: context.s.addSubject,
        label: context.s.subjectName,
      ),
    );
    if (name == null || name.isEmpty) return;
    await _repo.createSubject(schoolId: widget.school.id, name: name);
    _reload();
  }

  Future<void> _rename(Subject subject) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: context.s.edit,
        label: context.s.subjectName,
        initial: subject.name,
      ),
    );
    if (name == null || name.isEmpty || name == subject.name) return;
    await _repo.renameSubject(subject.id, name);
    _reload();
  }

  Future<void> _delete(Subject subject) async {
    if (!await confirmDelete(context, subject.name)) return;
    await _repo.deleteSubject(subject.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return CatalogList<Subject>(
      future: _future,
      emptyText: s.noSubjects,
      addLabel: s.addSubject,
      onAdd: _add,
      titleOf: (subj) => subj.name,
      onEdit: _rename,
      onDelete: _delete,
      leadingIcon: Icons.menu_book_outlined,
    );
  }
}

/// Reusable "header + add button + list of name rows with edit/delete" used by
/// the Subjects and Classes sections.
class CatalogList<T> extends StatelessWidget {
  const CatalogList({
    super.key,
    required this.future,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    required this.titleOf,
    required this.onEdit,
    required this.onDelete,
    required this.leadingIcon,
    this.subtitleOf,
    this.onTap,
    this.header,
  });

  final Future<List<T>> future;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;
  final String Function(T) titleOf;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final IconData leadingIcon;

  /// Optional second line per row (e.g. a teacher's phone).
  final String? Function(T)? subtitleOf;

  /// Optional row tap (e.g. open a class's detail). Adds a chevron.
  final ValueChanged<T>? onTap;

  /// Optional widget shown above the list (e.g. the academic-year selector).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
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
                    if (header != null) ...[header!, const SizedBox(height: 12)],
                    Row(
                      children: [
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add),
                          label: Text(addLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<T>>(
                      future: future,
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
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(emptyText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium)),
                          );
                        }
                        return Column(
                          children: [
                            for (final item in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(leadingIcon),
                                title: Text(titleOf(item)),
                                subtitle: subtitleOf?.call(item) != null
                                    ? Text(subtitleOf!(item)!)
                                    : null,
                                onTap:
                                    onTap != null ? () => onTap!(item) : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: s.edit,
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => onEdit(item),
                                    ),
                                    IconButton(
                                      tooltip: s.delete,
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => onDelete(item),
                                    ),
                                    if (onTap != null)
                                      const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
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
    );
  }
}
