import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/teacher_repository.dart';
import '../../l10n/strings.dart';

/// Attendance for one session (a timetable slot on a given date). Ensures the
/// concrete session exists, lists the class's students, and lets the teacher
/// mark each present / absent / late (saved immediately).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.slot, required this.date});
  final TeacherSlot slot;
  final DateTime date;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  TeacherRepository get _repo => context.read<TeacherRepository>();

  bool _loading = true;
  Object? _error;
  String _sessionId = '';
  List<Student> _students = const [];
  final Map<String, AttendanceStatus> _status = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionId = await _repo.ensureSession(widget.slot.id, widget.date);
      final students = await _repo.students(widget.slot.classId);
      final saved = await _repo.attendanceForSession(sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _students = students;
        _status
          ..clear()
          ..addEntries(students.map(
              (st) => MapEntry(st.id, saved[st.id] ?? AttendanceStatus.present)));
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

  Future<void> _set(Student st, AttendanceStatus status) async {
    setState(() => _status[st.id] = status);
    try {
      await _repo.setAttendance(_sessionId, st.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _markAllPresent() async {
    setState(() {
      for (final st in _students) {
        _status[st.id] = AttendanceStatus.present;
      }
    });
    try {
      for (final st in _students) {
        await _repo.setAttendance(_sessionId, st.id, AttendanceStatus.present);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final slot = widget.slot;
    return Scaffold(
      appBar: AppBar(
        title: Text(slot.subjectName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${slot.className} · ${timeLabel(slot.start)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
        actions: [
          if (!_loading && _error == null && _students.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllPresent,
              icon: const Icon(Icons.done_all),
              label: Text(s.markAllPresent),
            ),
        ],
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final st = _students[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(st.fullName, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              _StatusButtons(
                value: _status[st.id] ?? AttendanceStatus.present,
                onChanged: (v) => _set(st, v),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusButtons extends StatelessWidget {
  const _StatusButtons({required this.value, required this.onChanged});
  final AttendanceStatus value;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SegmentedButton<AttendanceStatus>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: AttendanceStatus.present, label: Text(s.present)),
        ButtonSegment(value: AttendanceStatus.absent, label: Text(s.absent)),
        ButtonSegment(value: AttendanceStatus.late, label: Text(s.late)),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
