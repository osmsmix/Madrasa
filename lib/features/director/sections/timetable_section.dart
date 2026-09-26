import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/academic_repository.dart';
import '../../../data/models.dart';
import '../../../data/school_repository.dart';
import '../../../l10n/strings.dart';
import '../widgets.dart';

/// The director builds the weekly timetable per class: which subject (with its
/// assigned teacher) is taught on which weekday and time. These are the
/// `schedule_slots` the teacher's daily schedule and attendance derive from.
class TimetableSection extends StatefulWidget {
  const TimetableSection({super.key, required this.school});
  final School school;

  @override
  State<TimetableSection> createState() => _TimetableSectionState();
}

class _TimetableSectionState extends State<TimetableSection> {
  SchoolRepository get _schoolRepo => context.read<SchoolRepository>();
  AcademicRepository get _repo => context.read<AcademicRepository>();

  bool _loading = true;
  List<SchoolYear> _years = const [];
  String? _yearId;
  List<SchoolClass> _classes = const [];
  String? _classId;

  List<ClassSubject> _classSubjects = const [];
  Future<List<ScheduleSlot>>? _slotsFuture;

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
    await _loadForClass();
  }

  Future<void> _onYearChanged(String yearId) async {
    final classes = await _repo.classes(yearId);
    if (!mounted) return;
    setState(() {
      _yearId = yearId;
      _classes = classes;
      _classId = classes.isEmpty ? null : classes.first.id;
    });
    await _loadForClass();
  }

  Future<void> _loadForClass() async {
    if (_classId == null) {
      setState(() {
        _classSubjects = const [];
        _slotsFuture = Future.value(const []);
      });
      return;
    }
    final cs = await _repo.classSubjects(_classId!);
    if (!mounted) return;
    setState(() {
      _classSubjects = cs;
      _slotsFuture = _repo.slotsForClass(_classId!);
    });
  }

  void _reloadSlots() {
    if (_classId == null) return;
    setState(() {
      _slotsFuture = _repo.slotsForClass(_classId!);
    });
  }

  Future<void> _add() async {
    final s = context.s;
    if (_classSubjects.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.needClassSubjectsFirst)));
      return;
    }
    final result = await showDialog<_SessionResult>(
      context: context,
      builder: (_) => _SessionDialog(classSubjects: _classSubjects),
    );
    if (result == null) return;
    await _repo.createSlot(
      classSubjectId: result.classSubjectId,
      weekday: result.weekday,
      startTime: timeToDb(result.start),
      endTime: timeToDb(result.end),
      room: result.room,
    );
    _reloadSlots();
  }

  Future<void> _edit(ScheduleSlot slot) async {
    final result = await showDialog<_SessionResult>(
      context: context,
      builder: (_) =>
          _SessionDialog(classSubjects: _classSubjects, editing: slot),
    );
    if (result == null) return;
    await _repo.updateSlot(
      id: slot.id,
      classSubjectId: result.classSubjectId,
      weekday: result.weekday,
      startTime: timeToDb(result.start),
      endTime: timeToDb(result.end),
      room: result.room,
    );
    _reloadSlots();
  }

  Future<void> _delete(ScheduleSlot slot) async {
    if (!await confirmDelete(context, '${slot.subjectName} · ${timeLabel(slot.start)}')) {
      return;
    }
    await _repo.deleteSlot(slot.id);
    _reloadSlots();
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _selectors(context),
                    const Divider(height: 28),
                    FutureBuilder<List<ScheduleSlot>>(
                      future: _slotsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final slots = snap.data ?? const [];
                        if (slots.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(s.noSessions,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium)),
                          );
                        }
                        return _week(context, slots);
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
                _loadForClass();
              },
              items: [
                for (final c in _classes)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(s.addSession),
        ),
      ],
    );
  }

  Widget _week(BuildContext context, List<ScheduleSlot> slots) {
    final s = context.s;
    final byDay = <int, List<ScheduleSlot>>{};
    for (final slot in slots) {
      byDay.putIfAbsent(slot.weekday, () => []).add(slot);
    }
    final days = byDay.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(s.dayName(day),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          for (final slot in byDay[day]!) _slotTile(context, slot),
        ],
      ],
    );
  }

  Widget _slotTile(BuildContext context, ScheduleSlot slot) {
    final s = context.s;
    final time = '${timeLabel(slot.start)} – ${timeLabel(slot.end)}';
    final sub = [
      if (slot.teacherName != null) slot.teacherName!,
      if (slot.room != null && slot.room!.isNotEmpty) '${s.roomLabel}: ${slot.room}',
    ].join('  ·  ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 92,
        child: Text(time,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.labelLarge),
      ),
      title: Text(slot.subjectName),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: s.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(slot),
          ),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(slot),
          ),
        ],
      ),
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

class _SessionResult {
  _SessionResult({
    required this.classSubjectId,
    required this.weekday,
    required this.start,
    required this.end,
    this.room,
  });
  final String classSubjectId;
  final int weekday;
  final TimeOfDay start;
  final TimeOfDay end;
  final String? room;
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({required this.classSubjects, this.editing});
  final List<ClassSubject> classSubjects;
  final ScheduleSlot? editing;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  String? _classSubjectId;
  int _weekday = 1;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 0);
  late final _roomCtrl = TextEditingController(text: widget.editing?.room ?? '');
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _classSubjectId = e.classSubjectId;
      _weekday = e.weekday;
      _start = e.start;
      _end = e.end;
    } else if (widget.classSubjects.isNotEmpty) {
      _classSubjectId = widget.classSubjects.first.id;
    }
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  void _submit() {
    if (_classSubjectId == null) return;
    if (_minutes(_end) <= _minutes(_start)) {
      setState(() => _error = context.s.endAfterStart);
      return;
    }
    Navigator.of(context).pop(_SessionResult(
      classSubjectId: _classSubjectId!,
      weekday: _weekday,
      start: _start,
      end: _end,
      room: _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
    ));
  }

  String _csLabel(ClassSubject cs) =>
      cs.teacherName == null ? cs.subjectName : '${cs.subjectName} — ${cs.teacherName}';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.editing == null ? s.addSession : s.edit),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classSubjectId,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.sessionLabel),
              items: [
                for (final cs in widget.classSubjects)
                  DropdownMenuItem(value: cs.id, child: Text(_csLabel(cs))),
              ],
              onChanged: (v) => setState(() => _classSubjectId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.dayLabel),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(s.dayName(d))),
              ],
              onChanged: (v) => setState(() => _weekday = v ?? 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: s.startTimeLabel,
                    value: _start,
                    onTap: _pickStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: s.endTimeLabel,
                    value: _end,
                    onTap: _pickEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomCtrl,
              decoration: InputDecoration(labelText: s.roomLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
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

class _TimeField extends StatelessWidget {
  const _TimeField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, suffixIcon: const Icon(Icons.schedule)),
        child: Text(timeLabel(value), textDirection: TextDirection.ltr),
      ),
    );
  }
}
