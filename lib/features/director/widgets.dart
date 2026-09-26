import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../data/models.dart';
import '../../data/school_repository.dart';
import '../../l10n/strings.dart';
import '../auth/auth_service.dart';

/// Segmented picker for trimester (×3) vs semester (×2).
class TermTypePicker extends StatelessWidget {
  const TermTypePicker({super.key, required this.value, required this.onChanged});
  final TermType value;
  final ValueChanged<TermType> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.termTypeLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<TermType>(
          segments: [
            ButtonSegment(
                value: TermType.trimester, label: Text('${s.trimester} ×3')),
            ButtonSegment(
                value: TermType.semester, label: Text('${s.semester} ×2')),
          ],
          selected: {value},
          onSelectionChanged: (set) => onChanged(set.first),
        ),
      ],
    );
  }
}

/// Grade-scale field (e.g. /20).
class GradeMaxField extends StatelessWidget {
  const GradeMaxField({super.key, required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return TextFormField(
      initialValue:
          value % 1 == 0 ? value.toStringAsFixed(0) : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: s.gradeMaxLabel,
        prefixText: '/ ',
        prefixStyle:
            const TextStyle(color: AppTheme.seed, fontWeight: FontWeight.bold),
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed != null && parsed > 0) onChanged(parsed);
      },
    );
  }
}

String gradeMaxLabelValue(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

/// Small dialog to enter/edit a single name (class, subject, …). Pops the
/// trimmed text on save, or null if cancelled.
class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint,
    this.initial,
  });

  final String title;
  final String label;
  final String? hint;
  final String? initial;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _ctrl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: TextFormField(
            controller: _ctrl,
            autofocus: true,
            decoration:
                InputDecoration(labelText: widget.label, hintText: widget.hint),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
          ),
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

/// Result of the teacher dialog. Phone is normalized to E.164 without '+'.
typedef TeacherInput = ({String? name, String phone});

/// Dialog to add/edit a teacher (full name + phone). Pops [TeacherInput] on save.
class TeacherDialog extends StatefulWidget {
  const TeacherDialog({super.key, this.initialName, this.initialPhone});
  final String? initialName;
  final String? initialPhone;

  @override
  State<TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<TeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.initialPhone ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    Navigator.of(context).pop((
      name: name.isEmpty ? null : name,
      phone: AuthService.normalizePhone(_phoneCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initialPhone == null ? s.addTeacher : s.edit),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s.fullNameLabel),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: InputDecoration(
                  labelText: s.phoneLabel,
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '${Env.defaultCountryCode}XXXXXXXX',
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
            ],
          ),
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

/// Result of the student dialog. Phones are normalized to E.164 without '+'.
typedef StudentInput = ({String name, String? phone1, String? phone2});

/// Dialog to add/edit a student (name + up to two parent phones).
class StudentDialog extends StatefulWidget {
  const StudentDialog({
    super.key,
    this.initialName,
    this.initialPhone1,
    this.initialPhone2,
  });
  final String? initialName;
  final String? initialPhone1;
  final String? initialPhone2;

  @override
  State<StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<StudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  late final _phone1Ctrl =
      TextEditingController(text: widget.initialPhone1 ?? '');
  late final _phone2Ctrl =
      TextEditingController(text: widget.initialPhone2 ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    super.dispose();
  }

  String? _phone(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : AuthService.normalizePhone(t);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      name: _nameCtrl.text.trim(),
      phone1: _phone(_phone1Ctrl),
      phone2: _phone(_phone2Ctrl),
    ));
  }

  Widget _phoneField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.phone),
          hintText: '${Env.defaultCountryCode}XXXXXXXX',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initialName == null ? s.addStudent : s.edit),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s.studentName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
              const SizedBox(height: 12),
              _phoneField(_phone1Ctrl, s.parentPhone1),
              const SizedBox(height: 12),
              _phoneField(_phone2Ctrl, s.parentPhone2),
            ],
          ),
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

/// Confirmation dialog for a destructive delete. Resolves true if confirmed.
Future<bool> confirmDelete(BuildContext context, String name) async {
  final s = context.s;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
        scrollable: true,
      title: Text('${s.delete}: $name'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Dialog to create a school. Pops the created [School] on success, or null if
/// cancelled. Reused by onboarding and the in-app "create another school" flow.
class CreateSchoolDialog extends StatefulWidget {
  const CreateSchoolDialog({super.key});
  @override
  State<CreateSchoolDialog> createState() => _CreateSchoolDialogState();
}

class _CreateSchoolDialogState extends State<CreateSchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  TermType _termType = TermType.trimester;
  double _gradeMax = 20;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final school = await context.read<SchoolRepository>().createSchool(
            name: _nameCtrl.text.trim(),
            termType: _termType,
            gradeMax: _gradeMax,
          );
      if (mounted) Navigator.of(context).pop(school);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.s.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(s.createSchoolCta),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
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
              GradeMaxField(value: _gradeMax, onChanged: (v) => _gradeMax = v),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
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
