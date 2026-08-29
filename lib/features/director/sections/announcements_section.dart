import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../data/school_repository.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';

/// Director announcements: title + message, targeted by audience
/// (teachers / parents / both) and optionally scoped to a single class.
class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key, required this.school});
  final School school;

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  SchoolRepository get _schoolRepo => context.read<SchoolRepository>();
  AcademicRepository get _repo => context.read<AcademicRepository>();

  List<SchoolClass> _classes = const [];
  late Future<List<Announcement>> _future = _repo.announcements(widget.school.id);

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final years = await _schoolRepo.years(widget.school.id);
    SchoolYear? active;
    for (final y in years) {
      if (y.isActive) active = y;
    }
    final classes =
        active == null ? <SchoolClass>[] : await _repo.classes(active.id);
    if (mounted) setState(() => _classes = classes);
  }

  void _reload() {
    setState(() {
      _future = _repo.announcements(widget.school.id);
    });
  }

  Future<void> _new() async {
    final r = await showDialog<_AnnResult>(
      context: context,
      builder: (_) => _AnnouncementDialog(classes: _classes),
    );
    if (r == null) return;
    await _repo.createAnnouncement(
      schoolId: widget.school.id,
      classId: r.classId,
      audience: r.audience,
      title: r.title,
      body: r.body,
    );
    _reload();
  }

  Future<void> _edit(Announcement a) async {
    final r = await showDialog<_AnnResult>(
      context: context,
      builder: (_) => _AnnouncementDialog(classes: _classes, editing: a),
    );
    if (r == null) return;
    await _repo.updateAnnouncement(
      id: a.id,
      classId: r.classId,
      audience: r.audience,
      title: r.title,
      body: r.body,
    );
    _reload();
  }

  Future<void> _delete(Announcement a) async {
    if (!await confirmDelete(context, a.title)) return;
    await _repo.deleteAnnouncement(a.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: _new,
                    icon: const Icon(Icons.campaign_outlined),
                    label: Text(s.newAnnouncement),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Announcement>>(
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
                            child: Text(s.noAnnouncements,
                                style: Theme.of(context).textTheme.bodyMedium)),
                      );
                    }
                    return Column(
                      children: [for (final a in items) _card(context, a)],
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

  String _audienceText(BuildContext context, AnnouncementAudience a) {
    final s = context.s;
    return switch (a) {
      AnnouncementAudience.teachers => s.audienceTeachers,
      AnnouncementAudience.parents => s.audienceParents,
      AnnouncementAudience.both => s.audienceBoth,
    };
  }

  Widget _card(BuildContext context, Announcement a) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    final date = DateFormat.yMMMd(lang).add_Hm().format(a.createdAt);
    final scope = a.className ?? s.wholeSchool;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: s.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(a),
                ),
                IconButton(
                  tooltip: s.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(a),
                ),
              ],
            ),
            if (a.body != null && a.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(a.body!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.group_outlined, size: 16),
                  label: Text(_audienceText(context, a.audience)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.class_outlined, size: 16),
                  label: Text(scope),
                ),
                Text(date,
                    style: Theme.of(context).textTheme.bodySmall,
                    textDirection: TextDirection.ltr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnResult {
  _AnnResult({
    required this.title,
    required this.audience,
    this.body,
    this.classId,
  });
  final String title;
  final AnnouncementAudience audience;
  final String? body;
  final String? classId;
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.classes, this.editing});
  final List<SchoolClass> classes;
  final Announcement? editing;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl =
      TextEditingController(text: widget.editing?.title ?? '');
  late final _bodyCtrl = TextEditingController(text: widget.editing?.body ?? '');
  late AnnouncementAudience _audience =
      widget.editing?.audience ?? AnnouncementAudience.both;
  late String? _classId = widget.editing?.classId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_AnnResult(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      audience: _audience,
      classId: _classId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(widget.editing == null ? s.newAnnouncement : s.edit),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: s.announcementTitle),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.phoneRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                    labelText: s.announcementBody, alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(s.audienceLabel,
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 6),
              SegmentedButton<AnnouncementAudience>(
                segments: [
                  ButtonSegment(
                      value: AnnouncementAudience.teachers,
                      label: Text(s.audienceTeachers)),
                  ButtonSegment(
                      value: AnnouncementAudience.parents,
                      label: Text(s.audienceParents)),
                  ButtonSegment(
                      value: AnnouncementAudience.both,
                      label: Text(s.audienceBoth)),
                ],
                selected: {_audience},
                onSelectionChanged: (set) =>
                    setState(() => _audience = set.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _classId,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.scopeLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(s.wholeSchool)),
                  for (final c in widget.classes)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _classId = v),
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
