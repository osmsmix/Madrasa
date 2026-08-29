import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../config/theme.dart';
import '../../../data/models.dart';
import '../../../data/school_repository.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';

/// School settings: edit the school's core fields, and manage school years +
/// their terms. Constrained to a comfortable reading width on wide screens.
class SchoolSettingsSection extends StatefulWidget {
  const SchoolSettingsSection({
    super.key,
    required this.school,
    required this.onSchoolUpdated,
    required this.onSchoolDeleted,
  });

  final School school;
  final ValueChanged<School> onSchoolUpdated;
  final VoidCallback onSchoolDeleted;

  @override
  State<SchoolSettingsSection> createState() => _SchoolSettingsSectionState();
}

class _SchoolSettingsSectionState extends State<SchoolSettingsSection> {
  SchoolRepository get _repo => context.read<SchoolRepository>();

  late School _school = widget.school;
  late Future<List<SchoolYear>> _years = _repo.years(widget.school.id);

  void _reloadYears() {
    setState(() {
      _years = _repo.years(_school.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SchoolDetailsCard(
                  school: _school,
                  onSaved: (s) {
                    setState(() => _school = s);
                    widget.onSchoolUpdated(s);
                  },
                ),
                const SizedBox(height: 16),
                _YearsCard(
                  school: _school,
                  yearsFuture: _years,
                  onChanged: _reloadYears,
                ),
                const SizedBox(height: 16),
                _DangerZoneCard(
                  school: _school,
                  onDeleted: widget.onSchoolDeleted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({required this.school, required this.onDeleted});
  final School school;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final error = Theme.of(context).colorScheme.error;
    return Card(
      color: error.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: error.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dangerZone,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: error)),
            const SizedBox(height: 8),
            Text(s.deleteSchoolWarning,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: error, side: BorderSide(color: error)),
                icon: const Icon(Icons.delete_forever),
                label: Text(s.deleteSchool),
                onPressed: () async {
                  final deleted = await showDialog<bool>(
                    context: context,
                    builder: (_) => _DeleteSchoolDialog(school: school),
                  );
                  if (deleted == true) onDeleted();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSchoolDialog extends StatefulWidget {
  const _DeleteSchoolDialog({required this.school});
  final School school;
  @override
  State<_DeleteSchoolDialog> createState() => _DeleteSchoolDialogState();
}

class _DeleteSchoolDialogState extends State<_DeleteSchoolDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _canDelete =>
      _ctrl.text.trim() == widget.school.name.trim() && !_busy;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SchoolRepository>().deleteSchool(widget.school.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.s.genericError;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: Text(s.deleteSchool),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.deleteSchoolWarning),
            const SizedBox(height: 16),
            Text('${s.typeNameToConfirm}:  “${widget.school.name}”',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: s.schoolName),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: _canDelete ? _delete : null,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4))
              : Text(s.deleteSchool),
        ),
      ],
    );
  }
}

class _SchoolDetailsCard extends StatefulWidget {
  const _SchoolDetailsCard({required this.school, required this.onSaved});
  final School school;
  final ValueChanged<School> onSaved;
  @override
  State<_SchoolDetailsCard> createState() => _SchoolDetailsCardState();
}

class _SchoolDetailsCardState extends State<_SchoolDetailsCard> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.school.name);
  late TermType _termType = widget.school.termType;
  late double _gradeMax = widget.school.gradeMax;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<SchoolRepository>().updateSchool(
            widget.school.copyWith(
              name: _nameCtrl.text.trim(),
              termType: _termType,
              gradeMax: _gradeMax,
            ),
          );
      widget.onSaved(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.save)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.schoolSettings,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: s.schoolName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
              const SizedBox(height: 16),
              TermTypePicker(
                value: _termType,
                onChanged: (t) => setState(() => _termType = t),
              ),
              const SizedBox(height: 16),
              GradeMaxField(
                value: _gradeMax,
                onChanged: (v) => _gradeMax = v,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4))
                      : Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearsCard extends StatelessWidget {
  const _YearsCard({
    required this.school,
    required this.yearsFuture,
    required this.onChanged,
  });
  final School school;
  final Future<List<SchoolYear>> yearsFuture;
  final VoidCallback onChanged;

  Future<void> _addYear(BuildContext context) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddYearDialog(school: school),
    );
    if (added == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.schoolYears,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _addYear(context),
                  icon: const Icon(Icons.add),
                  label: Text(s.addYear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<SchoolYear>>(
              future: yearsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final years = snap.data ?? const [];
                if (years.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text(s.noYears,
                            style: Theme.of(context).textTheme.bodyMedium)),
                  );
                }
                return Column(
                  children: [
                    for (final y in years)
                      _YearTile(
                        school: school,
                        year: y,
                        onChanged: onChanged,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _YearTile extends StatelessWidget {
  const _YearTile({
    required this.school,
    required this.year,
    required this.onChanged,
  });
  final School school;
  final SchoolYear year;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Terms display derives from the school's structure (idx 1..count).
    final termChips = [
      for (var i = 1; i <= school.termType.count; i++)
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text(s.termName(school.termType, i)),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(year.label,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (year.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.seed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.activeYear,
                      style: TextStyle(
                          color: AppTheme.seed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              if (!year.isActive)
                TextButton(
                  onPressed: () async {
                    await context
                        .read<SchoolRepository>()
                        .setActiveYear(school.id, year.id);
                    onChanged();
                  },
                  child: Text(s.setActive),
                ),
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final repo = context.read<SchoolRepository>();
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await _confirmDelete(context);
                  if (ok != true) return;
                  try {
                    final n = await repo.deleteYear(year.id);
                    debugPrint('delete-year "${year.label}": $n row(s) deleted');
                    if (n == 0) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Nothing deleted — blocked by permissions (RLS).')));
                    }
                    onChanged();
                  } catch (e, st) {
                    debugPrint('delete-year error: $e\n$st');
                    messenger
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: termChips),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final s = context.s;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${s.delete}: ${year.label}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.delete)),
        ],
      ),
    );
  }
}

class _AddYearDialog extends StatefulWidget {
  const _AddYearDialog({required this.school});
  final School school;
  @override
  State<_AddYearDialog> createState() => _AddYearDialogState();
}

class _AddYearDialogState extends State<_AddYearDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = context.s;
    final type = widget.school.termType;
    final labels = [
      for (var i = 1; i <= type.count; i++) s.termName(type, i),
    ];
    try {
      await context.read<SchoolRepository>().createYearWithTerms(
            schoolId: widget.school.id,
            label: _labelCtrl.text.trim(),
            termType: type,
            termLabels: labels,
            startsOn: _start,
            endsOn: _end,
          );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e, st) {
      debugPrint('add-year PostgrestException: ${e.code} ${e.message}\n${e.details}\n$st');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '${e.message}${e.code != null ? ' (${e.code})' : ''}';
        });
      }
    } catch (e, st) {
      debugPrint('add-year error: $e\n$st');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.addYear),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: s.yearLabel),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: s.startDate,
                      value: _start,
                      onPick: (d) => setState(() => _start = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: s.endDate,
                      value: _end,
                      onPick: (d) => setState(() => _end = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${s.termsWord}: '
                  '${[for (var i = 1; i <= widget.school.termType.count; i++) s.termName(widget.school.termType, i)].join('  ·  ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(s.cancel)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4))
              : Text(s.create),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null ? '—' : dateToDb(value)!,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
